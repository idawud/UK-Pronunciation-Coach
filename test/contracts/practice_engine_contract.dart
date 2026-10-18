import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

/// Shared behaviour every [PracticeEngine] must have.
///
/// [create] returns an engine reading time from [clock], over an empty progress store
/// and a content repository holding at least `samplePassages` with them as the
/// placement set (e.g. `FakeContentRepository()` + `FakeProgressRepository()`).
void runPracticeEngineContract(
  Future<PracticeEngine> Function(Clock clock) create,
) {
  group('PracticeEngine contract', () {
    late DateTime now;
    DateTime clock() => now;
    late PracticeEngine engine;
    var n = 0;

    setUp(() async {
      now = DateTime(2026, 10, 18, 9);
      engine = await create(clock);
    });

    Future<LevelChange?> read(int score) {
      now = now.add(const Duration(minutes: 10));
      return engine.recordAttempt(
        goodAttempt(
          riverPassage,
          id: 'contract-${n++}',
          at: now,
          score: score,
          fluency: score,
        ),
      );
    }

    test('fresh engine starts at level 1', () async {
      expect(await engine.currentLevel(), 1);
      expect(await engine.dueReviewWords(), isEmpty);
    });

    test('nextPassage returns a passage; soundTag is honoured', () async {
      final p = await engine.nextPassage();
      expect(p.level, inInclusiveRange(1, 6));
      expect(p.words, isNotEmpty);
      final tagged = await engine.nextPassage(soundTag: 'θ');
      expect(tagged.soundTags, contains('θ'));
    });

    test(
      'up after 3 passages in a row at 85+, then the run restarts',
      () async {
        expect(await read(90), isNull);
        expect(await read(90), isNull);
        final change = await read(90);
        expect(change, isNotNull);
        expect(change!.from, 1);
        expect(change.to, 2);
        expect(change.isUp, isTrue);
        expect(change.reason.trim(), isNotEmpty);
        expect(await engine.currentLevel(), 2);
        expect(await read(90), isNull);
      },
    );

    test('a break in the run resets it', () async {
      await read(90);
      await read(90);
      await read(70);
      expect(await read(90), isNull);
      expect(await engine.currentLevel(), 1);
    });

    test('down after 3 in a row under 60, never below 1', () async {
      expect(await read(40), isNull);
      expect(await read(40), isNull);
      expect(await read(40), isNull);
      expect(await engine.currentLevel(), 1);

      final results = [
        for (final p in samplePassages)
          goodAttempt(p, id: 'place-${p.id}', at: now, score: 95, fluency: 95),
      ];
      await engine.completePlacement(results);
      final start = await engine.currentLevel();
      expect(start, greaterThan(1));
      await read(50);
      await read(50);
      final change = await read(50);
      expect(change, isNotNull);
      expect(change!.to, start - 1);
      expect(change.isUp, isFalse);
      expect(change.reason.trim(), isNotEmpty);
    });

    test('red words come back for review after one day', () async {
      await engine.recordAttempt(cannedRiverAttempt.copyWith(at: now));
      expect(await engine.dueReviewWords(), isEmpty);
      now = now.add(const Duration(days: 1, minutes: 1));
      final due = await engine.dueReviewWords();
      expect(due, containsAll(['Thursday', 'castle', 'bath']));
      final items = await engine.dueReviews();
      expect(
        items.singleWhere((r) => r.key == 'thursday').phonemes,
        isNotEmpty,
      );
    });

    test('weakest sounds are sorted and limited', () async {
      await engine.recordAttempt(cannedRiverAttempt.copyWith(at: now));
      final weak = await engine.weakestSounds();
      expect(weak.length, inInclusiveRange(1, 3));
      for (var i = 1; i < weak.length; i++) {
        expect(weak[i].accuracy, greaterThanOrEqualTo(weak[i - 1].accuracy));
      }
      expect(await engine.weakestSounds(count: 1), hasLength(1));
    });

    test('daily minutes and goal', () async {
      await engine.logPracticeTime(const Duration(minutes: 12));
      final d = await engine.dailyProgress();
      expect(d.minutesToday, 12);
      expect(d.streak, 1);
      expect(d.dailyGoalMinutes, greaterThan(0));
      expect(d.practisedDays, contains(DateTime(2026, 10, 18)));
    });

    test(
      'streak counts consecutive days and breaks after a missed day',
      () async {
        for (var day = 0; day < 3; day++) {
          now = DateTime(2026, 10, 10 + day, 19);
          await engine.logPracticeTime(const Duration(minutes: 5));
        }
        expect((await engine.dailyProgress()).streak, 3);
        now = DateTime(
          2026,
          10,
          13,
          8,
        ); // not practised yet today: streak holds
        expect((await engine.dailyProgress()).streak, 3);
        expect((await engine.dailyProgress()).minutesToday, 0);
        now = DateTime(2026, 10, 14, 8); // missed the 13th
        expect((await engine.dailyProgress()).streak, 0);
        await engine.logPracticeTime(const Duration(minutes: 5));
        expect((await engine.dailyProgress()).streak, 1);
      },
    );

    test('practice either side of midnight counts as two days', () async {
      now = DateTime(2026, 10, 20, 23, 50);
      await engine.logPracticeTime(const Duration(minutes: 5));
      now = DateTime(2026, 10, 21, 0, 10);
      await engine.logPracticeTime(const Duration(minutes: 5));
      final d = await engine.dailyProgress();
      expect(d.streak, 2);
      expect(d.minutesToday, 5);
    });

    test('streak survives the October clock change', () async {
      now = DateTime(2026, 10, 24, 12);
      await engine.logPracticeTime(const Duration(minutes: 5));
      now = DateTime(2026, 10, 25, 12); // UK clocks go back this night
      await engine.logPracticeTime(const Duration(minutes: 5));
      now = DateTime(2026, 10, 26, 12);
      await engine.logPracticeTime(const Duration(minutes: 5));
      expect((await engine.dailyProgress()).streak, 3);
    });

    test('placement passages are levels 1, 3, 5', () async {
      expect((await engine.placementPassages()).map((p) => p.level), [1, 3, 5]);
    });

    test('placementLevel is monotonic and bounded', () async {
      AttemptResult r(Passage p, int s) =>
          goodAttempt(p, id: 'p${p.id}$s', at: now, score: s, fluency: s);
      int level(List<int> s) => engine.placementLevel([
        r(teaPassage, s[0]),
        r(riverPassage, s[1]),
        r(linkingPassage, s[2]),
      ]);
      expect(level([30, 30, 30]), 1);
      expect(level([95, 95, 95]), greaterThanOrEqualTo(5));
      var previous = 0;
      for (var s = 0; s <= 100; s += 10) {
        final l = level([s, s, s]);
        expect(l, inInclusiveRange(1, 6));
        expect(l, greaterThanOrEqualTo(previous));
        previous = l;
      }
    });

    test('completePlacement sets the level', () async {
      final results = [
        for (final p in samplePassages)
          goodAttempt(p, id: 'cp-${p.id}', at: now, score: 80, fluency: 80),
      ];
      final expected = engine.placementLevel(results);
      final change = await engine.completePlacement(results);
      expect(await engine.currentLevel(), expected);
      if (expected == 1) {
        expect(change, isNull);
      } else {
        expect(change!.to, expected);
        expect(change.reason.trim(), isNotEmpty);
      }
    });
  });
}
