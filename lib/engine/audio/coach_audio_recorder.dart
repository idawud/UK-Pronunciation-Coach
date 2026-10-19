import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/contracts/audio_recorder.dart';
import '../../core/contracts/clock.dart';
import '../../core/contracts/errors.dart';
import '../../core/models/models.dart';
import 'mic.dart';
import 'signal.dart';
import 'silero_vad.dart';
import 'vad.dart';
import 'wav.dart';

/// Where the app bundles the Silero VAD model (flat name: Flutter does not bundle
/// sub-folders of assets/models/).
const String sileroVadAsset = 'assets/models/silero_vad.onnx';

/// Loads Silero VAD from the asset bundle, or falls back to the energy detector
/// when the model is missing or does not load (logged in debug builds).
Future<VadBackend> loadBundledVad({
  AssetBundle? bundle,
  String asset = sileroVadAsset,
  VadBackend Function(Uint8List bytes)? open,
}) async {
  try {
    final data = await (bundle ?? rootBundle).load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return (open ?? SileroVadBackend.new)(bytes);
  } catch (e) {
    debugPrint('A1 audio: Silero VAD unavailable ($e); using energy VAD');
    return const EnergyVadBackend();
  }
}

/// `<app support>/recordings`, created if needed.
Future<Directory> defaultRecordingsDirectory() async {
  final base = await getApplicationSupportDirectory();
  return Directory('${base.path}/recordings').create(recursive: true);
}

/// [AudioRecorder] for the app: streams 16 kHz mono PCM from a [MicSource] into a
/// WAV file, computes the level stream, runs the VAD live (for `silenceDetected`
/// and, for free, `speechSegments` of the clip just recorded) and checks quality
/// on [stop].
class CoachAudioRecorder implements AudioRecorder {
  /// Creates the recorder. [loadVad] starts at once so the model is warm before the
  /// first [start].
  CoachAudioRecorder({
    required MicSource mic,
    required MicPermissions permissions,
    Future<Directory> Function() recordingsDirectory =
        defaultRecordingsDirectory,
    Future<VadBackend> Function() loadVad = loadBundledVad,
    Clock clock = systemClock,
    this.settings = const VadSettings(),
  }) // Private fields from public named parameters.
    // ignore: prefer_initializing_formals
    : _mic = mic,
       // ignore: prefer_initializing_formals
       _permissions = permissions,
       // ignore: prefer_initializing_formals
       _recordingsDirectory = recordingsDirectory,
       // ignore: prefer_initializing_formals
       _clock = clock {
    _vad = loadVad();
    // Avoid an unhandled error if nobody records before it fails.
    _vad.ignore();
  }

  /// The production recorder: `record` + `permission_handler`, recordings in app
  /// support storage, bundled Silero VAD.
  factory CoachAudioRecorder.platform() => CoachAudioRecorder(
    mic: RecordMicSource(),
    permissions: PermissionHandlerMicPermissions(),
  );

  /// VAD thresholds, padding and the silence timeout.
  final VadSettings settings;

  final MicSource _mic;
  final MicPermissions _permissions;
  final Future<Directory> Function() _recordingsDirectory;
  final Clock _clock;
  late final Future<VadBackend> _vad;

  final _level = StreamController<double>.broadcast();
  final _silence = StreamController<void>.broadcast();

  /// VAD probabilities of recent clips, by path, so [speechSegments] does not
  /// re-run the model on the clip it just heard.
  final _probabilityCache = <String, List<double>>{};
  static const _cacheSize = 4;

  _Take? _take;
  Future<void>? _starting;
  SpeechProbabilityModel? _liveModel;
  int _liveChunk = 512;
  bool _disposed = false;
  int _counter = 0;

  /// Time [start] took last time (permission check to first audio requested).
  Duration? lastStartLatency;

  /// Name of the VAD in use ("silero" or "energy"), once loaded.
  Future<String> get vadName async => (await _vad).name;

  @override
  Future<MicPermission> checkPermission() => _permissions.status();

  @override
  Future<MicPermission> requestPermission() => _permissions.request();

  @override
  Future<bool> openPermissionSettings() => _permissions.openSettings();

  @override
  bool get isRecording => _take != null;

