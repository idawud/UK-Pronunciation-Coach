// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'practice_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PracticeSession _$PracticeSessionFromJson(Map<String, dynamic> json) =>
    _PracticeSession(
      start: DateTime.parse(json['start'] as String),
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
    );

Map<String, dynamic> _$PracticeSessionToJson(_PracticeSession instance) =>
    <String, dynamic>{
      'start': instance.start.toIso8601String(),
      'duration': instance.duration.inMicroseconds,
    };
