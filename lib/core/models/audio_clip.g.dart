// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_clip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AudioClip _$AudioClipFromJson(Map<String, dynamic> json) => _AudioClip(
  path: json['path'] as String,
  sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 16000,
  duration: Duration(microseconds: (json['duration'] as num).toInt()),
  quality:
      $enumDecodeNullable(_$AudioQualityEnumMap, json['quality']) ??
      AudioQuality.ok,
  peakDbfs: (json['peakDbfs'] as num?)?.toDouble(),
  snrDb: (json['snrDb'] as num?)?.toDouble(),
);

Map<String, dynamic> _$AudioClipToJson(_AudioClip instance) =>
    <String, dynamic>{
      'path': instance.path,
      'sampleRate': instance.sampleRate,
      'duration': instance.duration.inMicroseconds,
      'quality': _$AudioQualityEnumMap[instance.quality]!,
      'peakDbfs': instance.peakDbfs,
      'snrDb': instance.snrDb,
    };

const _$AudioQualityEnumMap = {
  AudioQuality.ok: 'ok',
  AudioQuality.tooQuiet: 'tooQuiet',
  AudioQuality.tooNoisy: 'tooNoisy',
};
