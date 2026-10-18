import 'dart:math' as math;

import 'config/scoring_config.dart';

/// A pause between two spoken words.
class Pause {
  /// Creates a pause after word [afterWord] lasting [ms].
  const Pause({
    required this.afterWord,
    required this.ms,
    required this.atPunctuation,
    required this.penalty,
  });

  /// Index of the word before the pause.
  final int afterWord;

  /// Pause length in milliseconds.
  final int ms;

  /// True when the text has punctuation between the two words.
  final bool atPunctuation;

  /// Fluency points lost to this pause (0 for a free pause).
  final double penalty;
}

/// Fluency components (all 0-100 except counts and [wordsPerMinute]).
class FluencyBreakdown {
  /// Creates a breakdown.
  const FluencyBreakdown({
    required this.score,
    required this.wordsPerMinute,
    required this.rateScore,
    required this.pauses,
    required this.pauseScore,
    required this.missedWords,
    required this.extraWords,
    required this.repeatedWords,
    required this.continuityScore,
  });

  /// Fluency 0-100.
  final int score;

  /// Speaking rate over the spoken span, or null when too few words to judge.
  final double? wordsPerMinute;

  /// Rate score.
  final double rateScore;

  /// Pauses between words (free ones included with penalty 0).
  final List<Pause> pauses;

  /// Pause score.
  final double pauseScore;

  /// Expected words not said.
  final int missedWords;

  /// Inserted words.
  final int extraWords;

  /// Repeated words.
  final int repeatedWords;

  /// Continuity score from missed, extra and repeated words.
  final double continuityScore;
}

/// Time span of a spoken word in milliseconds from the clip start.
typedef WordSpan = ({int word, int startMs, int endMs});

/// Computes fluency from speaking rate, pauses and missed / extra / repeated words.
///
/// - [spoken]: spans of words that were said, in passage order.
/// - [spokenWordCount]: words said, including unscored words (no span).
/// - [totalWords]: words in the passage.
/// - [silencesMs]: silences between VAD speech segments as `(start, end)` ms.
/// - [punctuationAfter]: true when the passage text has punctuation after word i.
FluencyBreakdown computeFluency({
  required ScoringConfig config,
  required List<WordSpan> spoken,
  required int spokenWordCount,
  required int totalWords,
  required int missedWords,
  required int extraWords,
  required int repeatedWords,
  required List<(int, int)> silencesMs,
  required bool Function(int word) punctuationAfter,
}) {
  final cont = math.max(
    0.0,
    100 -
        config.continuityPenaltyScale *
            (missedWords + extraWords + repeatedWords) /
            math.max(1, totalWords),
  );
  if (spoken.isEmpty) {
    return FluencyBreakdown(
      score: 0,
      wordsPerMinute: null,
      rateScore: 0,
      pauses: const [],
      pauseScore: 0,
      missedWords: missedWords,
      extraWords: extraWords,
      repeatedWords: repeatedWords,
      continuityScore: cont,
    );
  }

  double? wpm;
  var rate = 100.0;
  final spanMs = spoken.last.endMs - spoken.first.startMs;
  if (spokenWordCount >= config.minWordsForRate && spanMs > 0) {
    wpm = spokenWordCount / (spanMs / 60000);
    rate = config.rateScore(wpm);
  }

  final pauses = <Pause>[];
  for (var i = 1; i < spoken.length; i++) {
    final a = spoken[i - 1];
    final b = spoken[i];
    final gap = b.startMs - a.endMs;
    if (gap <= 0) continue;
    var vadSilence = 0;
    for (final (s, e) in silencesMs) {
      final int overlap = math.min(e, b.startMs) - math.max(s, a.endMs);
      if (overlap > vadSilence) vadSilence = overlap;
    }
    final isPause =
        gap >= config.pauseMinMs || vadSilence >= config.vadPauseMinMs;
    if (!isPause) continue;
    var punct = false;
    for (var w = a.word; w < b.word; w++) {
      if (punctuationAfter(w)) punct = true;
    }
    final excess = punct ? gap - config.freePauseAtPunctuationMs : gap;
    final penalty = excess <= 0
        ? 0.0
        : config.pausePenalty +
              config.pausePenaltyPerSecond * math.max(0, excess / 1000 - 0.5);
    pauses.add(
      Pause(afterWord: a.word, ms: gap, atPunctuation: punct, penalty: penalty),
    );
  }
  final pauseScore = math.max(
    0.0,
    100 - pauses.fold<double>(0, (s, p) => s + p.penalty),
  );

  final wsum = config.rateWeight + config.pauseWeight + config.continuityWeight;
  final score = wsum <= 0
      ? 0
      : ((config.rateWeight * rate +
                    config.pauseWeight * pauseScore +
                    config.continuityWeight * cont) /
                wsum)
            .round()
            .clamp(0, 100)
            .toInt();
  return FluencyBreakdown(
    score: score,
    wordsPerMinute: wpm,
    rateScore: rate,
    pauses: pauses,
    pauseScore: pauseScore,
    missedWords: missedWords,
    extraWords: extraWords,
    repeatedWords: repeatedWords,
    continuityScore: cont,
  );
}
