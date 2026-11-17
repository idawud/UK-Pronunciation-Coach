import '../../../core/models/models.dart';

/// Phonemes scored below this count as misheard (the same line as the red band,
/// [WordStatus.defaultClose]).
const int confusionMaxScore = 60;

/// How many example words a [Confusion] keeps.
const int confusionExampleCount = 3;

/// A sound the user often swaps: [expected] was the target and [heard] is what the
/// model heard instead. Both are IPA phonemes in the form of `PhonemeSpec.ipa`.
class Confusion {
  /// Creates a confusion.
  const Confusion({
    required this.expected,
    required this.heard,
    required this.count,
    required this.avgScore,
    this.exampleWords = const <String>[],
  });

  /// The phoneme the word needs, e.g. `ʌ`.
  final String expected;

  /// The phoneme the model heard instead, e.g. `æ`.
  final String heard;

  /// Number of misheard occurrences in the counted attempts.
  final int count;

  /// Mean phoneme score of those occurrences (0-100, below [confusionMaxScore]).
  final double avgScore;

  /// Distinct words where the confusion happened, newest attempt first.
  final List<String> exampleWords;

  /// The pair as a minimal-pair contrast string, expected first, e.g. `ʌ-æ`.
  String get contrast => '$expected-$heard';
}

/// Counts the (expected, heard) confusions in [attempts].
///
/// A phoneme counts when `heard` is set, differs from `expected` and the phoneme scored
/// below [confusionMaxScore]. Attempts before [since] are skipped. Confusions seen fewer
/// than [minCount] times are dropped. The result is sorted by count (most first), ties
/// by average score (lowest first).
///
/// Pure: no I/O, so it is unit tested directly.
List<Confusion> buildConfusions(
  List<AttemptResult> attempts, {
  int minCount = 2,
  DateTime? since,
}) {
  assert(minCount >= 1, 'minCount must be at least 1');
  final tallies = <(String, String), _Tally>{};
  for (final attempt in attempts) {
    if (since != null && attempt.at.isBefore(since)) continue;
    for (final word in attempt.words) {
      for (final phoneme in word.phonemes) {
        final heard = phoneme.heard;
        if (heard == null || heard == phoneme.expected) continue;
        if (phoneme.score >= confusionMaxScore) continue;
        tallies
            .putIfAbsent((phoneme.expected, heard), _Tally.new)
            .add(phoneme.score, word.text);
      }
    }
  }
  final confusions = <Confusion>[
    for (final entry in tallies.entries)
      if (entry.value.count >= minCount)
        Confusion(
          expected: entry.key.$1,
          heard: entry.key.$2,
          count: entry.value.count,
          avgScore: entry.value.average,
          exampleWords: entry.value.words,
        ),
  ];
  confusions.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.avgScore.compareTo(b.avgScore);
  });
  return confusions;
}

/// Running count, score total and example words for one (expected, heard) pair.
class _Tally {
  int count = 0;
  int _total = 0;
  final List<String> words = <String>[];

  void add(int score, String word) {
    count++;
    _total += score;
    if (words.length < confusionExampleCount && !words.contains(word)) {
      words.add(word);
    }
  }

  double get average => _total / count;
}
