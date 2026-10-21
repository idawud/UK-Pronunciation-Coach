import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

/// Shared behaviour every [PronunciationScorer] must have, using the sample passages
/// and synthetic posteriors from lib/core/fakes/sample_data.dart.
///
/// [checkSemantics] also checks that scores react to the audio (perfect read scores
/// high, substituted phonemes and missed words are caught). Real scorers must pass it;
/// the canned fake runs with it off.
void runPronunciationScorerContract(
  PronunciationScorer Function() create, {
  bool checkSemantics = true,
}) {
  group('PronunciationScorer contract', () {
    late PronunciationScorer scorer;
    setUp(() => scorer = create());

    const order = {
      WordStatus.missed: 0,
      WordStatus.fix: 0,
      WordStatus.close: 1,
      WordStatus.good: 2,
    };

    void checkWellFormed(AttemptResult r, Passage p, PhonemePosteriors post) {
      expect(r.passageId, p.id);
      expect(r.words.length, p.words.length);
      for (final s in [r.overall, r.accuracy, r.fluency]) {
        expect(s, inInclusiveRange(0, 100));
      }
      expect(
        (r.overall - (0.7 * r.accuracy + 0.3 * r.fluency)).abs(),
        lessThanOrEqualTo(1),
      );
      expect(r.tier, post.tier);
      for (var i = 0; i < r.words.length; i++) {
        final w = r.words[i];
        final spec = p.words[i];
        expect(w.index, i);
        expect(w.text, spec.text);
        expect(w.score, inInclusiveRange(0, 100));
        if (!spec.scorable) {
          expect(w.status, WordStatus.notScored);
          continue;
        }
        expect(w.status, isNot(WordStatus.notScored));
        if (w.status == WordStatus.missed) {
          expect(w.score, 0);
          continue;
        }
        // Scored against the main pronunciation or one of the alternatives.
        final heardAs = [spec.phonemes, ...spec.alternatives].firstWhere(
          (form) =>
              form.length == w.phonemes.length &&
              [
                for (var j = 0; j < form.length; j++)
                  form[j].ipa == w.phonemes[j].expected,
              ].every((ok) => ok),
          orElse: () => fail('${w.text}: phonemes match no pronunciation'),
        );
        expect(w.phonemes.length, heardAs.length);
        for (var j = 0; j < w.phonemes.length; j++) {
          final ph = w.phonemes[j];
          expect(ph.expected, heardAs[j].ipa);
          expect(ph.score, inInclusiveRange(0, 100));
          expect(ph.start, lessThanOrEqualTo(ph.end));
          expect(ph.start, greaterThanOrEqualTo(Duration.zero));
          expect(ph.end, lessThanOrEqualTo(post.duration));
        }
      }
      final ranked = r.words.where((w) => order.containsKey(w.status));
      for (final a in ranked) {
        for (final b in ranked) {
          if (a.score > b.score) {
            expect(
              order[a.status]!,
              greaterThanOrEqualTo(order[b.status]!),
              reason: '${a.text} (${a.score}) vs ${b.text} (${b.score})',
            );
          }
        }
      }
    }

    for (final passage in samplePassages) {
      test('well-formed result for ${passage.id}', () {
        final post = syntheticPosteriors(passage);
        final at = DateTime(2026, 10, 18, 9);
        final r = scorer.score(
          passage,
          post,
          syntheticSpeech(post),
          attemptId: 'a1',
          at: at,
          audioPath: '/tmp/a1.wav',
        );
        expect(r.id, 'a1');
        expect(r.at, at);
        expect(r.audioPath, '/tmp/a1.wav');
        checkWellFormed(r, passage, post);
      });
    }

    test('tier is copied from the posteriors', () {
      final post = syntheticPosteriors(teaPassage, tier: ModelTier.light);
      final r = scorer.score(teaPassage, post, syntheticSpeech(post));
      expect(r.tier, ModelTier.light);
      expect(r.id, isNotEmpty);
    });

    test('unscorable words are notScored', () {
      final p = teaPassage.copyWith(
        words: [
          for (final w in teaPassage.words)
            w.index == 2 ? w.copyWith(scorable: false, phonemes: []) : w,
        ],
      );
      final post = syntheticPosteriors(p);
      final r = scorer.score(p, post, syntheticSpeech(post));
      expect(r.words[2].status, WordStatus.notScored);
      checkWellFormed(r, p, post);
    });

    test('scoreWord keeps index and text', () {
      final word = riverPassage.words[1];
      final single = riverPassage.slice(1, 2);
      final w = scorer.scoreWord(word, syntheticPosteriors(single));
      expect(w.index, word.index);
      expect(w.text, word.text);
      expect(w.score, inInclusiveRange(0, 100));
      expect(w.status, isNot(WordStatus.notScored));
      final unscorable = word.copyWith(scorable: false, phonemes: []);
      expect(
        scorer.scoreWord(unscorable, syntheticPosteriors(single)).status,
        WordStatus.notScored,
      );
    });

    if (checkSemantics) {
      test('a perfect read scores high', () {
        for (final passage in samplePassages) {
          final post = syntheticPosteriors(passage);
          final r = scorer.score(passage, post, syntheticSpeech(post));
          expect(r.accuracy, greaterThanOrEqualTo(80), reason: passage.id);
          expect(r.redWords, isEmpty, reason: passage.id);
        }
      });

      test('substituted phonemes are caught and reported as heard', () {
        final perfect = syntheticPosteriors(riverPassage);
        final good = scorer.score(
          riverPassage,
          perfect,
          syntheticSpeech(perfect),
        );
        final r = scorer.score(
          riverPassage,
          riverPosteriors,
          syntheticSpeech(riverPosteriors),
        );
        for (final i in riverSubstitutions.keys) {
          expect(
            r.words[i].score,
            lessThan(good.words[i].score),
            reason: r.words[i].text,
          );
        }
        expect(r.words[1].phonemes.first.heard, 't');
      });

      test('a missed word is marked missed', () {
        final post = syntheticPosteriors(riverPassage, missedWords: {6});
        final r = scorer.score(riverPassage, post, syntheticSpeech(post));
        expect(r.words[6].status, WordStatus.missed);
        expect(r.words[6].score, 0);
      });

      group('alternative pronunciations', () {
        // "a" in the tea passage: main /ə/, read as the strong form /eɪ/.
        const strong = [PhonemeSpec(ipa: 'eɪ', stress: 1)];
        Passage withWord(List<PhonemeSpec> phonemes, {bool alt = false}) =>
            teaPassage.copyWith(
              words: [
                for (final w in teaPassage.words)
                  w.index == 2
                      ? w.copyWith(
                          phonemes: phonemes,
                          alternatives: alt ? [strong] : const [],
                        )
                      : w,
              ],
            );
        final spoken = syntheticPosteriors(withWord(strong));
        final speech = syntheticSpeech(spoken);
        final mainOnly = withWord(teaPassage.words[2].phonemes);
        final withAlt = withWord(teaPassage.words[2].phonemes, alt: true);

        test('a word read as an accepted alternative scores as good', () {
          final r = scorer.score(withAlt, spoken, speech);
          checkWellFormed(r, withAlt, spoken);
          expect(r.words[2].status, WordStatus.good);
          expect(r.words[2].phonemes.single.expected, 'eɪ');
          final without = scorer.score(mainOnly, spoken, speech);
          expect(r.words[2].score, greaterThan(without.words[2].score));
          expect(r.accuracy, greaterThanOrEqualTo(without.accuracy));
        });

        test('the main pronunciation still wins when it was said', () {
          final post = syntheticPosteriors(mainOnly);
          final r = scorer.score(withAlt, post, syntheticSpeech(post));
          expect(r.words[2].status, WordStatus.good);
          expect(r.words[2].phonemes.single.expected, 'ə');
        });

        test('scoreWord tries the alternatives too', () {
          final word = withAlt.words[2];
          final single = syntheticPosteriors(withWord(strong).slice(2, 3));
          final w = scorer.scoreWord(word, single);
          expect(w.status, WordStatus.good);
          expect(w.index, 2);
          expect(
            scorer
                .scoreWord(word.copyWith(alternatives: const []), single)
                .score,
            lessThan(w.score),
          );
        });
      });

      test('scoreWord: perfect is good, substituted is worse', () {
        final word = riverPassage.words[1];
        final single = riverPassage.slice(1, 2);
        final good = scorer.scoreWord(word, syntheticPosteriors(single));
        final bad = scorer.scoreWord(
          word,
          syntheticPosteriors(
            single,
            substitutions: {
              0: {0: 't'},
            },
          ),
        );
        expect(good.status, WordStatus.good);
        expect(bad.score, lessThan(good.score));
      });
    }
  });
}
