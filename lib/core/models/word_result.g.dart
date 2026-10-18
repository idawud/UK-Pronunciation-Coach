// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WordResult _$WordResultFromJson(Map<String, dynamic> json) => _WordResult(
  index: (json['index'] as num).toInt(),
  text: json['text'] as String,
  score: (json['score'] as num).toInt(),
  phonemes:
      (json['phonemes'] as List<dynamic>?)
          ?.map((e) => PhonemeResult.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PhonemeResult>[],
  status: $enumDecode(_$WordStatusEnumMap, json['status']),
);

Map<String, dynamic> _$WordResultToJson(_WordResult instance) =>
    <String, dynamic>{
      'index': instance.index,
      'text': instance.text,
      'score': instance.score,
      'phonemes': instance.phonemes.map((e) => e.toJson()).toList(),
      'status': _$WordStatusEnumMap[instance.status]!,
    };

const _$WordStatusEnumMap = {
  WordStatus.good: 'good',
  WordStatus.close: 'close',
  WordStatus.fix: 'fix',
  WordStatus.notScored: 'notScored',
  WordStatus.missed: 'missed',
};
