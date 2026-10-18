import '../models/enums.dart';

/// Thrown by `AudioRecorder.start` when the microphone permission is not granted.
class MicPermissionException implements Exception {
  /// [state] is [MicPermission.denied] or [MicPermission.permanentlyDenied].
  const MicPermissionException(this.state);

  /// The permission state that blocked recording.
  final MicPermission state;

  @override
  String toString() => 'MicPermissionException($state)';
}

/// Thrown by `PhonemeRecognizer.load` when the requested tier's files are not on the
/// device (e.g. [ModelTier.full] before it has been downloaded).
class ModelNotAvailableException implements Exception {
  /// Creates the exception for [tier].
  const ModelNotAvailableException(this.tier);

  /// The tier that could not be loaded.
  final ModelTier tier;

  @override
  String toString() => 'ModelNotAvailableException($tier)';
}

/// Thrown by `PhonemeRecognizer.downloadFullModel` when the download fails or the
/// SHA-256 does not match.
class ModelDownloadException implements Exception {
  /// Creates the exception with a short human-readable [message].
  const ModelDownloadException(this.message);

  /// Why the download failed.
  final String message;

  @override
  String toString() => 'ModelDownloadException: $message';
}

/// Thrown by `ContentRepository.byId` for an unknown passage id.
class PassageNotFoundException implements Exception {
  /// Creates the exception for [id].
  const PassageNotFoundException(this.id);

  /// The id that was not found.
  final String id;

  @override
  String toString() => 'PassageNotFoundException($id)';
}

/// Thrown by `ProgressRepository.updateWordResult` for an unknown attempt id.
class AttemptNotFoundException implements Exception {
  /// Creates the exception for [id].
  const AttemptNotFoundException(this.id);

  /// The id that was not found.
  final String id;

  @override
  String toString() => 'AttemptNotFoundException($id)';
}
