import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/segment.dart';
import 'package:uk_pronunciation_coach/ui/coach/record/pace_stats.dart';
import 'package:uk_pronunciation_coach/ui/coach/record/rhythm.dart';

Segment seg(int startMs, int endMs) => Segment(
  start: Duration(milliseconds: startMs),
  end: Duration(milliseconds: endMs),
);

/// Every region stretched by [factor] from the first start.
List<Segment> stretch(List<Segment> s, double factor) {
  final origin = s.first.start.inMicroseconds;
  return [
    for (final r in s)
      Segment(
        start: Duration(
          microseconds:
              origin + ((r.start.inMicroseconds - origin) * factor).round(),
        ),
        end: Duration(
          microseconds:
              origin + ((r.end.inMicroseconds - origin) * factor).round(),
        ),
      ),
  ];
}

void main() {
  final reading = [seg(0, 1000), seg(1500, 2500), seg(3000, 3800)];

  group('rhythmScore', () {
    test('identical readings score 100', () {
      expect(rhythmScore(reading, reading), 100);
    });

    test('a reading twice as slow scores lower than 100', () {
      final slow = stretch(reading, 2);
      final score = rhythmScore(slow, reading);
      expect(score, lessThan(100));
      expect(score, greaterThan(0));
    });

    test('a reading with its pause in the wrong place scores lower', () {
      final shifted = [seg(0, 2000), seg(2500, 3000), seg(3300, 3800)];
      expect(rhythmScore(shifted, reading), lessThan(100));
    });

    test('empty input scores 0 and never throws', () {
      expect(rhythmScore(const [], reading), 0);
      expect(rhythmScore(reading, const []), 0);
      expect(rhythmScore(const [], const []), 0);
    });

    test('zero-length regions score 0', () {
      expect(rhythmScore([seg(500, 500)], reading), 0);
    });
  });

  group('estimateReference', () {
    test('empty text gives no regions', () {
      expect(estimateReference(''), isEmpty);
    });

    test('a comma makes a short pause between two regions', () {
      final regions = estimateReference('Hello, world');
      expect(regions, hasLength(2));
      // "Hello" is two syllables (0.5 s), then a 0.25 s comma pause.
      expect(regions[0].start, Duration.zero);
      expect(regions[0].end, const Duration(milliseconds: 500));
      expect(
        regions[1].start - regions[0].end,
        const Duration(milliseconds: 250),
      );
      // "world" is one syllable (0.25 s).
      expect(regions[1].duration, const Duration(milliseconds: 250));
    });

    test('a full stop gives a pause over 0.4 s', () {
      final stats = paceFromRegions(
        estimateReference('Hello. World.'),
        'Hello. World.',
      );
      expect(stats.pauseCount, 1);
    });

    test('slow speech takes longer than normal speech', () {
      Duration total(List<Segment> s) =>
          s.fold(Duration.zero, (sum, r) => sum + r.duration);
      final normal = total(estimateReference('Please pass the butter'));
      final slow = total(
        estimateReference('Please pass the butter', rate: 0.6),
      );
      expect(slow, greaterThan(normal));
    });
  });
}
