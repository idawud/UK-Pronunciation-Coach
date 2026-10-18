import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

/// The single user's profile and settings (stored by C2).
@freezed
abstract class UserProfile with _$UserProfile {
  /// - [level]: current level 1-6.
  /// - [dailyGoalMinutes]: daily practice goal.
  /// - [streak]: consecutive local days with practice (maintained by C3).
  /// - [lastPractice]: last time any practice was logged.
  /// - [keepRecordings]: keep audio after scoring (off: delete after scoring).
  /// - [placementDone]: first-run placement finished.
  /// - [placementLevel]: level chosen by placement, if done.
  /// - [reminderMinutes]: daily reminder as minutes after local midnight; null = off.
  /// - [textScale]: passage text size multiplier (1.0 = 20 sp default).
  /// - [tierOverride]: model tier chosen in Settings; null = `recommendedTier()`.
  /// - [onboardingDone]: first-run flow finished (welcome, mic, voice check, placement).
  const factory UserProfile({
    @Default(1) int level,
    @Default(10) int dailyGoalMinutes,
    @Default(0) int streak,
    DateTime? lastPractice,
    @Default(false) bool keepRecordings,
    @Default(false) bool placementDone,
    int? placementLevel,
    int? reminderMinutes,
    @Default(1.0) double textScale,
    ModelTier? tierOverride,
    @Default(false) bool onboardingDone,
  }) = _UserProfile;

  /// Decodes from JSON.
  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
