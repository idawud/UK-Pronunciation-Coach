// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
  level: (json['level'] as num?)?.toInt() ?? 1,
  dailyGoalMinutes: (json['dailyGoalMinutes'] as num?)?.toInt() ?? 10,
  streak: (json['streak'] as num?)?.toInt() ?? 0,
  lastPractice: json['lastPractice'] == null
      ? null
      : DateTime.parse(json['lastPractice'] as String),
  keepRecordings: json['keepRecordings'] as bool? ?? false,
  placementDone: json['placementDone'] as bool? ?? false,
  placementLevel: (json['placementLevel'] as num?)?.toInt(),
  reminderMinutes: (json['reminderMinutes'] as num?)?.toInt(),
  textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
  tierOverride: $enumDecodeNullable(_$ModelTierEnumMap, json['tierOverride']),
  onboardingDone: json['onboardingDone'] as bool? ?? false,
);

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'level': instance.level,
      'dailyGoalMinutes': instance.dailyGoalMinutes,
      'streak': instance.streak,
      'lastPractice': instance.lastPractice?.toIso8601String(),
      'keepRecordings': instance.keepRecordings,
      'placementDone': instance.placementDone,
      'placementLevel': instance.placementLevel,
      'reminderMinutes': instance.reminderMinutes,
      'textScale': instance.textScale,
      'tierOverride': _$ModelTierEnumMap[instance.tierOverride],
      'onboardingDone': instance.onboardingDone,
    };

const _$ModelTierEnumMap = {ModelTier.light: 'light', ModelTier.full: 'full'};
