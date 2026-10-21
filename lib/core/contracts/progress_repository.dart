import '../models/attempt_result.dart';
import '../models/level_change.dart';
import '../models/practice_session.dart';
import '../models/review_item.dart';
import '../models/sound_stat.dart';
import '../models/user_profile.dart';
import '../models/word_result.dart';

/// Local storage for everything the user does (C2: drift / SQLite). Nothing leaves the
/// device except through [exportJson], which the user triggers.
abstract interface class ProgressRepository {
  /// Emits after every write (save, update, import, delete). Broadcast; for refreshing
  /// UI providers.
  Stream<void> get changes;

  /// Saves (or replaces, by id) an attempt and its word results.
  ///
  /// Also folds every scored phoneme into the sound stats with [SoundStat.update] (or
  /// [SoundStat.first]). Unless `profile().keepRecordings` is true, deletes the file at
  /// `audioPath` and stores the attempt with `audioPath: null`. Does not touch the
  /// review queue or level (the practice engine does).
  ///
  /// Replacing an attempt folds its phonemes into the stats again (an average cannot
  /// be un-folded), so save each attempt once and use [updateWordResult] for retries.
  Future<void> saveAttempt(AttemptResult attempt);

  /// The attempt with [id], or null.
  Future<AttemptResult?> attempt(String id);

  /// Attempts, newest first, optionally only for [passageId], only at or after [since],
  /// and at most [limit]. Loading 1,000 attempts takes < 200 ms.
  Future<List<AttemptResult>> attempts({
    String? passageId,
    DateTime? since,
    int? limit,
  });

  /// Replaces the word at `word.index` of attempt [attemptId] with a retried [word] and
  /// returns the updated attempt. The attempt's overall, accuracy and fluency stay as
  /// first scored.
  ///
  /// Also folds the word's phoneme scores into the sound stats and updates the review
  /// queue: a queued word is rescheduled with [ReviewItem.afterScore] (and removed when
  /// it graduates); an unqueued word whose new status is red is enqueued. A word
  /// enqueued here has empty `ReviewItem.phonemes` (a [WordResult] has no stress
  /// marks); readers look the word up with `ContentRepository.lookup` when needed.
  ///
  /// Throws [AttemptNotFoundException] for an unknown attempt and [RangeError] for an
  /// index outside the attempt's words.
  Future<AttemptResult> updateWordResult(String attemptId, WordResult word);

  /// All sound stats, weakest first (ascending accuracy, ties by ipa).
  Future<List<SoundStat>> soundStats();

  /// The user profile; a default `UserProfile()` when none has been saved.
  Future<UserProfile> profile();

  /// Saves the user profile.
  Future<void> saveProfile(UserProfile profile);

  /// The whole review queue, soonest due first.
  Future<List<ReviewItem>> reviewQueue();

  /// Review items due at or before [now], soonest due first.
  Future<List<ReviewItem>> dueReviews(DateTime now);

  /// Inserts or replaces a review item, keyed by [ReviewItem.key].
  Future<void> upsertReview(ReviewItem item);

  /// Removes [word] (case-insensitive) from the review queue; no-op if absent.
  Future<void> removeReview(String word);

  /// Appends a level change to the history.
  Future<void> saveLevelChange(LevelChange change);

  /// Level changes, oldest first.
  Future<List<LevelChange>> levelHistory();

  /// Appends practice time (for daily minutes and streaks).
  Future<void> logPractice(PracticeSession session);

  /// Practice sessions, oldest first, optionally only those starting at or after [since].
  Future<List<PracticeSession>> practiceSessions({DateTime? since});

  /// All data as a `ProgressBackup` JSON document (recordings not included).
  Future<String> exportJson();

  /// Replaces all data with a `ProgressBackup` JSON document from [exportJson].
  /// Throws [FormatException] (and changes nothing) for invalid JSON or a newer
  /// unsupported `schemaVersion`.
  Future<void> importJson(String json);

  /// Deletes every attempt, stat, review item, level change, practice session and kept
  /// recording, and resets the profile to `UserProfile()`.
  Future<void> deleteAll();
}
