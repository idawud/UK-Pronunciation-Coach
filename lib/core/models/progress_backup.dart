import 'package:freezed_annotation/freezed_annotation.dart';

import 'attempt_result.dart';
import 'level_change.dart';
import 'practice_session.dart';
import 'review_item.dart';
import 'sound_stat.dart';
import 'user_profile.dart';

part 'progress_backup.freezed.dart';
part 'progress_backup.g.dart';

/// The progress export file format (`ProgressRepository.exportJson` / `importJson`).
/// Also read by R1's beta report script. Bump [schemaVersion] on breaking changes.
@freezed
abstract class ProgressBackup with _$ProgressBackup {
  /// Current export schema version.
  static const int currentSchemaVersion = 1;

  /// All user data. Recordings are not included.
  const factory ProgressBackup({
    @Default(ProgressBackup.currentSchemaVersion) int schemaVersion,
    required DateTime exportedAt,
    required UserProfile profile,
    @Default(<AttemptResult>[]) List<AttemptResult> attempts,
    @Default(<SoundStat>[]) List<SoundStat> soundStats,
    @Default(<ReviewItem>[]) List<ReviewItem> reviewQueue,
    @Default(<LevelChange>[]) List<LevelChange> levelHistory,
    @Default(<PracticeSession>[]) List<PracticeSession> practiceSessions,
  }) = _ProgressBackup;

  /// Decodes from JSON.
  factory ProgressBackup.fromJson(Map<String, dynamic> json) =>
      _$ProgressBackupFromJson(json);
}
