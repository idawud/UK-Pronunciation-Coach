import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/leitner.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/lost_word.dart';

void main() {
  final t0 = DateTime(2026, 10, 19, 9, 30);

  LostWord fresh({int box = 1, int lapses = 0}) => LostWord(
    word: 'scaffold',
    addedAt: t0,
    due: t0,
    box: box,
    lapses: lapses,
  );

  group('intervals', () {
    test('box 1 is due the same day, then 1, 2, 4, 8 days', () {
      expect(
        [for (var b = 1; b <= 5; b++) leitnerIntervalFor(b)],
        [0, 1, 2, 4, 8],
      );
    });

    test('out-of-range boxes are clamped to 1-5', () {
      expect(leitnerIntervalFor(0), 0);
      expect(leitnerIntervalFor(9), 8);
    });
  });

  group('review: recalled', () {
    test('grows one box per recall with the interval of the new box', () {
      var w = fresh();
      const expected = [(2, 1), (3, 2), (4, 4), (5, 8)];
      for (final (box, days) in expected) {
        w = review(w, true, t0);
        expect(w.box, box);
        expect(w.due, t0.add(Duration(days: days)));
        expect(w.lapses, 0);
      }
    });

    test('caps at box 5 and keeps the 8-day interval', () {
      final again = review(fresh(box: 5), true, t0);
      expect(again.box, 5);
      expect(again.due, t0.add(const Duration(days: 8)));
    });

    test('a recall never changes lapses', () {
      final w = review(fresh(box: 3, lapses: 2), true, t0);
      expect(w.lapses, 2);
    });
  });

  group('review: missed', () {
    test('drops to box 1, adds a lapse and is due now', () {
      final w = review(fresh(box: 5), false, t0);
      expect(w.box, 1);
      expect(w.lapses, 1);
      expect(w.due, t0);
    });

    test('each miss adds one lapse', () {
      final w = review(review(fresh(box: 4), false, t0), false, t0);
      expect(w.lapses, 2);
      expect(w.box, 1);
    });
  });

  group('due', () {
    test(
      'due exactly at now counts as due; one millisecond earlier does not',
      () {
        final w = fresh();
        expect(isDue(w, t0), isTrue);
        expect(isDue(w, t0.subtract(const Duration(milliseconds: 1))), isFalse);
      },
    );
  });

  group('midnight boundary (fixed clock)', () {
    test('a box-2 word reviewed at 23:50 is due at 23:50 the next day', () {
      final late = DateTime(2026, 10, 19, 23, 50);
      final w = review(fresh(), true, late);
      expect(w.due, DateTime(2026, 10, 20, 23, 50));
      expect(isDue(w, DateTime(2026, 10, 20, 23, 49, 59, 999)), isFalse);
      expect(isDue(w, DateTime(2026, 10, 20, 23, 50)), isTrue);
    });

    test('a miss at 23:59:59 is due at once, not after midnight', () {
      final last = DateTime(2026, 10, 19, 23, 59, 59);
      final w = review(fresh(box: 3), false, last);
      expect(w.due, last);
      expect(isDue(w, last), isTrue);
    });
  });
}
