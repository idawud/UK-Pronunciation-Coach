import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/scoring/data/phoneme_map.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_content.dart';

void main() {
  test('there are 12 vowels, 8 diphthongs and 24 consonants', () {
    expect(ipaSoundsIn(IpaGroup.vowels), hasLength(12));
    expect(ipaSoundsIn(IpaGroup.diphthongs), hasLength(8));
    expect(ipaSoundsIn(IpaGroup.consonants), hasLength(24));
    expect(ipaSoundCount, 44);
  });

  test('all 44 symbols are unique', () {
    final symbols = ipaSounds.map((s) => s.symbol).toList();
    expect(symbols.toSet(), hasLength(44));
    expect(symbols, hasLength(44));
  });

  test('every symbol is in the app phoneme inventory', () {
    final missing = [
      for (final s in ipaSounds)
        if (!ssbePhonemeMap.containsKey(s.symbol)) s.symbol,
    ];
    expect(missing, isEmpty, reason: 'symbols missing from ssbePhonemeMap');
  });

  test('the consonant manner counts match the standard table', () {
    int count(IpaManner m) => ipaSounds.where((s) => s.manner == m).length;
    expect(count(IpaManner.plosive), 6);
    expect(count(IpaManner.fricative), 9);
    expect(count(IpaManner.affricate), 2);
    expect(count(IpaManner.nasal), 3);
    expect(count(IpaManner.approximant), 4);
  });

  test('each sound has exactly three examples with one marked span', () {
    for (final s in ipaSounds) {
      expect(s.examples, hasLength(3), reason: s.symbol);
      for (final e in s.examples) {
        final opens = '{'.allMatches(e.marked).length;
        final closes = '}'.allMatches(e.marked).length;
        expect(opens, 1, reason: '${s.symbol}: ${e.marked}');
        expect(closes, 1, reason: '${s.symbol}: ${e.marked}');
        expect(e.highlightStart, lessThan(e.highlightEnd), reason: e.marked);
        expect(e.word, isNotEmpty, reason: e.marked);
        expect(e.word.substring(e.highlightStart, e.highlightEnd), isNotEmpty);
      }
    }
  });

  test('keywords, tips, pitfalls and contrast words are non-empty', () {
    for (final s in ipaSounds) {
      expect(s.keyword.trim(), isNotEmpty, reason: s.symbol);
      expect(s.mouthTip.trim(), isNotEmpty, reason: s.symbol);
      expect(s.pitfall.trim(), isNotEmpty, reason: s.symbol);
      expect(s.contrast.word.trim(), isNotEmpty, reason: s.symbol);
      expect(s.contrast.otherWord.trim(), isNotEmpty, reason: s.symbol);
    }
  });

  test('a contrast points at a sound in the lessons, or at silence', () {
    final symbols = {for (final s in ipaSounds) s.symbol};
    for (final s in ipaSounds) {
      final other = s.contrast.otherSymbol;
      if (other == null) {
        expect(s.symbol, 'h', reason: 'only /h/ is confused with silence');
      } else {
        expect(symbols, contains(other), reason: '${s.symbol} vs $other');
        expect(other, isNot(s.symbol));
      }
    }
  });

  test('vowels carry a lexical set, consonants a manner and voicing', () {
    for (final s in ipaSounds) {
      if (s.group == IpaGroup.consonants) {
        expect(s.manner, isNotNull, reason: s.symbol);
        expect(s.voiced, isNotNull, reason: s.symbol);
        expect(s.lexicalSet, isNull, reason: s.symbol);
      } else {
        expect(s.lexicalSet, isNotNull, reason: s.symbol);
        expect(s.manner, isNull, reason: s.symbol);
        expect(s.voiced, isNull, reason: s.symbol);
      }
    }
  });

  test('ipaSoundFor finds every sound and returns null for others', () {
    for (final s in ipaSounds) {
      expect(ipaSoundFor(s.symbol), same(s));
    }
    expect(ipaSoundFor('x'), isNull);
  });

  test('the intro explains symbols, slashes, length and stress', () {
    final all = ipaIntroPoints.map((p) => '${p.title} ${p.body}').join(' ');
    expect(ipaIntroPoints, isNotEmpty);
    for (final mark in ['ː', 'ˈ', '/', '[']) {
      expect(all, contains(mark));
    }
  });
}
