import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/confusion_logic.dart';

import 'confusion_fixtures.dart';

void main() {
  final day = DateTime(2026, 10, 18, 9);

  group('buildConfusions', () {
    test('ʌ heard as æ three times is the top confusion', () {
      final attempts = [
        attempt('a', day, [
          word(0, 'cut', [phoneme('ʌ', heard: 'æ', score: 40)]),
        ]),
        attempt('b', day, [
          word(0, 'uncle', [phoneme('ʌ', heard: 'æ', score: 30)]),
        ]),
        attempt('c', day, [
          word(0, 'cut', [phoneme('ʌ', heard: 'æ', score: 50)]),
          word(1, 'bus', [phoneme('ʌ', heard: 'ɒ', score: 20)]),
        ]),
        // A single ɒ confusion: below the default minCount of 2.
      ];
      final result = buildConfusions(attempts);
      expect(result, hasLength(1));
      final top = result.single;
      expect(top.expected, 'ʌ');
      expect(top.heard, 'æ');
      expect(top.contrast, 'ʌ-æ');
      expect(top.count, 3);
      expect(top.avgScore, closeTo(40, 1e-9));
      expect(top.exampleWords, ['cut', 'uncle']);
    });

    test('ignores heard == expected, null heard and scores of 60 or more', () {
      final attempts = [
        attempt('a', day, [
          word(0, 'cut', [
            phoneme('ʌ', heard: 'ʌ', score: 30),
            phoneme('ʌ', score: 30),
            phoneme('ʌ', heard: 'æ', score: 60),
            phoneme('ʌ', heard: 'æ', score: 85),
          ]),
        ]),
        attempt('b', day, [
          word(0, 'cut', [phoneme('ʌ', heard: 'æ', score: 59)]),
          word(1, 'cut', [phoneme('ʌ', heard: 'æ', score: 41)]),
        ]),
      ];
      final result = buildConfusions(attempts);
      expect(result, hasLength(1));
      expect(result.single.count, 2);
      expect(result.single.avgScore, closeTo(50, 1e-9));
    });

    test('minCount drops rarer confusions', () {
      final attempts = [
        attempt('a', day, [
          word(0, 'cut', [phoneme('ʌ', heard: 'æ', score: 40)]),
        ]),
      ];
      expect(buildConfusions(attempts), isEmpty);
      expect(buildConfusions(attempts, minCount: 1), hasLength(1));
    });

    test('attempts before since are not counted', () {
      final attempts = [
        attempt('old', DateTime(2026, 8, 1), [
          word(0, 'cut', [phoneme('ʌ', heard: 'æ', score: 40)]),
          word(1, 'cut', [phoneme('ʌ', heard: 'æ', score: 40)]),
          word(2, 'cut', [phoneme('ʌ', heard: 'æ', score: 40)]),
        ]),
        attempt('new', day, [
          word(0, 'cut', [phoneme('ʌ', heard: 'æ', score: 40)]),
        ]),
      ];
      expect(buildConfusions(attempts, since: DateTime(2026, 9, 1)), isEmpty);
      expect(
        buildConfusions(
          attempts,
          minCount: 1,
          since: DateTime(2026, 9, 1),
        ).single.count,
        1,
      );
    });

    test('sorts by count, then by lower average score', () {
      final attempts = [
        attempt('a', day, [
          word(0, 'bit', [phoneme('ɪ', heard: 'iː', score: 50)]),
          word(1, 'bit', [phoneme('ɪ', heard: 'iː', score: 50)]),
          word(2, 'cut', [phoneme('ʌ', heard: 'æ', score: 20)]),
          word(3, 'cut', [phoneme('ʌ', heard: 'æ', score: 20)]),
        ]),
        attempt('b', day, [
          word(0, 'sheep', [phoneme('θ', heard: 'f', score: 10)]),
          word(1, 'sheep', [phoneme('θ', heard: 'f', score: 10)]),
        ]),
      ];
      final result = buildConfusions(attempts);
      expect(
        [for (final c in result) c.contrast],
        // Ties on count (2 each): lower average first, so ʌ-æ (20) before ɪ-iː (50).
        ['θ-f', 'ʌ-æ', 'ɪ-iː'],
      );
    });

    test('keeps at most three example words, distinct', () {
      final attempts = [
        attempt('a', day, [
          for (final w in ['cut', 'cut', 'bus', 'run', 'fun', 'sun'])
            word(0, w, [phoneme('ʌ', heard: 'æ', score: 40)]),
        ]),
      ];
      final top = buildConfusions(attempts).single;
      expect(top.exampleWords, ['cut', 'bus', 'run']);
    });

    test('empty input gives no confusions', () {
      expect(buildConfusions(const []), isEmpty);
    });
  });
}
