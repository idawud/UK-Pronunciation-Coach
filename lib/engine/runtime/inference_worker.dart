import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'audio_input.dart';
import 'ctc_session.dart';
import 'model_vocab.dart';

/// wav2vec2's feature encoder receptive field: shorter input yields no frames.
const int minModelSamples = 400;

/// Log-posteriors for one clip as produced by [InferenceCore.recognise].
class RecognitionOutput {
  /// Creates the output.
  const RecognitionOutput({
    required this.logProbs,
    required this.frames,
    required this.vocab,
    required this.blankIndex,
    required this.samples,
    required this.inferenceMicros,
  });

  /// Row-major `[frames, vocab.length]` natural-log probabilities.
  final Float32List logProbs;

  /// Number of frames.
  final int frames;

  /// Model symbols.
  final List<String> vocab;

  /// CTC blank column.
  final int blankIndex;

  /// Number of input samples (16 kHz).
  final int samples;

  /// Time spent in the model itself (not WAV decoding), in microseconds.
  final int inferenceMicros;
}

/// The work done inside the inference isolate, as a plain class so it can also be
/// unit-tested on the calling isolate. Not thread-safe; one call at a time.
class InferenceCore {
  /// Creates the core; [opener] opens ONNX sessions.
  InferenceCore(this._opener);

  final CtcSessionOpener _opener;
  CtcModelSession? _session;
  ModelVocab? _vocab;

  /// Whether a model is loaded.
  bool get isLoaded => _session != null;

  /// Loads the model at [modelPath] with the vocab at [vocabPath], replacing any
  /// loaded model. Returns the vocab size.
  Future<int> load(String modelPath, String vocabPath) async {
    final vocab = ModelVocab.fromJson(File(vocabPath).readAsStringSync());
    final session = _opener(modelPath);
    await unload();
    _session = session;
    _vocab = vocab;
    return vocab.length;
  }

  /// Reads the 16 kHz WAV at [wavPath], normalises it and runs the model.
  /// Throws [StateError] when no model is loaded.
  RecognitionOutput recognise(String wavPath) {
    final session = _session;
    final vocab = _vocab;
    if (session == null || vocab == null) {
      throw StateError('No model loaded');
    }
    final raw = decodePcm16Wav(File(wavPath).readAsBytesSync());
    final input = padToMinLength(normaliseWaveform(raw), minModelSamples);
    final watch = Stopwatch()..start();
    final logits = session.run(input);
    watch.stop();
    if (logits.vocabSize != vocab.length) {
      throw StateError(
        'Model has ${logits.vocabSize} outputs but vocab.json has ${vocab.length}',
      );
    }
    logSoftmaxRowsInPlace(logits.data, logits.vocabSize);
    return RecognitionOutput(
      logProbs: logits.data,
      frames: logits.frames,
      vocab: vocab.symbols,
      blankIndex: vocab.blankIndex,
      samples: raw.length,
      inferenceMicros: watch.elapsedMicroseconds,
    );
  }

  /// Releases the loaded model, if any.
  Future<void> unload() async {
    final session = _session;
    _session = null;
    _vocab = null;
    await session?.close();
  }

  /// Runs one worker command and returns the reply message `(id, ok, payload)`;
  /// errors are encoded as `(kind, message)` so they can cross isolates.
  Future<(int, bool, Object?)> handle(int id, String op, Object? arg) async {
    try {
      switch (op) {
        case 'load':
          final (model, vocab) = arg! as (String, String);
          return (id, true, await load(model, vocab));
        case 'recognise':
          final out = recognise(arg! as String);
          return (
            id,
            true,
            (
              TransferableTypedData.fromList([out.logProbs]),
              out.frames,
              out.vocab,
              out.blankIndex,
              out.samples,
              out.inferenceMicros,
            ),
          );
        case 'unload':
          await unload();
          return (id, true, null);
        default:
          throw StateError('Unknown command $op');
      }
    } catch (e) {
      return (id, false, encodeWorkerError(e));
    }
  }
}

