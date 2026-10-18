import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_progress.freezed.dart';
part 'daily_progress.g.dart';

/// Streak and daily-goal summary for Home and Progress (from `PracticeEngine.dailyProgress`).
@freezed
abstract class DailyProgress with _$DailyProgress {
  const DailyProgress._();

  /// - [streak]: consecutive local days with practice, counting today if practised
  ///   (or up to yesterday if not yet practised today).
  /// - [minutesToday]: whole minutes practised today (local day).
  /// - [dailyGoalMinutes]: from the profile.
  /// - [practisedDays]: local dates (midnight, time zone of the device) with practice,
  ///   ascending; used for the streak calendar.
  const factory DailyProgress({
    required int streak,
    required int minutesToday,
    required int dailyGoalMinutes,
    @Default(<DateTime>[]) List<DateTime> practisedDays,
  }) = _DailyProgress;

  /// Decodes from JSON.
  factory DailyProgress.fromJson(Map<String, dynamic> json) =>
      _$DailyProgressFromJson(json);

  /// True once today's minutes reach the goal.
  bool get goalMet => minutesToday >= dailyGoalMinutes;
}
