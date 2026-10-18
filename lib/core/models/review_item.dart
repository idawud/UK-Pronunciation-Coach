import 'package:freezed_annotation/freezed_annotation.dart';

import 'phoneme_spec.dart';

part 'review_item.freezed.dart';
part 'review_item.g.dart';

/// A word in the spaced-review queue. The schedule rule lives here so C2
/// (`ProgressRepository.updateWordResult`) and C3 (`PracticeEngine`) apply the same one.
///
/// Intervals are 1, 3, 7 and 21 calendar days ([intervals]). A score of 80+ advances a
/// stage (past the last stage the word graduates and leaves the queue); under 60 resets
/// to the first stage; 60-79 repeats the current interval.
@freezed
abstract class ReviewItem with _$ReviewItem {
  const ReviewItem._();

  /// Review intervals in days, by stage.
  static const List<int> intervals = [1, 3, 7, 21];

  /// Score at or above which a review advances.
  static const int advanceAt = 80;

  /// Score below which a review resets.
  static const int resetBelow = 60;

  /// - [word]: the word as written; the queue is keyed by `word.toLowerCase()` ([key]).
  /// - [phonemes]: expected phonemes, so Fix a word can open without a dictionary lookup.
  /// - [due]: when it is next due (local time).
  /// - [intervalDays]: current interval, `intervals[stage]`.
  /// - [ease]: SM-2 style ease, informational (2.5 start, +0.1 on advance, -0.2 on reset,
  ///   floor 1.3).
  /// - [stage]: index into [intervals].
  /// - [lastScore]: most recent score for the word.
  /// - [passageId]: passage the word was missed in, if known.
  const factory ReviewItem({
    required String word,
    @Default(<PhonemeSpec>[]) List<PhonemeSpec> phonemes,
    required DateTime due,
    required int intervalDays,
    @Default(2.5) double ease,
    @Default(0) int stage,
    int? lastScore,
    String? passageId,
  }) = _ReviewItem;

  /// Decodes from JSON.
  factory ReviewItem.fromJson(Map<String, dynamic> json) =>
      _$ReviewItemFromJson(json);

  /// A newly missed word: stage 0, due one calendar day after [now].
  factory ReviewItem.enqueue({
    required String word,
    List<PhonemeSpec> phonemes = const [],
    required DateTime now,
    int? score,
    String? passageId,
  }) => ReviewItem(
    word: word,
    phonemes: phonemes,
    due: addDays(now, intervals.first),
    intervalDays: intervals.first,
    lastScore: score,
    passageId: passageId,
  );

  /// Queue key: the lower-cased word.
  String get key => word.toLowerCase();

  /// True when due at or before [now].
  bool isDue(DateTime now) => !due.isAfter(now);

  /// Applies a new [score] at [now]. Returns the rescheduled item, or null when the
  /// word graduates (advanced past the 21-day stage) and should leave the queue.
  ReviewItem? afterScore(int score, DateTime now) {
    if (score >= advanceAt) {
      final next = stage + 1;
      if (next >= intervals.length) return null;
      return copyWith(
        stage: next,
        intervalDays: intervals[next],
        due: addDays(now, intervals[next]),
        ease: ease + 0.1,
        lastScore: score,
      );
    }
    if (score < resetBelow) {
      return copyWith(
        stage: 0,
        intervalDays: intervals.first,
        due: addDays(now, intervals.first),
        ease: (ease - 0.2) < 1.3 ? 1.3 : ease - 0.2,
        lastScore: score,
      );
    }
    return copyWith(due: addDays(now, intervalDays), lastScore: score);
  }

  /// Adds [days] calendar days to [t], keeping the wall-clock time (safe across
  /// daylight-saving changes, unlike adding `Duration(days: n)`).
  static DateTime addDays(DateTime t, int days) => t.isUtc
      ? DateTime.utc(
          t.year,
          t.month,
          t.day + days,
          t.hour,
          t.minute,
          t.second,
          t.millisecond,
          t.microsecond,
        )
      : DateTime(
          t.year,
          t.month,
          t.day + days,
          t.hour,
          t.minute,
          t.second,
          t.millisecond,
          t.microsecond,
        );
}
