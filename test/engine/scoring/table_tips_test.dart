import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/scoring/data/tips_table.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

void main() {
  const tips = TableTips();

  test('has at least 25 entries, none empty', () {
    expect(TableTips.entryCount, greaterThanOrEqualTo(25));
    for (final m in substitutionTips.values) {
      for (final t in m.values) {
        expect(t.trim(), isNotEmpty);
      }
    }
    for (final t in [...droppedTips.values, ...generalTips.values]) {
      expect(t.trim(), isNotEmpty);
    }
  });

  test('the examples from the build prompt', () {
    expect(tips.tipFor('θ', 't'), contains('tongue between your teeth'));
    expect(tips.tipFor('ɑː', 'æ'), "Drop your jaw for a long 'ah', as in car.");
    expect(tips.tipFor('ɑː', 'ɑːɹ'), rhoticTip);
  });

  test('nothing to fix gives null', () {
    expect(tips.tipFor('θ', null), isNull);
    expect(tips.tipFor('θ', 'θ'), isNull);
    expect(tips.tipFor('ˈɑː', 'ɑ:'), isNull);
    expect(tips.tipFor('ɛ', 'e'), isNull);
    expect(tips.tipFor('', 'x'), isNull);
  });

  test('r after a vowel, in any spelling', () {
    expect(tips.tipFor('ɔː', 'ɔːɹ'), rhoticTip);
    expect(tips.tipFor('ə', 'ɚ'), rhoticTip);
    expect(tips.tipFor('ɜː', 'ɜːr'), rhoticTip);
    expect(tips.tipFor('ɪə', 'ɪɹ'), rhoticTip);
    // Not a vowel: no r advice.
    expect(tips.tipFor('t', 'tɹ'), isNull);
    // A different vowel plus r is not just an added r.
    expect(tips.tipFor('ɪ', 'ɑːɹ'), rhoticTip);
    expect(tips.tipFor('ɪ', 'æɹ'), isNull);
  });

  test('dropped sounds', () {
    expect(tips.tipFor('h', ''), contains('h'));
    expect(tips.tipFor('ʒ', ''), contains('/ʒ/'));
  });

  test('canonical spellings are folded and general advice is the fallback', () {
    expect(tips.tipFor('e', 'æ'), tips.tipFor('ɛ', 'æ'));
    expect(tips.tipFor('r', 'l'), tips.tipFor('ɹ', 'l'));
    expect(tips.tipFor('θ', 'k'), generalTips['θ']);
    expect(tips.tipFor('m', 'k'), isNull);
  });
}
