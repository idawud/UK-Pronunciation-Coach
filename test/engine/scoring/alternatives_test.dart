import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import 'gop_pronunciation_scorer_test.dart' show read;

/// `WordSpec.alternatives`: each word is scored against its best-matching accepted
/// pronunciation (C1 / I2 contract request), on the real 392-symbol model vocab.
void main() {
  const scorer = GopPronunciationScorer();
  final river = riverPassage;

  List<PhonemeSpec> ipa(String s) => [
    for (final t in s.split(' '))
      PhonemeSpec(
        ipa: t.replaceAll('ˈ', ''),
        stress: t.startsWith('ˈ') ? 1 : 0,
      ),
  ];

  /// [p] with word [i]'s phonemes and alternatives replaced.
  Passage withWord(
    Passage p,
    int i,
    String main, [
    List<String> alternatives = const [],
  ]) => p.copyWith(
    words: [
      for (final w in p.words)
        w.index == i
            ? w.copyWith(
                phonemes: ipa(main),
                alternatives: [for (final a in alternatives) ipa(a)],
              )
            : w,
    ],
  );

  group('"Thursday" said with -day /deɪ/ against Britfone /di/', () {
    // The reader says /θɜːzdeɪ/ (river passage as written).
    final said = read(river);
    final mainOnly = withWord(river, 1, 'θ ˈɜː z d i');
    final withAlt = withWord(river, 1, 'θ ˈɜː z d i', ['θ ˈɜː z d eɪ']);

    test('without the alternative the word is marked down', () {
      final a = scorer.analyse(mainOnly, said.post, said.speech);
      expect(a.words[1].status, isNot(WordStatus.good));
    });

    test('with it the word is good and reports the form it matched', () {
      final a = scorer.analyse(withAlt, said.post, said.speech);
      expect(a.words[1].status, WordStatus.good);
      expect(a.words[1].phonemes.last.expected, 'eɪ');
      final without = scorer.analyse(mainOnly, said.post, said.speech);
      expect(a.accuracy, greaterThan(without.accuracy));
      // The other words are untouched.
      for (var i = 0; i < river.words.length; i++) {
        if (i == 1) continue;
        expect(a.words[i].score, without.words[i].score, reason: '$i');
      }
    });

    test('the main form wins a tie and when it was said', () {
      final both = withWord(river, 1, 'θ ˈɜː z d eɪ', ['θ ˈɜː z d eɪ']);
      final a = scorer.analyse(both, said.post, said.speech);
      expect(a.words[1].phonemes.last.expected, 'eɪ');
      final wrongAlt = withWord(river, 1, 'θ ˈɜː z d eɪ', ['θ ˈɜː z d i']);
      final b = scorer.analyse(wrongAlt, said.post, said.speech);
      expect(b.words[1].status, WordStatus.good);
      expect(b.words[1].phonemes.last.expected, 'eɪ');
    });
  });

  test('a weak form the first pass skipped is found by its alternative', () {
    // "and" (word 12) read as a bare /n/; Britfone's main form is /ænd/.
    final spoken = withWord(river, 12, 'n');
    final said = read(spoken);
    final mainOnly = withWord(river, 12, 'ˈæ n d');
    final withAlt = withWord(river, 12, 'ˈæ n d', ['ə n d', 'n']);
    final before = scorer.analyse(mainOnly, said.post, said.speech);
    final after = scorer.analyse(withAlt, said.post, said.speech);
    expect(before.words[12].status, isNot(WordStatus.good));
    expect(after.words[12].status, WordStatus.good);
    expect(after.words[12].phonemes.single.expected, 'n');
  });

  test('a real mistake is still caught when alternatives exist', () {
    // "bath" (word 21) with both alternatives wrong for what was said (/æ f/).
    final said = read(river, subs: riverSubstitutions);
    final withAlt = withWord(river, 21, 'b ˈɑː θ', ['b ˈɑː θ s']);
    final a = scorer.analyse(withAlt, said.post, said.speech);
    expect(a.words[21].status.isRed, isTrue);
  });

  test('alternatives of unscorable, missed-everywhere and empty forms', () {
    final p = river.copyWith(
      words: [
        for (final w in river.words)
          switch (w.index) {
            2 => w.copyWith(alternatives: [const []]),
            4 => w.copyWith(
              scorable: false,
              phonemes: const [],
              alternatives: [ipa('b aɪ')],
            ),
            _ => w,
          },
      ],
    );
    final said = read(river);
    final a = scorer.analyse(p, said.post, said.speech);
    expect(a.words[2].status, WordStatus.good);
    expect(a.words[4].status, WordStatus.notScored);
    // Silence: every window is empty or silent, nothing is chosen.
    final silent = read(p, missed: {for (final w in p.words) w.index});
    final b = scorer.analyse(
      withWord(river, 1, 'θ ˈɜː z d i', ['θ ˈɜː z d eɪ']),
      silent.post,
      silent.speech,
    );
    expect(b.words.every((w) => w.status == WordStatus.missed), isTrue);
  });

  test('scoreWord keeps the best form', () {
    final word = withWord(river, 1, 'θ ˈɜː z d i', ['θ ˈɜː z d eɪ']).words[1];
    final said = read(river.slice(1, 2));
    final w = scorer.scoreWord(word, said.post);
    expect(w.status, WordStatus.good);
    expect(w.index, 1);
    expect(w.phonemes.last.expected, 'eɪ');
    final unscorable = scorer.scoreWord(
      word.copyWith(scorable: false, phonemes: const []),
      said.post,
    );
    expect(unscorable.status, WordStatus.notScored);
  });
}
