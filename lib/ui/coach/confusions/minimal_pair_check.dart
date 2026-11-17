import '../../../core/contracts/contracts.dart';
import '../../../core/models/models.dart';

/// Scores closer than this many points are reported as ambiguous.
const int pairAmbiguousGap = 8;

/// Which word of a minimal pair the recording fits better.
enum PairWinner {
  /// The clip fits `MinimalPair.wordA` clearly better.
  a,

  /// The clip fits `MinimalPair.wordB` clearly better.
  b,

  /// The two scores are within [pairAmbiguousGap] of each other.
  ambiguous,
}

/// The estimate for one recording of a minimal pair: the score against each word and
/// the winner. This is an estimate from the on-device model, not a judged score.
class PairVerdict {
  /// Creates a verdict.
  const PairVerdict({
    required this.scoreA,
    required this.scoreB,
    required this.winner,
  });

  /// Word score (0-100) of the clip against `MinimalPair.wordA`.
  final int scoreA;

  /// Word score (0-100) of the clip against `MinimalPair.wordB`.
  final int scoreB;

  /// The word the clip fits, or [PairWinner.ambiguous].
  final PairWinner winner;

  /// `scoreA - scoreB`.
  int get gap => scoreA - scoreB;
}

/// Turns two word scores into a [PairVerdict]. Ambiguous when the gap is below
/// [pairAmbiguousGap] in either direction.
PairVerdict verdictFor(int scoreA, int scoreB) {
  final gap = scoreA - scoreB;
  final PairWinner winner;
  if (gap.abs() < pairAmbiguousGap) {
    winner = PairWinner.ambiguous;
  } else if (gap > 0) {
    winner = PairWinner.a;
  } else {
    winner = PairWinner.b;
  }
  return PairVerdict(scoreA: scoreA, scoreB: scoreB, winner: winner);
}

/// Scores [clip] against both words of [pair] and returns the estimate.
///
/// The clip is recognised once; the same posteriors are scored against a [WordSpec]
/// built from `pair.phonemesA` and one from `pair.phonemesB`. The caller must have
/// loaded a model on [recognizer]. A pair without phonemes cannot be judged and returns
/// an ambiguous verdict of 0 and 0 without recognising the clip.
Future<PairVerdict> checkPair(
  AudioClip clip,
  MinimalPair pair, {
  required PhonemeRecognizer recognizer,
  required PronunciationScorer scorer,
}) async {
  if (pair.phonemesA.isEmpty || pair.phonemesB.isEmpty) {
    return const PairVerdict(
      scoreA: 0,
      scoreB: 0,
      winner: PairWinner.ambiguous,
    );
  }
  final posteriors = await recognizer.recognise(clip);
  final scoreA = scorer
      .scoreWord(
        WordSpec(text: pair.wordA, index: 0, phonemes: pair.phonemesA),
        posteriors,
      )
      .score;
  final scoreB = scorer
      .scoreWord(
        WordSpec(text: pair.wordB, index: 0, phonemes: pair.phonemesB),
        posteriors,
      )
      .score;
  return verdictFor(scoreA, scoreB);
}
