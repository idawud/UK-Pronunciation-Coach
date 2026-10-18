import '../models/attempt_result.dart';
import '../models/daily_progress.dart';
import '../models/level_change.dart';
import '../models/passage.dart';
import '../models/review_item.dart';
import '../models/sound_stat.dart';

/// Practice logic (C3): level rules, passage choice, spaced review, placement, streaks.
/// Built on `ContentRepository` and `ProgressRepository`; time comes from a `Clock`.
abstract interface class PracticeEngine {
  /// The user's current level, 1-6.
  Future<int> currentLevel();

  /// Chooses the next passage: 70% current level weighted to the 3 weakest sounds, 20%
  /// a passage containing previously missed words, 10% a preview of the next level.
  /// Avoids passages read in the last 10 sessions where possible.
  ///
  /// With [soundTag], returns a passage at or below `currentLevel() + 1` tagged with it
  /// (falling back to any level when none is). Never throws for an empty history.
  Future<Passage> nextPassage({String? soundTag});

  /// Records a scored passage attempt. Saves it through `ProgressRepository.saveAttempt`
  /// (callers must not save it again), enqueues its red words for review, reschedules
  /// queued words it contains, updates the streak, and applies the level rules:
  /// up after 3 passages in a row at 85+, down after 3 in a row under 60 (levels stay
  /// within 1-6; the run restarts after a change).
  ///
  /// Returns the [LevelChange] (also saved to the level history) or null.
  Future<LevelChange?> recordAttempt(AttemptResult result);

  /// Words due for review now (as written in the review queue), soonest due first.
  Future<List<String>> dueReviewWords();

  /// Review items due now, soonest due first (with phonemes, for Fix a word).
  Future<List<ReviewItem>> dueReviews();

  /// The [count] weakest sounds, weakest first.
  Future<List<SoundStat>> weakestSounds({int count = 3});

  /// Adds [duration] of practice starting now (time spent reading, retrying, listening).
  Future<void> logPracticeTime(Duration duration);

  /// Today's minutes, the goal, the streak and practised days (device time zone).
  /// The streak breaks after a whole local day without practice.
  Future<DailyProgress> dailyProgress();

  /// The placement passages (levels 1, 3, 5) for the first-run test.
  Future<List<Passage>> placementPassages();

  /// The starting level (1-6) for placement [results] (one per placement passage, in
  /// order). Pure: does not save anything. Higher scores never give a lower level.
  int placementLevel(List<AttemptResult> results);

  /// Finishes placement: sets the profile's level to [placementLevel], `placementDone`
  /// and `placementLevel`. Placement attempts are not saved as practice attempts.
  /// Returns the change from the previous level (saved to the history), or null when
  /// the level is unchanged.
  Future<LevelChange?> completePlacement(List<AttemptResult> results);
}
