import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/practice/local_days.dart';

import 'zones.dart';

void main() {
  group('europeLondon helper', () {
    test('GMT in winter, BST in summer, changes at 01:00 UTC', () {
      expect(europeLondon(DateTime.utc(2026, 1, 10, 12)).hour, 12);
      expect(europeLondon(DateTime.utc(2026, 7, 10, 12)).hour, 13);
      // 2026: BST starts 29 March, ends 25 October.
      expect(europeLondon(DateTime.utc(2026, 3, 29, 0, 59)).hour, 0);
      expect(europeLondon(DateTime.utc(2026, 3, 29, 1)).hour, 2);
      expect(europeLondon(DateTime.utc(2026, 10, 25, 0, 59)).hour, 1);
      expect(europeLondon(DateTime.utc(2026, 10, 25, 1)).hour, 1);
    });
  });

  group('LocalDay', () {
    test('of uses the wall clock, not UTC', () {
      // 23:30 UTC on 1 July is 00:30 on 2 July in London.
      final t = DateTime.utc(2026, 7, 1, 23, 30);
      expect(LocalDay.of(t, europeLondon), LocalDay.ymd(2026, 7, 2));
      expect(
        LocalDay.of(t, fixedOffset(Duration.zero)),
        LocalDay.ymd(2026, 7, 1),
      );
      expect(
        LocalDay.of(t, fixedOffset(const Duration(hours: -5))),
        LocalDay.ymd(2026, 7, 1),
      );
    });

    test('device wall clock: local DateTimes are taken as they are', () {
      expect(
        LocalDay.of(DateTime(2026, 10, 25, 0, 30), deviceWallClock),
        LocalDay.ymd(2026, 10, 25),
      );
      final u = DateTime.utc(2026, 10, 25, 12);
      expect(
        LocalDay.of(u, deviceWallClock),
        LocalDay.of(u.toLocal(), deviceWallClock),
      );
    });

    test('plus, ymd normalisation and toDate', () {
      final d = LocalDay.ymd(2026, 3, 1);
      expect(d.plus(-1), LocalDay.ymd(2026, 2, 28));
      expect(LocalDay.ymd(2026, 3, 0), LocalDay.ymd(2026, 2, 28));
      expect(d.plus(-1).toDate(), DateTime(2026, 2, 28));
      expect(LocalDay.ymd(2026, 12, 32), LocalDay.ymd(2027, 1, 1));
      // Days across both clock changes are exactly one apart.
      expect(LocalDay.ymd(2026, 3, 30).plus(-1), LocalDay.ymd(2026, 3, 29));
      expect(LocalDay.ymd(2026, 10, 26).plus(-1), LocalDay.ymd(2026, 10, 25));
    });
  });

  group('splitByLocalDay', () {
    Map<LocalDay, Duration> split(DateTime start, Duration d, WallClock z) =>
        splitByLocalDay(PracticeSession(start: start, duration: d), z);

    test('within one day', () {
      expect(
        split(
          DateTime.utc(2026, 1, 5, 10),
          const Duration(minutes: 12),
          europeLondon,
        ),
        {LocalDay.ymd(2026, 1, 5): const Duration(minutes: 12)},
      );
    });

    test('non-positive durations credit nothing', () {
      expect(
        split(DateTime.utc(2026, 1, 5), Duration.zero, europeLondon),
        isEmpty,
      );
      expect(
        split(
          DateTime.utc(2026, 1, 5),
          const Duration(minutes: -3),
          europeLondon,
        ),
        isEmpty,
      );
    });

    final cases =
        <(String, DateTime, Duration, WallClock, Map<LocalDay, Duration>)>[
          (
            'across midnight (GMT)',
            DateTime.utc(2026, 1, 5, 23, 50),
            const Duration(minutes: 20),
            europeLondon,
            {
              LocalDay.ymd(2026, 1, 5): const Duration(minutes: 10),
              LocalDay.ymd(2026, 1, 6): const Duration(minutes: 10),
            },
          ),
          (
            'across midnight (BST: 23:50 London is 22:50 UTC)',
            DateTime.utc(2026, 7, 5, 22, 50),
            const Duration(minutes: 20),
            europeLondon,
            {
              LocalDay.ymd(2026, 7, 5): const Duration(minutes: 10),
              LocalDay.ymd(2026, 7, 6): const Duration(minutes: 10),
            },
          ),
          (
            'over the October change (01:00-02:00 BST then GMT): elapsed time counts',
            DateTime.utc(2026, 10, 24, 23, 30), // 00:30 BST on the 25th
            const Duration(hours: 2),
            europeLondon,
            {LocalDay.ymd(2026, 10, 25): const Duration(hours: 2)},
          ),
          (
            'over the March change',
            DateTime.utc(2026, 3, 28, 23, 30), // 23:30 GMT on the 28th
            const Duration(hours: 2),
            europeLondon,
            {
              LocalDay.ymd(2026, 3, 28): const Duration(minutes: 30),
              LocalDay.ymd(2026, 3, 29): const Duration(minutes: 90),
            },
          ),
          (
            'longer than a day',
            DateTime.utc(2026, 1, 5, 12),
            const Duration(hours: 36),
            europeLondon,
            {
              LocalDay.ymd(2026, 1, 5): const Duration(hours: 12),
              LocalDay.ymd(2026, 1, 6): const Duration(hours: 24),
            },
          ),
        ];
    for (final (name, start, d, zone, expected) in cases) {
      test(name, () => expect(split(start, d, zone), expected));
    }
  });

  group('streakFor', () {
    final today = LocalDay.ymd(2026, 10, 18);
    Set<LocalDay> days(List<int> back) => {
      for (final b in back) today.plus(-b),
    };
    // days practised (0 = today, 1 = yesterday, ...) -> streak
    final cases = <(String, List<int>, int)>[
      ('no practice', [], 0),
      ('today only', [0], 1),
      ('yesterday only: holds until today ends', [1], 1),
      ('three days to today', [0, 1, 2], 3),
      ('three days to yesterday', [1, 2, 3], 3),
      ('missed yesterday and today', [2, 3, 4], 0),
      ('gap breaks the run', [0, 1, 3, 4, 5], 2),
      ('today after a missed day', [0, 2, 3], 1),
    ];
    for (final (name, back, expected) in cases) {
      test(name, () => expect(streakFor(days(back), today), expected));
    }
  });
}
