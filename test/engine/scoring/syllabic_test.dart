import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import 'support/synth.dart';

/// Syllabic `l̩` / `n̩` forms (I2 contract request 1): the model writes the last
/// syllable of "people" as one `əl` token, which used to leave `ə` or `l` "dropped".
void main() {
  List<PhonemeSpec> ipa(String s) => [
    for (final t in s.split(' '))
      PhonemeSpec(
        ipa: t.replaceAll('ˈ', ''),
        stress: t.startsWith('ˈ') ? 1 : 0,
      ),
  ];

  String plain(List<PhonemeSpec>? f) => f!.map((p) => p.ipa).join(' ');

  group('syllabicForm', () {
    test('rewrites ə l / ə n before a consonant or at the end', () {
      final f = GopPronunciationScorer.syllabicForm;
      expect(plain(f(ipa('p ˈiː p ə l'))), 'p iː p l̩');
      expect(plain(f(ipa('b ˈʌ t ə n z'))), 'b ʌ t n̩ z');
      expect(f(ipa('b ə l ˈuː n')), isNull, reason: 'a vowel follows');
      expect(f(ipa('k ˈæ t')), isNull);
      expect(plain(f(ipa('l ˈɪ t ə l ə n'))), 'l ɪ t ə l n̩');
    });
  });

  group('"people" said with one əl token', () {
    final word = WordSpec(
      text: 'people',
      index: 0,
      offset: 0,
      phonemes: ipa('p ˈiː p ə l'),
    );
    final passage = Passage(
      id: 'p',
      level: 1,
      title: 'people',
      text: 'people',
      words: [word],
    );
    PhonemePosteriors said() {
      final s = Synth()..blank(10);
      for (final sym in ['p', 'iː', 'p']) {
        s
          ..phone(sym, 2)
          ..blank(2);
      }
      s
        ..phone('əl', 1)
        ..blank(12);
      return s.build();
    }

    test('without syllabic forms a sound looks dropped', () {
      const scorer = GopPronunciationScorer(
        config: ScoringConfig(syllabicConsonants: false),
      );
      final r = scorer.analyse(passage, said(), const []).words.single;
      expect(r.phonemes.map((p) => p.heard), contains(''));
    });

    test('with them the word matches p iː p l̩ and nothing is dropped', () {
      const scorer = GopPronunciationScorer();
      final r = scorer.analyse(passage, said(), const []).words.single;
      expect(r.phonemes.map((p) => p.expected), ['p', 'iː', 'p', 'l̩']);
      expect(r.phonemes.map((p) => p.heard), isNot(contains('')));
      expect(r.status, WordStatus.good);
      final single = scorer.scoreWord(word, said());
      expect(single.status, WordStatus.good);
    });

    test('a reader who says ə and l still matches the main form', () {
      final s = Synth()..blank(10);
      for (final sym in ['p', 'iː', 'p', 'ə', 'l']) {
        s
          ..phone(sym, 2)
          ..blank(2);
      }
      s.blank(10);
      final r = const GopPronunciationScorer()
          .analyse(passage, s.build(), const [])
          .words
          .single;
      expect(r.phonemes.map((p) => p.expected), ['p', 'iː', 'p', 'ə', 'l']);
      expect(r.status, WordStatus.good);
    });
  });

  test('phonemeGopOffset shifts a sound before the curve', () {
    const c = ScoringConfig(phonemeGopOffset: {'θ': 2});
    expect(c.phonemeScore(0, 'θ'), c.phonemeScore(-2));
    expect(c.phonemeScore(0, 's'), c.phonemeScore(0));
    expect(c.phonemeScore(0), c.calibration(0).round());
    final back = ScoringConfig.fromJson(c.toJson());
    expect(back.phonemeGopOffset, {'θ': 2.0});
    expect(back.syllabicConsonants, isTrue);
    expect(
      ScoringConfig.fromJson({'syllabicConsonants': false}).syllabicConsonants,
      isFalse,
    );
  });
}
