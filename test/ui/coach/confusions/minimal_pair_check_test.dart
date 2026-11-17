import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/minimal_pair_check.dart';

import 'confusion_fixtures.dart';

void main() {
  final clip = AudioClip(
    path: '/fake/check.wav',
    duration: const Duration(seconds: 1),
  );

  group('verdictFor', () {
    test('a gap of 8 or more picks the clearer word', () {
      expect(verdictFor(80, 72).winner, PairWinner.a);
      expect(verdictFor(60, 70).winner, PairWinner.b);
    });

    test('a gap under 8 in either direction is ambiguous', () {
      expect(verdictFor(80, 73).winner, PairWinner.ambiguous);
      expect(verdictFor(73, 80).winner, PairWinner.ambiguous);
      expect(verdictFor(50, 50).winner, PairWinner.ambiguous);
    });

    test('keeps both scores and the gap', () {
      final v = verdictFor(30, 85);
      expect(v.scoreA, 30);
      expect(v.scoreB, 85);
      expect(v.gap, -55);
      expect(v.winner, PairWinner.b);
    });
  });

  group('checkPair', () {
    late FakePhonemeRecognizer recognizer;

    setUp(() async {
      recognizer = FakePhonemeRecognizer();
      await recognizer.load(ModelTier.light);
    });

    test('recognises once and scores each word of the pair', () async {
      final scorer = FakePronunciationScorer(wordScores: [85, 30]);
      final verdict = await checkPair(
        clip,
        catCut,
        recognizer: recognizer,
        scorer: scorer,
      );
      expect(recognizer.recogniseCount, 1);
      expect(verdict.scoreA, 85);
      expect(verdict.scoreB, 30);
      expect(verdict.winner, PairWinner.a);
    });

    test('the second word can win', () async {
      final scorer = FakePronunciationScorer(wordScores: [40, 90]);
      final verdict = await checkPair(
        clip,
        catCut,
        recognizer: recognizer,
        scorer: scorer,
      );
      expect(verdict.winner, PairWinner.b);
    });

    test('close scores are ambiguous', () async {
      final scorer = FakePronunciationScorer(wordScores: [55, 50]);
      final verdict = await checkPair(
        clip,
        catCut,
        recognizer: recognizer,
        scorer: scorer,
      );
      expect(verdict.winner, PairWinner.ambiguous);
    });

    test(
      'a pair without phonemes is ambiguous and is not recognised',
      () async {
        const bare = MinimalPair(contrast: 'æ-ʌ', wordA: 'cat', wordB: 'cut');
        final verdict = await checkPair(
          clip,
          bare,
          recognizer: recognizer,
          scorer: FakePronunciationScorer(),
        );
        expect(verdict.winner, PairWinner.ambiguous);
        expect(recognizer.recogniseCount, 0);
      },
    );
  });
}
