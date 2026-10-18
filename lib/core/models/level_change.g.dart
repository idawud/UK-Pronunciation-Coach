// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'level_change.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LevelChange _$LevelChangeFromJson(Map<String, dynamic> json) => _LevelChange(
  from: (json['from'] as num).toInt(),
  to: (json['to'] as num).toInt(),
  reason: json['reason'] as String,
  at: DateTime.parse(json['at'] as String),
);

Map<String, dynamic> _$LevelChangeToJson(_LevelChange instance) =>
    <String, dynamic>{
      'from': instance.from,
      'to': instance.to,
      'reason': instance.reason,
      'at': instance.at.toIso8601String(),
    };
