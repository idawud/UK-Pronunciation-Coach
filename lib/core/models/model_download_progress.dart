import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'model_download_progress.freezed.dart';
part 'model_download_progress.g.dart';

/// Progress of the optional full-model download (A2 emits, U2/U4 show).
@freezed
abstract class ModelDownloadProgress with _$ModelDownloadProgress {
  const ModelDownloadProgress._();

  /// - [state]: see [DownloadState].
  /// - [receivedBytes]: bytes on disk so far (survives resume).
  /// - [totalBytes]: full size in bytes (known up front from the model manifest).
  /// - [error]: short human-readable reason when [state] is [DownloadState.failed].
  const factory ModelDownloadProgress({
    required DownloadState state,
    @Default(0) int receivedBytes,
    @Default(0) int totalBytes,
    String? error,
  }) = _ModelDownloadProgress;

  /// Decodes from JSON.
  factory ModelDownloadProgress.fromJson(Map<String, dynamic> json) =>
      _$ModelDownloadProgressFromJson(json);

  /// Nothing started.
  static const idle = ModelDownloadProgress(state: DownloadState.idle);

  /// 0.0-1.0 (0 when [totalBytes] is unknown).
  double get fraction =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);

  /// True while waiting, downloading or verifying.
  bool get isActive =>
      state == DownloadState.waitingForWifi ||
      state == DownloadState.downloading ||
      state == DownloadState.verifying;
}
