/// Spaced-review updates for one attempt. Pure Dart; the interval rule itself is
/// `ReviewItem.afterScore` / `ReviewItem.enqueue` (shared with C2).
library;

import '../core/models/enums.dart';
import '../core/models/phoneme_spec.dart';
import '../core/models/review_item.dart';
import '../core/models/word_result.dart';

/// What to write to the review queue after an attempt.
class ReviewUpdates {
  /// Creates the updates.
  const ReviewUpdates({required this.upserts, required this.removals});

  /// Items to insert or replace.
  final List<ReviewItem> upserts;

  /// Words that graduated and leave the queue.
  final List<String> removals;
}

/// Computes review-queue changes for the scored [words] of an attempt at [now].
///
/// Each word is handled once per attempt, by its lowest score there (a word read twice,
/// once badly, counts as badly). Unscored words are ignored. A queued word is
/// rescheduled with [ReviewItem.afterScore] (or removed when it graduates); an unqueued
/// red word ([WordStatus.isRed]) is enqueued with [ReviewItem.enqueue], taking its
/// phonemes from [phonemesFor].
ReviewUpdates reviewUpdatesFor({
  required List<WordResult> words,
  required Map<String, ReviewItem> queue,
  required DateTime now,
  required List<PhonemeSpec> Function(WordResult word) phonemesFor,
  String? passageId,
}) {
  final worst = <String, WordResult>{};
  for (final w in words) {
    if (w.status == WordStatus.notScored) continue;
    final key = w.text.toLowerCase();
    final seen = worst[key];
    if (seen == null || w.score < seen.score) worst[key] = w;
  }
  final upserts = <ReviewItem>[];
  final removals = <String>[];
  for (final MapEntry(:key, value: w) in worst.entries) {
    final queued = queue[key];
    if (queued != null) {
      final next = queued.afterScore(w.score, now);
      if (next == null) {
        removals.add(queued.word);
      } else {
        upserts.add(next);
      }
    } else if (w.status.isRed) {
      upserts.add(
        ReviewItem.enqueue(
          word: w.text,
          phonemes: phonemesFor(w),
          now: now,
          score: w.score,
          passageId: passageId,
        ),
      );
    }
  }
  return ReviewUpdates(upserts: upserts, removals: removals);
}
