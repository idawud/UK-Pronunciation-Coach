// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_backup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProgressBackup _$ProgressBackupFromJson(Map<String, dynamic> json) =>
    _ProgressBackup(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ??
          ProgressBackup.currentSchemaVersion,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      attempts:
          (json['attempts'] as List<dynamic>?)
              ?.map((e) => AttemptResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AttemptResult>[],
      soundStats:
          (json['soundStats'] as List<dynamic>?)
              ?.map((e) => SoundStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SoundStat>[],
      reviewQueue:
          (json['reviewQueue'] as List<dynamic>?)
              ?.map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ReviewItem>[],
      levelHistory:
          (json['levelHistory'] as List<dynamic>?)
              ?.map((e) => LevelChange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LevelChange>[],
      practiceSessions:
          (json['practiceSessions'] as List<dynamic>?)
              ?.map((e) => PracticeSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PracticeSession>[],
    );

Map<String, dynamic> _$ProgressBackupToJson(
  _ProgressBackup instance,
) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'exportedAt': instance.exportedAt.toIso8601String(),
  'profile': instance.profile.toJson(),
  'attempts': instance.attempts.map((e) => e.toJson()).toList(),
  'soundStats': instance.soundStats.map((e) => e.toJson()).toList(),
  'reviewQueue': instance.reviewQueue.map((e) => e.toJson()).toList(),
  'levelHistory': instance.levelHistory.map((e) => e.toJson()).toList(),
  'practiceSessions': instance.practiceSessions.map((e) => e.toJson()).toList(),
};