  @override
  Future<void> start() async {
    _checkNotDisposed();
    if (_take != null || _starting != null) {
      throw StateError('Already recording');
    }
    final done = Completer<void>();
    _starting = done.future;
    final watch = Stopwatch()..start();
    try {
      final permission = await _permissions.status();
      if (permission != MicPermission.granted) {
        throw MicPermissionException(permission);
      }
      final backend = await _vad;
      final model = _liveModel ??= backend.open();
      _liveChunk = model.chunkSamples;
      final dir = await _recordingsDirectory();
      final stamp = _clock().toUtc().toIso8601String().replaceAll(
        RegExp('[^0-9]'),
        '',
      );
      final path = '${dir.path}/rec_${stamp}_${_counter++}.wav';
      final writer = await WavFileWriter.open(path);
      final take = _Take(
        writer,
        ChunkedVad(model)..reset(),
        SilenceTimer(settings: settings, chunkSamples: model.chunkSamples),
      );
      final Stream<Uint8List> stream;
      try {
        stream = await _mic.start(sampleRate: recordingSampleRate);
      } catch (_) {
        await writer.discard();
        rethrow;
      }
      take.subscription = stream.listen(
        (bytes) => _onAudio(take, bytes),
        onError: (Object e) => take.error ??= e,
      );
      _take = take;
      lastStartLatency = watch.elapsed;
    } finally {
      _starting = null;
      done.complete();
    }
  }

  void _onAudio(_Take take, Uint8List bytes) {
    if (take.closed || bytes.isEmpty) return;
    // Keep an even byte count: carry a split sample over to the next block.
    var data = bytes;
    if (take.carry != null) {
      data = Uint8List(bytes.length + 1)
        ..[0] = take.carry!
        ..setRange(1, bytes.length + 1, bytes);
      take.carry = null;
    }
    if (data.length.isOdd) {
      take.carry = data.last;
      data = Uint8List.sublistView(data, 0, data.length - 1);
    }
    if (data.isEmpty) return;
    take.writer.add(Uint8List.fromList(data));
    final samples = pcm16ToFloat(data);
    take.samples.add(samples);
    for (final v in take.meter.add(samples)) {
      _level.add(v);
    }
    for (final p in take.vad.add(samples)) {
      if (take.silence.add(p)) _silence.add(null);
    }
  }

  Future<_Take?> _halt() async {
    final pending = _starting;
    if (pending != null) await pending;
    final take = _take;
    if (take == null) return null;
    _take = null;
    take.closed = true;
    try {
      await _mic.stop();
    } finally {
      await take.subscription?.cancel();
    }
    return take;
  }

  @override
  Future<AudioClip> stop() async {
    _checkNotDisposed();
    if (_take == null && _starting == null) throw StateError('Not recording');
    final take = await _halt();
    if (take == null) throw StateError('Not recording');
    take.vad.flush();
    await take.writer.close();
    final samples = take.samples.toFloat32List();
    final report = QualityReport.of(samples);
    final path = take.writer.file.path;
    _remember(path, List.of(take.vad.probabilities));
    return AudioClip(
      path: path,
      sampleRate: recordingSampleRate,
      duration: durationOfSamples(samples.length, recordingSampleRate),
      quality: report.quality,
      peakDbfs: report.peakDbfs,
      snrDb: report.snrDb,
    );
  }

  @override
  Future<void> cancel() async {
    if (_disposed) return;
    final take = await _halt();
    await take?.writer.discard();
  }

  @override
  Stream<double> get level => _level.stream;

  @override
  Stream<void> get silenceDetected => _silence.stream;

  void _remember(String path, List<double> probabilities) {
    _probabilityCache.remove(path);
    _probabilityCache[path] = probabilities;
    while (_probabilityCache.length > _cacheSize) {
      _probabilityCache.remove(_probabilityCache.keys.first);
    }
  }

  @override
  Future<List<Segment>> speechSegments(AudioClip clip) async {
    _checkNotDisposed();
    var probabilities = _probabilityCache[clip.path];
    var chunk = _liveChunk;
    if (probabilities == null) {
      final audio = decodeWav(await File(clip.path).readAsBytes());
      if (audio.sampleRate != recordingSampleRate) {
        throw FormatException(
          'Expected $recordingSampleRate Hz audio, got ${audio.sampleRate} Hz',
        );
      }
      final backend = await _vad;
      chunk = backend.chunkSamples;
      probabilities = await backend.analyse(audio.samples);
    }
    return speechSegmentsFromProbabilities(
      probabilities,
      clipDuration: clip.duration,
      chunkSamples: chunk,
      settings: settings,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await cancel();
    _disposed = true;
    _liveModel?.close();
    _liveModel = null;
    await _mic.dispose();
    await _level.close();
    await _silence.close();
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('Recorder disposed');
  }
}

/// State of one recording.
class _Take {
  _Take(this.writer, this.vad, this.silence);

  final WavFileWriter writer;
  final ChunkedVad vad;
  final SilenceTimer silence;
  final meter = LevelMeter();
  final samples = _FloatBuilder();
  StreamSubscription<Uint8List>? subscription;
  int? carry;
  Object? error;
  bool closed = false;
}

/// Growable list of float blocks.
class _FloatBuilder {
  final _blocks = <Float32List>[];
  int _length = 0;

  void add(Float32List block) {
    _blocks.add(block);
    _length += block.length;
  }

  Float32List toFloat32List() {
    final out = Float32List(_length);
    var at = 0;
    for (final b in _blocks) {
      out.setAll(at, b);
      at += b.length;
    }
    return out;
  }
}
