import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/contracts/errors.dart';
import '../../core/contracts/live_recognition.dart';
import '../../core/contracts/phoneme_recognizer.dart';
import '../../core/models/audio_clip.dart';
import '../../core/models/enums.dart';
import '../../core/models/model_download_progress.dart';
import '../../core/models/phoneme_posteriors.dart';
import 'audio_input.dart';
import 'chunk_planner.dart';
import 'ctc_session.dart';
import 'inference_worker.dart';
import 'live_recognition_session.dart';
import 'model_downloader.dart';
import 'model_files.dart';
import 'model_manifest.dart';
import 'model_vocab.dart';
import 'network.dart';
import 'tier_advisor.dart';

/// Frame hop of wav2vec2-style models: the feature encoder's strides multiply to
/// 320 samples, i.e. 20 ms at 16 kHz (50 frames/s).
const int modelFrameMs = 20;

/// Fallback for [PhonemeRecognizer.fullModelSizeBytes] before the manifest lists the
/// full tier: the size of the development model (wav2vec2-lv-60-espeak-cv-ft,
/// `onnx/model_quantized.onnx` (uint8) from Hugging Face `onnx-community`,
/// 317,712,852 bytes) plus its 4,637-byte vocab.json.
const int fallbackFullModelBytes = 317717489;

