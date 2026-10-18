// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phoneme_posteriors.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PhonemePosteriors _$PhonemePosteriorsFromJson(
  Map<String, dynamic> json,
) => _PhonemePosteriors(
  vocab: (json['vocab'] as List<dynamic>).map((e) => e as String).toList(),
  frames: const Float32ListListConverter().fromJson(json['frames'] as List),
  blankIndex: (json['blankIndex'] as num?)?.toInt() ?? 0,
  frameMs: (json['frameMs'] as num?)?.toInt() ?? 20,
  tier: $enumDecodeNullable(_$ModelTierEnumMap, json['tier']) ?? ModelTier.full,
);

Map<String, dynamic> _$PhonemePosteriorsToJson(_PhonemePosteriors instance) =>
    <String, dynamic>{
      'vocab': instance.vocab,
      'frames': const Float32ListListConverter().toJson(instance.frames),
      'blankIndex': instance.blankIndex,
      'frameMs': instance.frameMs,
      'tier': _$ModelTierEnumMap[instance.tier]!,
    };

const _$ModelTierEnumMap = {ModelTier.light: 'light', ModelTier.full: 'full'};
