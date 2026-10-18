// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReviewItem _$ReviewItemFromJson(Map<String, dynamic> json) => _ReviewItem(
  word: json['word'] as String,
  phonemes:
      (json['phonemes'] as List<dynamic>?)
          ?.map((e) => PhonemeSpec.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PhonemeSpec>[],
  due: DateTime.parse(json['due'] as String),
  intervalDays: (json['intervalDays'] as num).toInt(),
  ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
  stage: (json['stage'] as num?)?.toInt() ?? 0,
  lastScore: (json['lastScore'] as num?)?.toInt(),
  passageId: json['passageId'] as String?,
);

Map<String, dynamic> _$ReviewItemToJson(_ReviewItem instance) =>
    <String, dynamic>{
      'word': instance.word,
      'phonemes': instance.phonemes.map((e) => e.toJson()).toList(),
      'due': instance.due.toIso8601String(),
      'intervalDays': instance.intervalDays,
      'ease': instance.ease,
      'stage': instance.stage,
      'lastScore': instance.lastScore,
      'passageId': instance.passageId,
    };
