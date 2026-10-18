import 'dart:async';

import '../contracts/errors.dart';
import '../contracts/phoneme_recognizer.dart';
import '../models/models.dart';
import 'sample_data.dart';

/// Working [PhonemeRecognizer] that returns synthetic posteriors and simulates the
/// full-model download. No model files, no network.
class FakePhonemeRecognizer implements PhonemeRecognizer {
  /// Creates the fake. By default [recognise] returns posteriors matching
  /// `cannedRiverAttempt`; pass [posteriorsFor] to change that.
  FakePhonemeRecognizer({
    this.recommended = ModelTier.full,
    this.fullAvailable = false,
    this.failDownload = false,
    this.downloadSteps = 4,
    this.stepDelay = Duration.zero,
    this._posteriorsFor,
  });

  /// Value of [recommendedTier].
  ModelTier recommended;

  /// Whether the full tier is already downloaded.
  bool fullAvailable;

  /// Make [downloadFullModel] fail with a checksum error.
  bool failDownload;

  /// Number of progress events while downloading.
  int downloadSteps;

  /// Delay between progress events.
  Duration stepDelay;

  /// Number of [recognise] calls.
  int recogniseCount = 0;

  final PhonemePosteriors Function(AudioClip clip)? _posteriorsFor;
  final _progress = StreamController<ModelDownloadProgress>.broadcast();
  ModelTier? _loaded;
  ModelDownloadProgress _status = ModelDownloadProgress.idle;
  bool _cancelRequested = false;

  @override
  Future<ModelTier> recommendedTier() async => recommended;

  @override
  Future<bool> isTierAvailable(ModelTier tier) async =>
      tier == ModelTier.light || fullAvailable;

  @override
  ModelTier? get loadedTier => _loaded;

  @override
  Future<void> load(ModelTier tier) async {
    if (!await isTierAvailable(tier)) throw ModelNotAvailableException(tier);
    _loaded = tier;
  }

  @override
  Future<PhonemePosteriors> recognise(AudioClip clip) async {
    final tier = _loaded;
    if (tier == null) throw StateError('No model loaded');
    recogniseCount++;
    final p = _posteriorsFor?.call(clip) ?? riverPosteriors;
    return p.copyWith(tier: tier);
  }

  @override
  int get fullModelSizeBytes => 320 * 1024 * 1024;

  @override
  ModelDownloadProgress get downloadStatus => _status;

  @override
  Stream<ModelDownloadProgress> get downloadProgress => _progress.stream;

  void _emit(ModelDownloadProgress p) {
    _status = p;
    _progress.add(p);
  }

  @override
  Future<void> downloadFullModel({bool requireWifi = true}) async {
    if (fullAvailable) {
      if (_status.state != DownloadState.completed) {
        _emit(
          ModelDownloadProgress(
            state: DownloadState.completed,
            receivedBytes: fullModelSizeBytes,
            totalBytes: fullModelSizeBytes,
          ),
        );
      }
      return;
    }
    _cancelRequested = false;
    final total = fullModelSizeBytes;
    final already = _status.receivedBytes;
    for (var i = 1; i <= downloadSteps; i++) {
      await Future<void>.delayed(stepDelay);
      if (_cancelRequested) {
        _emit(_status.copyWith(state: DownloadState.cancelled));
        throw const ModelDownloadException('Cancelled');
      }
      final received = already + ((total - already) * i ~/ downloadSteps);
      _emit(
        ModelDownloadProgress(
          state: DownloadState.downloading,
          receivedBytes: received,
          totalBytes: total,
        ),
      );
    }
    _emit(_status.copyWith(state: DownloadState.verifying));
    await Future<void>.delayed(stepDelay);
    if (failDownload) {
      _emit(
        ModelDownloadProgress(
          state: DownloadState.failed,
          totalBytes: total,
          error: 'Checksum mismatch',
        ),
      );
      throw const ModelDownloadException('Checksum mismatch');
    }
    fullAvailable = true;
    _emit(
      ModelDownloadProgress(
        state: DownloadState.completed,
        receivedBytes: total,
        totalBytes: total,
      ),
    );
  }

  @override
  Future<void> cancelDownload() async {
    if (_status.isActive) _cancelRequested = true;
  }

  @override
  Future<void> deleteFullModel() async {
    fullAvailable = false;
    if (_loaded == ModelTier.full) _loaded = null;
    _emit(ModelDownloadProgress.idle);
  }

  @override
  Future<void> dispose() async {
    _loaded = null;
    await _progress.close();
  }
}
