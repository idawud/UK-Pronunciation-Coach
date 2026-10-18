import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/engine/scoring/data/phoneme_map.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import 'support/espeak_vocab.dart';

/// Britfone's SSBE inventory.
const britfone = [
  'ɑː', 'æ', 'ʌ', 'ɒ', 'ɔː', 'ə', 'ɜː', 'ɪ', 'iː', 'ʊ', 'uː', 'ɛ', //
  'aɪ', 'aʊ', 'eɪ', 'əʊ', 'ɔɪ', 'ɪə', 'eə', 'ʊə', //
  'b', 'd', 'f', 'ɡ', 'h', 'j', 'k', 'l', 'm', 'n', 'ŋ', 'p', 'ɹ', 's', //
  'ʃ', 't', 'tʃ', 'θ', 'ð', 'v', 'w', 'z', 'ʒ', 'dʒ',
];

void main() {
  final real = ModelVocab(espeakVocab, 0);
  List<String> syms(PhonemeMapper m, String ipa) => [
    for (final u in m.unitsFor(ipa))
      u.ids.map((i) => m.vocab.symbols[i]).join('|'),
  ];

  group('normalizeIpa', () {
    test('strips stress and tie bars, writes length as ː', () {
      expect(normalizeIpa('ˈɑ:'), 'ɑː');
      expect(normalizeIpa('ˌt͡ʃ'), 'tʃ');
      expect(normalizeIpa(' ə '), 'ə');
    });
  });

  group('ModelVocab', () {
    test('blank and <...> symbols are not phones', () {
      expect(real.isPhone[0], isFalse);
      for (final s in ['<s>', '</s>', '<unk>']) {
        expect(real.isPhone[real.index[s]!], isFalse, reason: s);
      }
      expect(real.isPhone[real.index['θ']!], isTrue);
      expect(real.length, 392);
    });

    test('rejects a bad blank index', () {
      expect(() => ModelVocab(const ['a'], 3), throwsRangeError);
    });
  });

  group('PhonemeMapper on the real model vocab', () {
    final m = PhonemeMapper(real);

    test('every Britfone phoneme is one unit', () {
      for (final p in britfone) {
        expect(m.unitsFor(p), hasLength(1), reason: p);
      }
    });

    test('every table key resolves', () {
      for (final key in ssbePhonemeMap.keys) {
        expect(m.unitsFor(key), isNotEmpty, reason: key);
      }
    });

    test('every phoneme of the sample passages resolves', () {
      for (final p in samplePassages) {
        for (final w in p.words) {
          for (final ph in w.phonemes) {
            expect(m.unitsFor(ph.ipa), hasLength(1), reason: ph.ipa);
          }
        }
      }
    });

    test('accepts British variants, best symbol first', () {
      expect(syms(m, 'əʊ'), ['əʊ|oʊ']);
      expect(syms(m, 'ə'), ['ə|ɐ|ᵻ|əl']);
      expect(syms(m, 'ɪə'), ['iə']);
      expect(syms(m, 'eə'), ['eə|ɛː']);
      expect(syms(m, 'ɹ'), ['ɹ|r']);
      expect(syms(m, 'g'), ['ɡ']);
      expect(syms(m, 'ˈɑ:'), ['ɑː|ɑ|aː']);
    });

    test('r-coloured vowels are not accepted for British vowels', () {
      for (final v in ssbeVowels) {
        for (final u in m.unitsFor(v)) {
          for (final id in u.ids) {
            expect(rhoticSymbols, isNot(contains(real.symbols[id])), reason: v);
          }
        }
      }
    });

    test('caches results', () {
      expect(identical(m.unitsFor('θ'), m.unitsFor('θ')), isTrue);
    });
  });

  group('PhonemeMapper fallbacks', () {
    test('splits diphthongs when the vocab has no diphthong symbol', () {
      final m = PhonemeMapper(ModelVocab(const ['<pad>', 'e', 'ɪ', 'a'], 0));
      expect(syms(m, 'eɪ'), ['e', 'ɪ']);
    });

    test('drops the length mark when only the short vowel exists', () {
      final m = PhonemeMapper(ModelVocab(const ['<pad>', 'ɜ', 'o'], 0));
      expect(syms(m, 'ɜː'), ['ɜ']);
      expect(syms(m, 'oː'), ['o']);
    });

    test('falls back to the characters it knows, or nothing', () {
      final m = PhonemeMapper(ModelVocab(const ['<pad>', 'q', 'χ'], 0));
      expect(syms(m, 'qχ'), ['q', 'χ']);
      expect(m.unitsFor('ʘ'), isEmpty);
    });

    test('extraAccepted widens a phoneme', () {
      final m = PhonemeMapper(
        real,
        extraAccepted: const {
          'ɒ': ['ɑ'],
        },
      );
      expect(syms(m, 'ɒ'), ['ɒ|ɔ|ɑ']);
    });

    test('works with the sample vocab', () {
      final m = PhonemeMapper(ModelVocab(sampleVocab, 0));
      expect(syms(m, 'ɪə'), ['ɪə']);
      expect(syms(m, 'əʊ'), ['əʊ|oʊ']);
    });
  });

  test('PhonemeUnit.sameAs compares ids in order', () {
    expect(const PhonemeUnit([1, 2]).sameAs(const PhonemeUnit([1, 2])), isTrue);
    expect(
      const PhonemeUnit([1, 2]).sameAs(const PhonemeUnit([2, 1])),
      isFalse,
    );
    expect(const PhonemeUnit([1]).sameAs(const PhonemeUnit([1, 2])), isFalse);
  });
}