/// A long-lived background isolate that owns the ONNX session, so model loading and
/// inference never run on the UI isolate. Calls are queued and run one at a time.
class InferenceWorker {
  InferenceWorker._(this._isolate, this._commands, this._responses);

  /// Starts the isolate. [opener] must be a top-level or static function.
  static Future<InferenceWorker> spawn({
    CtcSessionOpener opener = OrtCtcModelSession.opener,
  }) async {
    final responses = ReceivePort('inference-responses');
    final isolate = await Isolate.spawn(
      _workerMain,
      (responses.sendPort, opener),
      debugName: 'phoneme-inference',
      errorsAreFatal: false,
    );
    final events = StreamIterator(responses);
    await events.moveNext();
    final commands = events.current as SendPort;
    final worker = InferenceWorker._(isolate, commands, responses);
    worker._listen(events);
    return worker;
  }

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _responses;
  final _pending = <int, Completer<Object?>>{};
  var _nextId = 0;
  var _closed = false;

  void _listen(StreamIterator<dynamic> events) {
    unawaited(() async {
      while (await events.moveNext()) {
        final (id, ok, value) = events.current as (int, bool, Object?);
        final completer = _pending.remove(id);
        if (completer == null) continue;
        if (ok) {
          completer.complete(value);
        } else {
          completer.completeError(
            decodeWorkerError(value! as (String, String)),
          );
        }
      }
    }());
  }

  Future<Object?> _call(String op, [Object? arg]) {
    if (_closed) return Future.error(StateError('Inference worker closed'));
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _commands.send((id, op, arg));
    return completer.future;
  }

  /// See [InferenceCore.load].
  Future<int> load(String modelPath, String vocabPath) async =>
      await _call('load', (modelPath, vocabPath)) as int;

  /// See [InferenceCore.recognise]. The result's buffer is moved, not copied.
  Future<RecognitionOutput> recognise(String wavPath) async {
    final (data, frames, vocab, blank, samples, micros) = await _call(
      'recognise',
      wavPath,
    ) as (TransferableTypedData, int, List<String>, int, int, int);
    return RecognitionOutput(
      logProbs: data.materialize().asFloat32List(),
      frames: frames,
      vocab: vocab,
      blankIndex: blank,
      samples: samples,
      inferenceMicros: micros,
    );
  }

  /// See [InferenceCore.unload].
  Future<void> unload() => _call('unload');

  /// Unloads the model and stops the isolate.
  Future<void> close() async {
    if (_closed) return;
    try {
      await _call('unload');
    } finally {
      _closed = true;
      _isolate.kill();
      _responses.close();
      for (final c in _pending.values) {
        c.completeError(StateError('Inference worker closed'));
      }
      _pending.clear();
    }
  }
}

/// Rebuilds an error encoded by [encodeWorkerError].
Object decodeWorkerError((String, String) error) {
  final (kind, message) = error;
  return switch (kind) {
    'state' => StateError(message),
    'format' => FormatException(message),
    'io' => FileSystemException(message),
    _ => Exception(message),
  };
}

/// Encodes [error] as `(kind, message)` so it can be sent between isolates.
(String, String) encodeWorkerError(Object error) => switch (error) {
  StateError(:final message) => ('state', message),
  FormatException(:final message) => ('format', message),
  FileSystemException() => ('io', error.toString()),
  _ => ('other', error.toString()),
};

Future<void> _workerMain((SendPort, CtcSessionOpener) args) async {
  final (replies, opener) = args;
  final commands = ReceivePort('inference-commands');
  replies.send(commands.sendPort);
  final core = InferenceCore(opener);
  await for (final message in commands) {
    final (id, op, arg) = message as (int, String, Object?);
    replies.send(await core.handle(id, op, arg));
  }
}
