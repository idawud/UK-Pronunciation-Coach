// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DailyProgress _$DailyProgressFromJson(Map<String, dynamic> json) =>
    _DailyProgress(
      streak: (json['streak'] as num).toInt(),
      minutesToday: (json['minutesToday'] as num).toInt(),
      dailyGoalMinutes: (json['dailyGoalMinutes'] as num).toInt(),
      practisedDays:
          (json['practisedDays'] as List<dynamic>?)
              ?.map((e) => DateTime.parse(e as String))
              .toList() ??
          const <DateTime>[],
    );

Map<String, dynamic> _$DailyProgressToJson(_DailyProgress instance) =>
    <String, dynamic>{
      'streak': instance.streak,
      'minutesToday': instance.minutesToday,
      'dailyGoalMinutes': instance.dailyGoalMinutes,
      'practisedDays': instance.practisedDays
          .map((e) => e.toIso8601String())
          .toList(),
    };
