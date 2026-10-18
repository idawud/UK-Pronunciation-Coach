import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

/// Shared behaviour every [ProgressRepository] must have.
///
/// [create] returns a fresh, empty repository (e.g. an in-memory database) that reads
/// the time from [clock]. Each call must give an independent store.
void runProgressRepositoryContract(
  Future<ProgressRepository> Function(Clock clock) create,
) {
  group('ProgressRepository contract', () {
    var now = DateTime(2026, 10, 18, 9);
    DateTime clock() => now;
    late ProgressRepository repo;
    late Directory tmp;

    setUp(() async {
      now = DateTime(2026, 10, 18, 9);
      repo = await create(clock);
      tmp = await Directory.systemTemp.createTemp('progress_contract');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    AttemptResult attemptAt(String id, DateTime at, {String? passage}) =>
        goodAttempt(
          passage == 'tea' ? teaPassage : riverPassage,
          id: id,
          at: at,
        );

    test('profile defaults, then round-trips', () async {
      expect(await repo.profile(), const UserProfile());
      const p = UserProfile(
        level: 3,
        dailyGoalMinutes: 15,
        streak: 4,
        keepRecordings: true,
        placementDone: true,
        placementLevel: 3,
        reminderMinutes: 1140,
        textScale: 1.2,
        tierOverride: ModelTier.light,
        onboardingDone: true,
      );
      await repo.saveProfile(p.copyWith(lastPractice: now));
      expect(await repo.profile(), p.copyWith(lastPractice: now));
    });

    test('attempt round-trips with words and phonemes', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      expect(await repo.attempt(cannedRiverAttempt.id), cannedRiverAttempt);
      expect(await repo.attempt('missing'), isNull);
    });

    test('attempts: newest first, filters, limit', () async {
      final t = DateTime(2026, 10, 1, 12);
      for (var i = 0; i < 5; i++) {
        await repo.saveAttempt(
          attemptAt(
            'a$i',
            t.add(Duration(days: i)),
            passage: i.isEven ? 'tea' : null,
          ),
        );
      }
      expect((await repo.attempts()).map((a) => a.id), [
        'a4',
        'a3',
        'a2',
        'a1',
        'a0',
      ]);
      expect((await repo.attempts(passageId: teaPassage.id)).map((a) => a.id), [
        'a4',
        'a2',
        'a0',
      ]);
      expect(
        (await repo.attempts(since: t.add(const Duration(days: 3))))
            .map((a) => a.id),
        ['a4', 'a3'],
      );
      expect((await repo.attempts(limit: 2)).map((a) => a.id), ['a4', 'a3']);
    });

    test('saving an attempt with the same id replaces it', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      await repo.saveAttempt(cannedRiverAttempt.copyWith(fluency: 50));
      final all = await repo.attempts();
      expect(all, hasLength(1));
      expect(all.single.fluency, 50);
    });

    test('saveAttempt folds phoneme scores into sound stats', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      final stats = await repo.soundStats();
      expect(stats, isNotEmpty);
      for (var i = 1; i < stats.length; i++) {
        expect(stats[i].accuracy, greaterThanOrEqualTo(stats[i - 1].accuracy));
      }
      final theta = stats.singleWhere((s) => s.ipa == 'θ');
      final scores = [
        for (final w in cannedRiverAttempt.words)
          for (final p in w.phonemes)
            if (p.expected == 'θ') p.score,
      ];
      expect(theta.attempts, scores.length);
      expect(
        theta.accuracy,
        inInclusiveRange(
          scores.reduce((a, b) => a < b ? a : b).toDouble(),
          scores.reduce((a, b) => a > b ? a : b).toDouble(),
        ),
      );
    });

    test('recording is deleted unless keepRecordings', () async {
      final f = File('${tmp.path}/a.wav')..writeAsBytesSync([0, 1, 2]);
      await repo.saveAttempt(cannedRiverAttempt.copyWith(audioPath: f.path));
      expect(f.existsSync(), isFalse);
      expect((await repo.attempt(cannedRiverAttempt.id))!.audioPath, isNull);

      await repo.saveProfile(const UserProfile(keepRecordings: true));
      final g = File('${tmp.path}/b.wav')..writeAsBytesSync([0, 1, 2]);
      await repo.saveAttempt(
        cannedRiverAttempt.copyWith(id: 'kept', audioPath: g.path),
      );
      expect(g.existsSync(), isTrue);
      expect((await repo.attempt('kept'))!.audioPath, g.path);
    });

    test('updateWordResult replaces one word and keeps the totals', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      final old = cannedRiverAttempt.words[1];
      final retried = old.copyWith(score: 88, status: WordStatus.good);
      final updated = await repo.updateWordResult(
        cannedRiverAttempt.id,
        retried,
      );
      expect(updated.words[1], retried);
      expect(updated.overall, cannedRiverAttempt.overall);
      expect(updated.accuracy, cannedRiverAttempt.accuracy);
      expect(updated.words[0], cannedRiverAttempt.words[0]);
      expect(await repo.attempt(cannedRiverAttempt.id), updated);
    });

    test('updateWordResult errors', () async {
      await expectLater(
        repo.updateWordResult('missing', cannedRiverAttempt.words.first),
        throwsA(isA<AttemptNotFoundException>()),
      );
      await repo.saveAttempt(cannedRiverAttempt);
      await expectLater(
        repo.updateWordResult(
          cannedRiverAttempt.id,
          cannedRiverAttempt.words.first.copyWith(index: 999),
        ),
        throwsRangeError,
      );
    });

    test('updateWordResult reschedules or enqueues review words', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      await repo.upsertReview(ReviewItem.enqueue(word: 'Thursday', now: now));
      final thursday = cannedRiverAttempt.words[1];
      await repo.updateWordResult(
        cannedRiverAttempt.id,
        thursday.copyWith(score: 90, status: WordStatus.good),
      );
      final q1 = await repo.reviewQueue();
      final item = q1.singleWhere((r) => r.key == 'thursday');
      expect(item.stage, 1);
      expect(item.intervalDays, ReviewItem.intervals[1]);

      final castle = cannedRiverAttempt.words[11];
      await repo.updateWordResult(
        cannedRiverAttempt.id,
        castle.copyWith(score: 40),
      );
      expect((await repo.reviewQueue()).map((r) => r.key), contains('castle'));
    });

    test('review queue: upsert by key, due filter, remove', () async {
      await repo.upsertReview(ReviewItem.enqueue(word: 'bath', now: now));
      await repo.upsertReview(
        ReviewItem.enqueue(word: 'Bath', now: now.add(const Duration(days: 1))),
      );
      await repo.upsertReview(
        ReviewItem.enqueue(
          word: 'castle',
          now: now.subtract(const Duration(days: 2)),
        ),
      );
      final q = await repo.reviewQueue();
      expect(q.map((r) => r.key), ['castle', 'bath']);
      expect(q.last.word, 'Bath');
      expect((await repo.dueReviews(now)).map((r) => r.key), ['castle']);
      await repo.removeReview('CASTLE');
      await repo.removeReview('not-there');
      expect((await repo.reviewQueue()).map((r) => r.key), ['bath']);
    });

    test('level history and practice sessions are kept in order', () async {
      final c2 = LevelChange(from: 2, to: 3, reason: 'Up', at: now);
      final c1 = LevelChange(
        from: 1,
        to: 2,
        reason: 'Up',
        at: now.subtract(const Duration(days: 3)),
      );
      await repo.saveLevelChange(c2);
      await repo.saveLevelChange(c1);
      expect(await repo.levelHistory(), [c1, c2]);

      final s1 = PracticeSession(
        start: now.subtract(const Duration(days: 1)),
        duration: const Duration(minutes: 5),
      );
      final s2 = PracticeSession(
        start: now,
        duration: const Duration(minutes: 7),
      );
      await repo.logPractice(s2);
      await repo.logPractice(s1);
      expect(await repo.practiceSessions(), [s1, s2]);
      expect(await repo.practiceSessions(since: now), [s2]);
    });

    test('changes fires after writes', () async {
      final next = repo.changes.first.timeout(const Duration(seconds: 5));
      await repo.saveProfile(const UserProfile(level: 2));
      await next;
    });

    test('export then import into a fresh store restores everything', () async {
      await repo.saveProfile(const UserProfile(level: 4, keepRecordings: true));
      await repo.saveAttempt(cannedRiverAttempt);
      await repo.saveAttempt(attemptAt('second', now, passage: 'tea'));
      await repo.upsertReview(ReviewItem.enqueue(word: 'bath', now: now));
      await repo.saveLevelChange(
        LevelChange(from: 3, to: 4, reason: 'Up', at: now),
      );
      await repo.logPractice(
        PracticeSession(start: now, duration: const Duration(minutes: 3)),
      );
      final json = await repo.exportJson();
      final backup = ProgressBackup.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(backup.schemaVersion, ProgressBackup.currentSchemaVersion);
      expect(backup.attempts, hasLength(2));

      final other = await create(clock);
      await other.importJson(json);
      expect(await other.profile(), await repo.profile());
      expect(await other.attempts(), await repo.attempts());
      expect(await other.soundStats(), await repo.soundStats());
      expect(await other.reviewQueue(), await repo.reviewQueue());
      expect(await other.levelHistory(), await repo.levelHistory());
      expect(await other.practiceSessions(), await repo.practiceSessions());
    });

    test('import rejects bad input and changes nothing', () async {
      await repo.saveProfile(const UserProfile(level: 5));
      await expectLater(repo.importJson('not json'), throwsFormatException);
      await expectLater(repo.importJson('[]'), throwsFormatException);
      final future = ProgressBackup(
        schemaVersion: 999,
        exportedAt: now,
        profile: const UserProfile(),
      );
      await expectLater(
        repo.importJson(jsonEncode(future.toJson())),
        throwsFormatException,
      );
      expect((await repo.profile()).level, 5);
    });

    test('deleteAll wipes data and kept recordings', () async {
      await repo.saveProfile(const UserProfile(level: 4, keepRecordings: true));
      final f = File('${tmp.path}/kept.wav')..writeAsBytesSync([1]);
      await repo.saveAttempt(cannedRiverAttempt.copyWith(audioPath: f.path));
      await repo.upsertReview(ReviewItem.enqueue(word: 'bath', now: now));
      await repo.saveLevelChange(
        LevelChange(from: 3, to: 4, reason: 'Up', at: now),
      );
      await repo.logPractice(
        PracticeSession(start: now, duration: const Duration(minutes: 3)),
      );
      await repo.deleteAll();
      expect(f.existsSync(), isFalse);
      expect(await repo.attempts(), isEmpty);
      expect(await repo.soundStats(), isEmpty);
      expect(await repo.reviewQueue(), isEmpty);
      expect(await repo.levelHistory(), isEmpty);
      expect(await repo.practiceSessions(), isEmpty);
      expect(await repo.profile(), const UserProfile());
    });
  });
}
