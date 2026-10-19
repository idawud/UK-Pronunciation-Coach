import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/practice/level_rules.dart';

void main() {
  final at = DateTime.utc(2026, 10, 18, 9);

  group('levelChangeFor', () {
    // (level, run newest first, expected new level or null)
    final cases = <(String, int, List<int>, int?)>[
      ('fewer than 3 passages', 1, [90, 90], null),
      ('empty run', 3, [], null),
      ('3 at 85+ moves up', 1, [90, 85, 99], 2),
      ('exactly 85 counts', 3, [85, 85, 85], 4),
      ('84 breaks the run', 3, [85, 84, 85], null),
      ('only the latest 3 count (up)', 2, [90, 90, 90, 10], 3),
      ('older break does not matter', 2, [90, 90, 90, 70, 70], 3),
      ('a break in the latest 3', 2, [90, 70, 90], null),
      ('never above 6', 6, [100, 100, 100], null),
      ('3 under 60 moves down', 4, [59, 30, 0], 3),
      ('exactly 60 is not under', 4, [59, 60, 59], null),
      ('only the latest 3 count (down)', 2, [10, 20, 30, 90], 1),
      ('never below 1', 1, [10, 10, 10], null),
      ('mixed 60-84 stays', 3, [70, 75, 80], null),
      ('5 to 6', 5, [95, 95, 95], 6),
    ];
    for (final (name, level, run, expected) in cases) {
      test(name, () {
        final change = levelChangeFor(level, run, at);
        if (expected == null) {
          expect(change, isNull);
        } else {
          expect(change, isNotNull);
          expect(change!.from, level);
          expect(change.to, expected);
          expect(change.at, at);
          expect(change.isUp, expected > level);
          expect(change.reason, contains('level $expected'));
        }
      });
    }
  });

  group('placementLevelFor', () {
    // scores for the level 1, 3 and 5 passages -> start level
    final cases = <(List<int>, int)>[
      ([], 1),
      ([30, 30, 30], 1),
      ([59, 100, 100], 1), // level 1 not passed: higher readings do not count
      ([60, 0, 0], 2),
      ([95, 59, 100], 2),
      ([70, 60, 0], 3),
      ([70, 79, 59], 3),
      ([70, 80, 0], 4),
      ([70, 65, 60], 5),
      ([70, 90, 79], 5),
      ([70, 65, 80], 6),
      ([95, 95, 95], 6),
      ([100, 100, 100], 6),
      ([80], 2), // missing scores count as 0
    ];
    for (final (scores, expected) in cases) {
      test('$scores -> $expected', () {
        expect(placementLevelFor(scores), expected);
      });
    }

    test('monotonic: raising any one score never lowers the level', () {
      const steps = [0, 30, 59, 60, 70, 79, 80, 90, 100];
      for (final a in steps) {
        for (final b in steps) {
          for (final c in steps) {
            final base = placementLevelFor([a, b, c]);
            expect(base, inInclusiveRange(minLevel, maxLevel));
            for (final up in steps.where((s) => s > a)) {
              expect(placementLevelFor([up, b, c]), greaterThanOrEqualTo(base));
            }
            for (final up in steps.where((s) => s > b)) {
              expect(placementLevelFor([a, up, c]), greaterThanOrEqualTo(base));
            }
            for (final up in steps.where((s) => s > c)) {
              expect(placementLevelFor([a, b, up]), greaterThanOrEqualTo(base));
            }
          }
        }
      }
    });
  });
}
