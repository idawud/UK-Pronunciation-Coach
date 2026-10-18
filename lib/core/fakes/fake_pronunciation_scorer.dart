import '../contracts/pronunciation_scorer.dart';
import '../models/models.dart';
import 'sample_data.dart';

/// Canned [PronunciationScorer]. Ignores the posteriors' content.
///
/// [score] returns `cannedRiverAttempt` for the river passage and a uniform result
/// (every word [defaultWordScore]) for other passages. [scoreWord] cycles through
/// [wordScores], so a Fix-a-word retry loop improves on each try.
class FakePronunciationScorer implements PronunciationScorer {
  /// Creates the fake.
  FakePronunciationScorer({
    this.wordScores = const [45, 72, 88],
    this.defaultWordScore = 90,
  });

  /// Scores returned by successive [scoreWord] calls (cycled).
  List<int> wordScores;

  /// Word score for passages other than the river sample.
  int defaultWordScore;

  int _wordCalls = 0;
  int _attempts = 0;

  @override
  AttemptResult score(
    Passage passage,
    PhonemePosteriors posteriors,
    List<Segment> speech, {
    String? attemptId,
    DateTime? at,
    String? audioPath,
  }) {
    final when = at ?? DateTime.now();
    final id =
        attemptId ?? 'fake-${when.microsecondsSinceEpoch}-${_attempts++}';
    final base = passage.id == riverPassage.id
        ? cannedRiverAttempt
        : buildAttempt(
            passage,
            id: id,
            at: when,
            defaultScore: (_) => defaultWordScore,
            fluency: defaultWordScore,
          );
    return base.copyWith(
      id: id,
      passageId: passage.id,
      at: when,
      audioPath: audioPath,
      tier: posteriors.tier,
    );
  }

  @override
  WordResult scoreWord(WordSpec word, PhonemePosteriors posteriors) {
    if (!word.scorable) {
      return WordResult(
        index: word.index,
        text: word.text,
        score: 0,
        status: WordStatus.notScored,
      );
    }
    final s = wordScores[_wordCalls++ % wordScores.length];
    final good = s >= WordStatus.defaultGood;
    return WordResult(
      index: word.index,
      text: word.text,
      score: s,
      status: WordStatus.fromScore(s),
      phonemes: [
        for (var i = 0; i < word.phonemes.length; i++)
          PhonemeResult(
            expected: word.phonemes[i].ipa,
            heard: good || i != 0 ? null : 't',
            score: good || i != 0 ? s : (s * 0.6).round(),
            start: Duration(milliseconds: 200 + i * 80),
            end: Duration(milliseconds: 280 + i * 80),
          ),
      ],
    );
  }
}
