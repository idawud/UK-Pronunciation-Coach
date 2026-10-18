// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phoneme_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PhonemeResult _$PhonemeResultFromJson(Map<String, dynamic> json) =>
    _PhonemeResult(
      expected: json['expected'] as String,
      heard: json['heard'] as String?,
      score: (json['score'] as num).toInt(),
      start: Duration(microseconds: (json['start'] as num).toInt()),
      end: Duration(microseconds: (json['end'] as num).toInt()),
    );

Map<String, dynamic> _$PhonemeResultToJson(_PhonemeResult instance) =>
    <String, dynamic>{
      'expected': instance.expected,
      'heard': instance.heard,
      'score': instance.score,
      'start': instance.start.inMicroseconds,
      'end': instance.end.inMicroseconds,
    };
