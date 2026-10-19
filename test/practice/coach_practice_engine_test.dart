import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/practice/practice.dart';

import '../contracts/practice_engine_contract.dart';
import 'zones.dart';

void main() {
  group('CoachPracticeEngine (device time zone)', () {
    runPracticeEngineContract(
      (clock) async => CoachPracticeEngine(
        content: FakeContentRepository(),
        progress: FakeProgressRepository(clock: clock),
        clock: clock,
        random: Random(1),
      ),
    );
  });

  group('CoachPracticeEngine (Europe/London, UTC instants)', () {
    runPracticeEngineContract(
      (clock) async => CoachPracticeEngine(
        content: FakeContentRepository(),
        progress: FakeProgressRepository(clock: clock),
        // The suite uses local wall-clock DateTimes; read them as London time.
        clock: () => londonInstant(clock()),
        wallClock: europeLondon,
        random: Random(2),
      ),
    );
  });

  late DateTime now;
  late WallClock zone;
  late FakeProgressRepository progress;
  late CoachPracticeEngine engine;
  var n = 0;

  setUp(() {
    now = DateTime.utc(2026, 10, 18, 9);
    zone = europeLondon;
    progress = FakeProgressRepository(clock: () => now);
    engine = CoachPracticeEngine(
      content: FakeContentRepository(),
      progress: progress,
      clock: () => now,
      wallClock: (t) => zone(t),
      random: Random(3),
    );
  });

  Future<LevelChange?> read(Passage p, int score) {
    now = now.add(const Duration(minutes: 10));
    return engine.recordAttempt(
      goodAttempt(p, id: 'a${n++}', at: now, score: score, fluency: score),
    );
  }

  group('recordAttempt', () {
    test(
      'saves the attempt once, the change, the streak and lastPractice',
      () async {
        await read(teaPassage, 90);
        await read(teaPassage, 90);
        final change = await read(teaPassage, 90);
        expect(change!.to, 2);
        expect(await progress.attempts(), hasLength(3));
        expect(await progress.levelHistory(), [change]);
        final profile = await progress.profile();
        expect(profile.level, 2);
        expect(profile.streak, 1);
        expect(profile.lastPractice, now);
      },
    );

    test(
      'a level change restarts the run; further runs keep climbing',
      () async {
        for (var i = 0; i < 3; i++) {
          await read(teaPassage, 95);
        }
        expect(await engine.currentLevel(), 2);
        expect(await read(teaPassage, 95), isNull);
        expect(await read(teaPassage, 95), isNull);
        expect((await read(teaPassage, 95))!.to, 3);
      },
    );

    test('custom text: saved, red words queued with dictionary phonemes, '
        'no effect on the level', () async {
      final custom = buildAttempt(
        riverPassage,
        id: 'custom',
        at: now,
        defaultScore: (i) => i == 1 ? 30 : 95,
        fluency: 95,
      ).copyWith(passageId: 'custom:hello');
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(minutes: 1));
        expect(
          await engine.recordAttempt(custom.copyWith(id: 'c$i', at: now)),
          isNull,
        );
      }
      expect(await engine.currentLevel(), 1);
      expect(await progress.attempts(), hasLength(3));
      final q = await progress.reviewQueue();
      expect(q.single.word, 'Thursday');
      expect(q.single.phonemes, riverPassage.words[1].phonemes);
      expect(q.single.passageId, 'custom:hello');
    });

    test('custom text attempts do not break or join a passage run', () async {
      await read(teaPassage, 95);
      await read(teaPassage, 95);
      now = now.add(const Duration(minutes: 1));
      await engine.recordAttempt(
        goodAttempt(
          teaPassage,
          id: 'x',
          at: now,
          score: 10,
          fluency: 10,
        ).copyWith(passageId: 'custom:x'),
      );
      expect((await read(teaPassage, 95))?.to, 2);
    });

    test(
      'spaced review through the engine: 1, 3, 7, 21 days then graduates',
      () async {
        final miss = buildAttempt(
          riverPassage,
          id: 'm',
          at: now,
          defaultScore: (i) => i == 11 ? 20 : 95, // castle
        );
        await engine.recordAttempt(miss);
        var item = (await progress.reviewQueue()).single;
        expect(item.word, 'castle');
        expect(item.phonemes, riverPassage.words[11].phonemes);
        for (final days in [1, 3, 7, 21]) {
          expect(item.intervalDays, days);
          now = item.due;
          expect(await engine.dueReviewWords(), ['castle']);
          await engine.recordAttempt(
            goodAttempt(riverPassage, id: 'r$days', at: now, score: 90),
          );
          final q = await progress.reviewQueue();
          if (days == 21) {
            expect(q, isEmpty);
          } else {
            item = q.single;
          }
        }
      },
    );

    test('a bad read resets a queued word to 1 day', () async {
      await engine.recordAttempt(
        buildAttempt(
          riverPassage,
          id: 'm',
          at: now,
          defaultScore: (i) => i == 11 ? 20 : 95,
        ),
      );
      now = now.add(const Duration(days: 1));
      await engine.recordAttempt(goodAttempt(riverPassage, id: 'g', at: now));
      expect((await progress.reviewQueue()).single.stage, 1);
      now = now.add(const Duration(days: 3));
      await engine.recordAttempt(
        buildAttempt(
          riverPassage,
          id: 'b',
          at: now,
          defaultScore: (i) => i == 11 ? 40 : 95,
        ),
      );
      final item = (await progress.reviewQueue()).single;
      expect(item.stage, 0);
      expect(item.due, ReviewItem.addDays(now, 1));
    });

    test('level change is stamped no earlier than the attempt', () async {
      final later = now.add(const Duration(hours: 1));
      for (var i = 0; i < 3; i++) {
        await engine.recordAttempt(
          goodAttempt(
            teaPassage,
            id: 'l$i',
            at: later.add(Duration(minutes: i)),
          ),
        );
      }
      final change = (await progress.levelHistory()).single;
      expect(change.at, later.add(const Duration(minutes: 2)));
    });
  });

  group('placement', () {
    test(
      'placement attempts are not saved; unchanged level gives null',
      () async {
        final results = [
          for (final p in samplePassages)
            goodAttempt(p, id: 'p${p.id}', at: now, score: 30, fluency: 30),
        ];
        expect(engine.placementLevel(results), 1);
        expect(await engine.completePlacement(results), isNull);
        expect(await progress.attempts(), isEmpty);
        final profile = await progress.profile();
        expect(profile.placementDone, isTrue);
        expect(profile.placementLevel, 1);
        expect(await engine.placementPassages(), samplePassages);
      },
    );

    test(
      'attempts before placement do not count towards the next run',
      () async {
        await read(teaPassage, 95);
        await read(teaPassage, 95);
        now = now.add(const Duration(minutes: 1));
        final change = await engine.completePlacement([
          for (final s in [70, 65, 0])
            goodAttempt(teaPassage, id: 'p$s', at: now, score: s, fluency: s),
        ]);
        expect(change!.to, 3);
        expect(await read(teaPassage, 95), isNull);
        expect(await read(teaPassage, 95), isNull);
        expect((await read(teaPassage, 95))!.to, 4);
      },
    );
  });

  group('misc', () {
    test('currentLevel is clamped to 1-6', () async {
      await progress.saveProfile(const UserProfile(level: 9));
      expect(await engine.currentLevel(), 6);
    });

    test('weakestSounds with count 0', () async {
      await engine.recordAttempt(cannedRiverAttempt.copyWith(at: now));
      expect(await engine.weakestSounds(count: 0), isEmpty);
      expect(
        await engine.weakestSounds(count: 100),
        hasLength((await progress.soundStats()).length),
      );
    });

    test('nextPassage avoids the last 10 sessions where possible', () async {
      final lib = [
        for (var i = 0; i < 12; i++)
          buildPassage(
            id: 'p$i',
            level: 1,
            title: 't',
            text: 'tea',
            ipa: ['t ˈiː'],
          ),
      ];
      final e = CoachPracticeEngine(
        content: FakeContentRepository(passages: lib),
        progress: progress,
        clock: () => now,
        random: Random(4),
      );
      for (var i = 0; i < 40; i++) {
        final p = await e.nextPassage();
        final recent = [
          for (final a in await progress.attempts(limit: 10)) a.passageId,
        ];
        expect(recent, isNot(contains(p.id)));
        now = now.add(const Duration(minutes: 5));
        await e.recordAttempt(goodAttempt(p, id: 'n$i', at: now, score: 70));
      }
    });

    test(
      'nextPassage(soundTag:) falls back to any level and to the mix',
      () async {
        expect(
          (await engine.nextPassage(soundTag: 'linking')).id,
          linkingPassage.id,
        );
        expect((await engine.nextPassage(soundTag: 'nope')).level, 1);
      },
    );

    test('nextPassage with an empty library throws StateError', () async {
      final e = CoachPracticeEngine(
        content: FakeContentRepository(passages: const []),
        progress: progress,
        clock: () => now,
      );
      await expectLater(e.nextPassage(), throwsStateError);
    });
  });

  group('daily progress and streaks (Europe/London)', () {
    Future<void> practise(DateTime at, [int minutes = 5]) {
      now = at;
      return engine.logPracticeTime(Duration(minutes: minutes));
    }

    test('zero or negative time is ignored', () async {
      await engine.logPracticeTime(Duration.zero);
      await engine.logPracticeTime(const Duration(minutes: -1));
      expect(await progress.practiceSessions(), isEmpty);
      expect((await engine.dailyProgress()).streak, 0);
    });

    test('logging updates the stored streak', () async {
      await practise(DateTime.utc(2026, 10, 17, 9));
      await practise(DateTime.utc(2026, 10, 18, 9));
      final profile = await progress.profile();
      expect(profile.streak, 2);
      expect(profile.lastPractice, DateTime.utc(2026, 10, 18, 9));
    });

    // Each case: practice times (UTC), "now" (UTC), expected streak and minutes today.
    final cases = <(String, List<(DateTime, int)>, DateTime, int, int)>[
      (
        'London midnight in BST is 23:00 UTC',
        [
          (DateTime.utc(2026, 7, 1, 22, 50), 5),
          (DateTime.utc(2026, 7, 1, 23, 10), 5),
        ],
        DateTime.utc(2026, 7, 1, 23, 30),
        2,
        5,
      ),
      (
        'same UTC day, two London days (23:30 UTC is 00:30 BST)',
        [
          (DateTime.utc(2026, 7, 1, 0, 30), 5),
          (DateTime.utc(2026, 7, 1, 23, 30), 5),
        ],
        DateTime.utc(2026, 7, 1, 23, 40),
        2,
        5,
      ),
      (
        'session over midnight credits both days',
        [(DateTime.utc(2026, 1, 9, 23, 50), 20)],
        DateTime.utc(2026, 1, 10, 9),
        2,
        10,
      ),
      (
        'October change: 23:30 on the 24th then 23:30 on the 25th (GMT)',
        [
          (DateTime.utc(2026, 10, 24, 22, 30), 5),
          (DateTime.utc(2026, 10, 25, 23, 30), 5),
        ],
        DateTime.utc(2026, 10, 25, 23, 45),
        2,
        5,
      ),
      (
        'March change: 00:30 GMT on the 29th then 00:30 BST on the 30th',
        [
          (DateTime.utc(2026, 3, 29, 0, 30), 5),
          (DateTime.utc(2026, 3, 29, 23, 30), 5),
        ],
        DateTime.utc(2026, 3, 29, 23, 40),
        2,
        5,
      ),
      (
        'October 25th is 25 hours long: still one day',
        [
          (DateTime.utc(2026, 10, 24, 23, 5), 5),
          (DateTime.utc(2026, 10, 25, 23, 55), 5),
        ],
        DateTime.utc(2026, 10, 25, 23, 58),
        1,
        10,
      ),
      (
        'missed day after the clock change breaks the streak',
        [(DateTime.utc(2026, 10, 24, 12), 5)],
        DateTime.utc(2026, 10, 26, 0, 1),
        0,
        0,
      ),
      (
        'just before midnight the streak still holds',
        [(DateTime.utc(2026, 10, 24, 12), 5)],
        DateTime.utc(2026, 10, 25, 23, 59),
        1,
        0,
      ),
    ];
    for (final (name, sessions, at, streak, minutes) in cases) {
      test(name, () async {
        for (final (t, m) in sessions) {
          await practise(t, m);
        }
        now = at;
        final d = await engine.dailyProgress();
        expect(d.streak, streak);
        expect(d.minutesToday, minutes);
        expect(d.dailyGoalMinutes, 10);
      });
    }

    test('attempts count as practised days', () async {
      now = DateTime.utc(2026, 10, 17, 9);
      await engine.recordAttempt(goodAttempt(teaPassage, id: 'x', at: now));
      now = DateTime.utc(2026, 10, 18, 9);
      final d = await engine.dailyProgress();
      expect(d.streak, 1);
      expect(d.practisedDays, [DateTime(2026, 10, 17)]);
      expect(d.minutesToday, 0);
    });

    test('travel: days follow the current device time zone', () async {
      await practise(DateTime.utc(2026, 10, 18, 20)); // 21:00 BST on the 18th
      await practise(DateTime.utc(2026, 10, 19, 12)); // 13:00 BST on the 19th
      // Fly west to New York (UTC-4): 02:00 UTC on the 20th is 22:00 on the 19th.
      zone = fixedOffset(const Duration(hours: -4));
      now = DateTime.utc(2026, 10, 20, 2);
      var d = await engine.dailyProgress();
      expect(d.streak, 2);
      expect(d.minutesToday, 5);
      expect(d.practisedDays, [DateTime(2026, 10, 18), DateTime(2026, 10, 19)]);
      // Fly east to Tokyo (UTC+9): both sessions fall on the 19th; today is the 20th.
      zone = fixedOffset(const Duration(hours: 9));
      d = await engine.dailyProgress();
      expect(d.practisedDays, [DateTime(2026, 10, 19)]);
      expect(d.streak, 1);
      expect(d.minutesToday, 0);
    });
  });
}