/// [PhonemeRecognizer] running a wav2vec2 CTC phoneme model with ONNX Runtime in a
/// background isolate.
///
/// Files under [root]: `light/` (bundled model copied out of the app),
/// `full/` (downloaded model), `tier.json` (cached [recommendedTier]).
class OnnxPhonemeRecognizer
    implements PhonemeRecognizer, IncrementalPhonemeRecognizer {
  /// Creates the recognizer. Prefer [create] in the app; tests inject everything.
  OnnxPhonemeRecognizer({
    required this.root,
    required ModelManifest manifest,
    required this._light,
    required ModelTransport transport,
    required NetworkMonitor network,
    required DeviceInfoSource deviceInfo,
    this._opener = OrtCtcModelSession.opener,
  }) : _manifest = manifest {
    _downloader = FullModelDownloader(
      files: manifest.filesFor(ModelTier.full),
      dir: Directory('${root.path}/full'),
      transport: transport,
      network: network,
    );
    _advisor = TierAdvisor(
      device: deviceInfo,
      benchmark: benchmarkLight,
      cacheFile: File('${root.path}/tier.json'),
    );
  }

  /// The production recognizer: models under the app-support folder, light model
  /// from the asset bundle, full model over HTTPS on Wi-Fi.
  static Future<OnnxPhonemeRecognizer> create({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/models');
    final manifest = await loadBundledManifest(assets);
    return OnnxPhonemeRecognizer(
      root: root,
      manifest: manifest,
      light: BundledLightModel(
        bundle: assets,
        manifest: manifest,
        dir: Directory('${root.path}/light'),
      ),
      transport: HttpModelTransport(),
      network: platformNetworkMonitor(),
      deviceInfo: PluginDeviceInfoSource(),
    );
  }

  /// Folder holding the installed models.
  final Directory root;

  final ModelManifest _manifest;
  final LightModelSource _light;
  final CtcSessionOpener _opener;
  late final FullModelDownloader _downloader;
  late final TierAdvisor _advisor;
  InferenceWorker? _worker;
  Future<InferenceWorker>? _spawning;
  Future<void>? _restored;
  ModelTier? _loaded;
  Future<void> _queue = Future.value();
  var _disposed = false;

  Future<void> _ready() => _restored ??= _downloader.restore();

  Future<InferenceWorker> _ensureWorker() async {
    final existing = _worker;
    if (existing != null) return existing;
    final spawning = _spawning ??= InferenceWorker.spawn(opener: _opener);
    return _worker = await spawning;
  }

  /// Runs [action] after every earlier load / unload, so they never interleave.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  void _checkAlive() {
    if (_disposed) throw StateError('PhonemeRecognizer used after dispose');
  }

  Future<ModelFiles?> _filesFor(ModelTier tier) async {
    switch (tier) {
      case ModelTier.light:
        return _light.resolve();
      case ModelTier.full:
        await _ready();
        if (!await _downloader.isComplete()) return null;
        final pair = _manifest.pairFor(ModelTier.full)!;
        return ModelFiles(
          _downloader.fileFor(pair.model).path,
          _downloader.fileFor(pair.vocab).path,
        );
    }
  }

  @override
  Future<ModelTier> recommendedTier() {
    _checkAlive();
    return _advisor.recommend();
  }

  /// Times the light model on 5 s of synthetic audio in a throwaway isolate (so the
  /// loaded model is untouched). Null when the light model cannot run.
  Future<Duration?> benchmarkLight() async {
    final files = await _light.resolve();
    if (files == null) return null;
    InferenceWorker? worker;
    final wav = File('${root.path}/benchmark.wav');
    try {
      await root.create(recursive: true);
      final random = math.Random(1);
      final samples = Float32List.fromList([
        for (var i = 0; i < 5 * modelSampleRate; i++)
          0.1 * math.sin(i * 0.05) + 0.01 * (random.nextDouble() - 0.5),
      ]);
      await wav.writeAsBytes(encodePcm16Wav(samples));
      worker = await InferenceWorker.spawn(opener: _opener);
      await worker.load(files.modelPath, files.vocabPath);
      await worker.recognise(wav.path); // warm-up
      final timed = await worker.recognise(wav.path);
      return Duration(microseconds: timed.inferenceMicros);
    } on Object {
      return null;
    } finally {
      await worker?.close();
      if (wav.existsSync()) wav.deleteSync();
    }
  }

  @override
  Future<bool> isTierAvailable(ModelTier tier) async {
    _checkAlive();
    return await _filesFor(tier) != null;
  }

  @override
  ModelTier? get loadedTier => _loaded;

  /// Time the model itself took in the last [recognise] (excludes WAV decoding,
  /// normalisation and isolate hops), for diagnostics and benchmarks.
  Duration? get lastInferenceTime => _lastInference;
  Duration? _lastInference;

  @override
  Future<void> load(ModelTier tier) {
    _checkAlive();
    return _serial(() async {
      if (_loaded == tier) return;
      final files = await _filesFor(tier);
      if (files == null) throw ModelNotAvailableException(tier);
      final worker = await _ensureWorker();
      await worker.load(files.modelPath, files.vocabPath);
      _loaded = tier;
    });
  }

  @override
  Future<PhonemePosteriors> recognise(AudioClip clip) {
    _checkAlive();
    if (_loaded == null) {
      return Future.error(StateError('No model loaded'));
    }
    if (clip.sampleRate != modelSampleRate) {
      return Future.error(
        ArgumentError.value(
          clip.sampleRate,
          'clip.sampleRate',
          'must be $modelSampleRate',
        ),
      );
    }
    // Queued behind any pending load, so the tier label always matches the model
    // that produced the frames.
    return _serial(() async {
      final tier = _loaded;
      final worker = _worker;
      if (tier == null || worker == null) throw StateError('No model loaded');
      final out = await worker.recognise(clip.path);
      _lastInference = Duration(microseconds: out.inferenceMicros);
      return PhonemePosteriors(
        vocab: out.vocab,
        frames: splitFrames(out.logProbs, out.vocab.length),
        blankIndex: out.blankIndex,
        frameMs: modelFrameMs,
        tier: tier,
      );
    });
  }

  /// How live recognition cuts recordings ([startLiveRecognition]).
  LiveChunking liveChunking = const LiveChunking();

  /// The session [startLiveRecognition] returned last (for benchmarks).
  LiveRecognitionSession? get lastLiveRecognition => _lastLive;
  LiveRecognitionSession? _lastLive;

  @override
  LiveRecognitionSession startLiveRecognition() {
    _checkAlive();
    return _lastLive = LiveRecognitionSession(
      recognise: _recogniseSamples,
      wholeClip: recognise,
      loadedTier: () => _loaded,
      settings: liveChunking,
      frameMs: modelFrameMs,
    );
  }

  /// Runs one piece of a live recording, queued like [recognise] (so behind any
  /// pending load, with the tier of the model that ran).
  Future<ChunkPosteriors?> _recogniseSamples(
    Float32List samples, {
    required bool Function() skip,
  }) {
    if (_disposed) return Future.error(StateError('Recognizer disposed'));
    return _serial(() async {
      if (skip()) return null;
      final tier = _loaded;
      final worker = _worker;
      if (tier == null || worker == null) throw StateError('No model loaded');
      final out = await worker.recogniseSamples(samples);
      return ChunkPosteriors(
        tier: tier,
        logProbs: out.logProbs,
        frames: out.frames,
        vocab: out.vocab,
        blankIndex: out.blankIndex,
      );
    });
  }

  @override
  int get fullModelSizeBytes =>
      _manifest.sizeOf(ModelTier.full) ?? fallbackFullModelBytes;

  @override
  ModelDownloadProgress get downloadStatus => _downloader.status;

  @override
  Stream<ModelDownloadProgress> get downloadProgress => _downloader.progress;

  @override
  Future<void> downloadFullModel({bool requireWifi = true}) async {
    _checkAlive();
    await _ready();
    await _downloader.download(requireWifi: requireWifi);
  }

  @override
  Future<void> cancelDownload() => _downloader.cancel();

  @override
  Future<void> deleteFullModel() async {
    _checkAlive();
    await _ready();
    await _serial(() async {
      if (_loaded == ModelTier.full) {
        await _worker?.unload();
        _loaded = null;
      }
    });
    await _downloader.delete();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _loaded = null;
    await _downloader.close();
    final worker = _worker ?? await _spawning;
    await worker?.close();
  }
}
