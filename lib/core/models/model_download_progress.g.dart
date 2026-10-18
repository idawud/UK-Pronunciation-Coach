// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_download_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ModelDownloadProgress _$ModelDownloadProgressFromJson(
  Map<String, dynamic> json,
) => _ModelDownloadProgress(
  state: $enumDecode(_$DownloadStateEnumMap, json['state']),
  receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
  totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
  error: json['error'] as String?,
);

Map<String, dynamic> _$ModelDownloadProgressToJson(
  _ModelDownloadProgress instance,
) => <String, dynamic>{
  'state': _$DownloadStateEnumMap[instance.state]!,
  'receivedBytes': instance.receivedBytes,
  'totalBytes': instance.totalBytes,
  'error': instance.error,
};

const _$DownloadStateEnumMap = {
  DownloadState.idle: 'idle',
  DownloadState.waitingForWifi: 'waitingForWifi',
  DownloadState.downloading: 'downloading',
  DownloadState.verifying: 'verifying',
  DownloadState.completed: 'completed',
  DownloadState.failed: 'failed',
  DownloadState.cancelled: 'cancelled',
};
