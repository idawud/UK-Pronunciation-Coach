import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/runtime/audio_input.dart';
import 'package:uk_pronunciation_coach/engine/runtime/ctc_session.dart';
import 'package:uk_pronunciation_coach/engine/runtime/inference_worker.dart';

import 'helpers/fakes.dart';
import 'helpers/host_ort.dart';

/// Session returning fixed logits; fails on demand.
class _StubSession implements CtcModelSession {
  _StubSession(this.vocab);

  final int vocab;
  static var closed = 0;

  @override
  CtcLogits run(Float32List waveform) {
    final frames = (waveform.length - 400) ~/ 320 + 1;
    return CtcLogits(Float32List(frames * vocab), frames, vocab);
  }

  @override
  Future<void> close() async => closed++;
}

CtcModelSession _stubOpener(String path) {
  if (path.contains('broken')) throw const OnnxRuntimeException('cannot open');
  return _StubSession(path.contains('wrong') ? 3 : 8);
}

void main() {
  group('InferenceCore', () {
    test('recognise before load is a StateError', () {
      expect(
        () => InferenceCore(_stubOpener).recognise(cleanWav),
        throwsStateError,
      );
    });

    test('loads, recognises with log-softmax, replaces and unloads', () async {
      final core = InferenceCore(_stubOpener);
      expect(await core.load('a.onnx', tinyVocab), 8);
      expect(core.isLoaded, isTrue);
      final out = core.recognise(cleanWav);
      expect(out.vocab, hasLength(8));
      expect(out.blankIndex, 0);
      expect(out.samples, 51386);
      expect(out.frames, (51386 - 400) ~/ 320 + 1);
      expect(out.logProbs.first, closeTo(-math.log(8), 1e-5));
      final before = _StubSession.closed;
      await core.load('b.onnx', tinyVocab);
      expect(_StubSession.closed, before + 1, reason: 'old session closed');
      await core.unload();
      expect(core.isLoaded, isFalse);
    });

    test('a failed load keeps the previous model', () async {
      final core = InferenceCore(_stubOpener);
      await core.load('a.onnx', tinyVocab);
      await expectLater(
        core.load('broken.onnx', tinyVocab),
        throwsA(isA<OnnxRuntimeException>()),
      );
      expect(core.isLoaded, isTrue);
    });

    test('rejects a vocab that does not match the model', () async {
      final core = InferenceCore(_stubOpener);
      await core.load('wrong.onnx', tinyVocab);
      expect(() => core.recognise(cleanWav), throwsStateError);
    });

    test('pads clips shorter than one frame', () async {
      final dir = await Directory.systemTemp.createTemp('a2');
      addTearDown(() => dir.delete(recursive: true));
      final wav = File('${dir.path}/short.wav')
        ..writeAsBytesSync(encodePcm16Wav(Float32List(100)));
      final core = InferenceCore(_stubOpener);
      await core.load('a.onnx', tinyVocab);
      expect(core.recognise(wav.path).frames, 1);
    });

    test(
      'handle encodes results and errors for the isolate protocol',
      () async {
        final core = InferenceCore(_stubOpener);
        expect(await core.handle(1, 'load', ('a.onnx', tinyVocab)), (
          1,
          true,
          8,
        ));
        final (id, ok, payload) = await core.handle(2, 'recognise', cleanWav);
        expect((id, ok), (2, true));
        final (data, frames, vocab, blank, samples, micros) =
            payload!
                as (TransferableTypedData, int, List<String>, int, int, int);
        expect(data.materialize().lengthInBytes, frames * vocab.length * 4);
        expect((blank, samples), (0, 51386));
        expect(micros, greaterThanOrEqualTo(0));

        void err((int, bool, Object?) r, int id, String kind, String text) {
          final (rid, ok, payload) = r;
          final (k, message) = payload! as (String, String);
          expect((rid, ok, k), (id, false, kind));
          expect(message, contains(text));
        }

        err(
          await core.handle(3, 'recognise', 'missing.wav'),
          3,
          'io',
          'missing.wav',
        );
        expect(await core.handle(4, 'unload', null), (4, true, null));
        err(
          await core.handle(5, 'recognise', cleanWav),
          5,
          'state',
          'No model loaded',
        );
        err(
          await core.handle(6, 'load', ('broken.onnx', tinyVocab)),
          6,
          'other',
          'cannot open',
        );
        err(
          await core.handle(7, 'load', (
            'a.onnx',
            '$fixtures/make_tiny_model.py',
          )),
          7,
          'format',
          '',
        );
        err(
          await core.handle(8, 'explode', null),
          8,
          'state',
          'Unknown command explode',
        );
      },
    );
  });

  test('worker errors round-trip', () {
    expect(
      decodeWorkerError(encodeWorkerError(StateError('s'))),
      isA<StateError>(),
    );
    expect(
      decodeWorkerError(encodeWorkerError(const FormatException('f'))),
      isA<FormatException>(),
    );
    expect(
      decodeWorkerError(encodeWorkerError(const FileSystemException('x'))),
      isA<FileSystemException>(),
    );
    expect(
      decodeWorkerError(encodeWorkerError(Exception('e'))),
      isA<Exception>(),
    );
  });

  group('InferenceWorker (background isolate)', () {
    test('runs the stub model off the calling isolate', () async {
      final w = await InferenceWorker.spawn(opener: _stubOpener);
      expect(await w.load('a.onnx', tinyVocab), 8);
      final out = await w.recognise(cleanWav);
      expect(out.frames * out.vocab.length, out.logProbs.length);
      await expectLater(
        w.recognise('missing.wav'),
        throwsA(isA<FileSystemException>()),
      );
      await w.unload();
      await expectLater(w.recognise(cleanWav), throwsStateError);
      await w.close();
      await w.close();
      await expectLater(w.load('a.onnx', tinyVocab), throwsStateError);
    });

    test(
      'runs the tiny ONNX model with the real runtime',
      skip: hostOrtLibraryPath() == null ? 'no host ONNX Runtime' : false,
      () async {
        final w = await InferenceWorker.spawn(opener: hostOpener);
        addTearDown(w.close);
        await w.load(tinyMaskModel, tinyVocab);
        final out = await w.recognise(cleanWav);
        expect(out.frames, 160);
        for (var f = 0; f < out.frames; f++) {
          var sum = 0.0;
          for (var i = 0; i < 8; i++) {
            sum += math.exp(out.logProbs[f * 8 + i]);
          }
          expect(sum, closeTo(1, 1e-4));
        }
      },
    );
  });
}
