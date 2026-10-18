// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attempt_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AttemptResult _$AttemptResultFromJson(
  Map<String, dynamic> json,
) => _AttemptResult(
  id: json['id'] as String,
  passageId: json['passageId'] as String,
  at: DateTime.parse(json['at'] as String),
  overall: (json['overall'] as num).toInt(),
  accuracy: (json['accuracy'] as num).toInt(),
  fluency: (json['fluency'] as num).toInt(),
  words: (json['words'] as List<dynamic>)
      .map((e) => WordResult.fromJson(e as Map<String, dynamic>))
      .toList(),
  audioPath: json['audioPath'] as String?,
  tier: $enumDecodeNullable(_$ModelTierEnumMap, json['tier']) ?? ModelTier.full,
);

Map<String, dynamic> _$AttemptResultToJson(_AttemptResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'passageId': instance.passageId,
      'at': instance.at.toIso8601String(),
      'overall': instance.overall,
      'accuracy': instance.accuracy,
      'fluency': instance.fluency,
      'words': instance.words.map((e) => e.toJson()).toList(),
      'audioPath': instance.audioPath,
      'tier': _$ModelTierEnumMap[instance.tier]!,
    };

const _$ModelTierEnumMap = {ModelTier.light: 'light', ModelTier.full: 'full'};
