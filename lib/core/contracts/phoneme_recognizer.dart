import '../models/audio_clip.dart';
import '../models/enums.dart';
import '../models/model_download_progress.dart';
import '../models/phoneme_posteriors.dart';

/// Runs the on-device CTC phoneme model (A2). The only component allowed to use the
/// network, and only for the one-time full-model download over Wi-Fi.
abstract interface class PhonemeRecognizer {
  /// The tier this device should use: [ModelTier.light] on devices under 4 GB RAM or
  /// older than iPhone XS / Android 10-class hardware, else [ModelTier.full].
  /// May time a short clip on first run; the answer is cached. Settings can override it
  /// (`UserProfile.tierOverride`).
  Future<ModelTier> recommendedTier();

  /// Whether [tier]'s model files are on the device and verified. Light is always
  /// available (bundled); full only after [downloadFullModel] completed.
  Future<bool> isTierAvailable(ModelTier tier);

  /// The tier currently loaded, or null before the first successful [load].
  ModelTier? get loadedTier;

  /// Loads [tier]'s model, replacing any loaded model. Calling it again for the loaded
  /// tier is a cheap no-op. Throws [ModelNotAvailableException] when the tier is not on
  /// the device.
  Future<void> load(ModelTier tier);

  /// Runs the loaded model on [clip] in a background isolate and returns per-frame
  /// log-probabilities (20 ms frames, `tier` = [loadedTier]).
  ///
  /// The waveform is zero-mean / unit-variance normalised first. Frame count is about
  /// `clip.duration / 20 ms`. Throws [StateError] if no model is loaded.
  Future<PhonemePosteriors> recognise(AudioClip clip);

  /// Size of the full-tier download in bytes, for the Settings "Download (N MB)" label.
  int get fullModelSizeBytes;

  /// Current state of the full-model download.
  ModelDownloadProgress get downloadStatus;

  /// Every change of [downloadStatus] (broadcast).
  Stream<ModelDownloadProgress> get downloadProgress;

  /// Downloads the full model once, resuming a partial download, then checks its
  /// SHA-256. With [requireWifi] it waits in [DownloadState.waitingForWifi] until an
  /// unmetered connection is available. Completes when the state is
  /// [DownloadState.completed] (immediately if already completed). Throws
  /// [ModelDownloadException] on failure (state [DownloadState.failed]).
  Future<void> downloadFullModel({bool requireWifi = true});

  /// Cancels a running download, keeping the partial file for resume
  /// (state [DownloadState.cancelled]). No-op when nothing is running.
  Future<void> cancelDownload();

  /// Deletes the downloaded full model (state back to [DownloadState.idle]). If the
  /// full tier is loaded, unloads it ([loadedTier] becomes null).
  Future<void> deleteFullModel();

  /// Releases the model and isolate. The recognizer must not be used afterwards.
  Future<void> dispose();
}
