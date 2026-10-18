// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sound_stat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SoundStat _$SoundStatFromJson(Map<String, dynamic> json) => _SoundStat(
  ipa: json['ipa'] as String,
  accuracy: (json['accuracy'] as num).toDouble(),
  attempts: (json['attempts'] as num).toInt(),
  lastPractised: DateTime.parse(json['lastPractised'] as String),
);

Map<String, dynamic> _$SoundStatToJson(_SoundStat instance) =>
    <String, dynamic>{
      'ipa': instance.ipa,
      'accuracy': instance.accuracy,
      'attempts': instance.attempts,
      'lastPractised': instance.lastPractised.toIso8601String(),
    };
