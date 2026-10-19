import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/data/data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  var now = DateTime(2026, 10, 18, 9);
  DateTime clock() => now;
  late Directory tmp;
  late Directory recDir;
  late DriftProgressRepository repo;

  setUp(() async {
    now = DateTime(2026, 10, 18, 9);
    tmp = await Directory.systemTemp.createTemp('c2_repo');
    recDir = await Directory('${tmp.path}/recordings').create();
    repo = DriftProgressRepository.inMemory(
      clock: clock,
      recordings: RecordingStore(directory: recDir),
    );
  });
  tearDown(() async {
    await repo.close();
    await tmp.delete(recursive: true);
  });

  File wav(String name) =>
      File('${recDir.path}/$name')..writeAsBytesSync([0, 1, 2]);

  group('attempts', () {
    test(
      'UTC and local times round-trip exactly and sort by instant',
      () async {
        final utc = DateTime.utc(2026, 1, 2, 3, 4, 5, 6, 7);
        final local = DateTime(2026, 1, 3, 3, 4, 5, 6, 7);
        await repo.saveAttempt(cannedRiverAttempt.copyWith(id: 'u', at: utc));
        await repo.saveAttempt(cannedRiverAttempt.copyWith(id: 'l', at: local));
        expect((await repo.attempt('u'))!.at, utc);
        expect((await repo.attempt('u'))!.at.isUtc, isTrue);
        expect((await repo.attempt('l'))!.at, local);
        expect((await repo.attempts()).map((a) => a.id), ['l', 'u']);
        expect((await repo.attempts(since: utc)).map((a) => a.id), ['l', 'u']);
        expect(
          (await repo.attempts(since: utc.add(const Duration(microseconds: 1))))
              .map((a) => a.id),
          ['l'],
        );
      },
    );

    test('limit 0 returns nothing; ties sort by id', () async {
      final t = DateTime(2026, 10, 1);
      await repo.saveAttempt(cannedRiverAttempt.copyWith(id: 'a', at: t));
      await repo.saveAttempt(cannedRiverAttempt.copyWith(id: 'b', at: t));
      expect(await repo.attempts(limit: 0), isEmpty);
      expect((await repo.attempts()).map((a) => a.id), ['b', 'a']);
    });

    test('light tier and attempts without words round-trip', () async {
      final a = cannedRiverAttempt.copyWith(
        id: 'light',
        tier: ModelTier.light,
        words: const [],
      );
      await repo.saveAttempt(a);
      expect(await repo.attempt('light'), a);
      expect(await repo.soundStats(), isEmpty);
    });

    test('replacing a kept attempt deletes the replaced recording', () async {
      await repo.saveProfile(const UserProfile(keepRecordings: true));
      final first = wav('1.wav');
      final second = wav('2.wav');
      await repo.saveAttempt(
        cannedRiverAttempt.copyWith(audioPath: first.path),
      );
      await repo.saveAttempt(
        cannedRiverAttempt.copyWith(audioPath: second.path),
      );
      expect(first.existsSync(), isFalse);
      expect(second.existsSync(), isTrue);
      expect((await repo.attempts()).single.audioPath, second.path);
    });

    test('a missing recording file does not fail the save', () async {
      await repo.saveAttempt(
        cannedRiverAttempt.copyWith(audioPath: '${tmp.path}/gone.wav'),
      );
      expect((await repo.attempt(cannedRiverAttempt.id))!.audioPath, isNull);
    });
  });

  group('sound stats', () {
    test('use the shared SoundStat EMA rule, in order', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      final expected = <String, SoundStat>{};
      for (final w in cannedRiverAttempt.words) {
        if (w.status == WordStatus.notScored) continue;
        for (final p in w.phonemes) {
          final s = expected[p.expected];
          expected[p.expected] = s == null
              ? SoundStat.first(p.expected, p.score, cannedRiverAttempt.at)
              : s.update(p.score, cannedRiverAttempt.at);
        }
      }
      final stats = await repo.soundStats();
      expect({for (final s in stats) s.ipa: s}, expected);
    });

    test('not-scored words are skipped', () async {
      const p = PhonemeResult(
        expected: 'x',
        score: 10,
        start: Duration.zero,
        end: Duration(milliseconds: 20),
      );
      await repo.saveAttempt(
        cannedRiverAttempt.copyWith(
          words: const [
            WordResult(
              index: 0,
              text: 'Xyz',
              score: 0,
              phonemes: [p],
              status: WordStatus.notScored,
            ),
          ],
        ),
      );
      expect(await repo.soundStats(), isEmpty);
    });

    test('updateWordResult folds at the clock time', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      now = DateTime(2026, 11, 1, 12);
      final w = cannedRiverAttempt.words[1];
      await repo.updateWordResult(cannedRiverAttempt.id, w);
      final ipa = w.phonemes.first.expected;
      final s = (await repo.soundStats()).singleWhere((s) => s.ipa == ipa);
      expect(s.lastPractised, now);
    });
  });

  group('review queue', () {
    test('a word graduates after the last stage', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      final w = cannedRiverAttempt.words[1];
      await repo.upsertReview(
        ReviewItem.enqueue(word: w.text, now: now).copyWith(
          stage: ReviewItem.intervals.length - 1,
          intervalDays: ReviewItem.intervals.last,
        ),
      );
      await repo.updateWordResult(
        cannedRiverAttempt.id,
        w.copyWith(score: 95, status: WordStatus.good),
      );
      expect(await repo.reviewQueue(), isEmpty);
    });

    test('a newly red word is enqueued with the attempt passage', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      final w = cannedRiverAttempt.words[0];
      await repo.updateWordResult(
        cannedRiverAttempt.id,
        w.copyWith(score: 20, status: WordStatus.fix),
      );
      final item = (await repo.reviewQueue()).single;
      expect(item.key, w.text.toLowerCase());
      expect(item.passageId, cannedRiverAttempt.passageId);
      expect(item.lastScore, 20);
      expect(item.due, ReviewItem.addDays(now, 1));
    });

    test('a good unqueued word is not enqueued', () async {
      await repo.saveAttempt(cannedRiverAttempt);
      await repo.updateWordResult(
        cannedRiverAttempt.id,
        cannedRiverAttempt.words[0].copyWith(
          score: 90,
          status: WordStatus.good,
        ),
      );
      expect(await repo.reviewQueue(), isEmpty);
    });

    test('phonemes, ease and passage round-trip', () async {
      final item = ReviewItem(
        word: 'Bath',
        phonemes: const [
          PhonemeSpec(ipa: 'b'),
          PhonemeSpec(ipa: 'ɑː', stress: 1),
          PhonemeSpec(ipa: 'θ'),
        ],
        due: DateTime.utc(2026, 10, 20, 8),
        intervalDays: 3,
        ease: 2.3,
        stage: 1,
        lastScore: 55,
        passageId: 'p1',
      );
      await repo.upsertReview(item);
      expect(await repo.reviewQueue(), [item]);
      expect(await repo.dueReviews(DateTime.utc(2026, 10, 20, 8)), [item]);
      expect(await repo.dueReviews(DateTime.utc(2026, 10, 20, 7)), isEmpty);
    });
  });

  group('changes', () {
    test('removing an absent review does not emit', () async {
      var count = 0;
      final sub = repo.changes.listen((_) => count++);
      await repo.removeReview('nothing');
      await repo.upsertReview(ReviewItem.enqueue(word: 'a', now: now));
      await repo.removeReview('A');
      await pumpEventQueue();
      expect(count, 2);
      await sub.cancel();
    });
  });

  group('export and import', () {
    test('export is a ProgressBackup stamped by the clock', () async {
      final json = await repo.exportJson();
      final b = ProgressBackup.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(b.exportedAt, now);
      expect(b.profile, const UserProfile());
    });

    test('rejects bad shapes and old-but-invalid versions', () async {
      for (final bad in [
        '{"schemaVersion": 1}',
        '{"schemaVersion": 0, "exportedAt": "2026-10-18T09:00:00.000", '
            '"profile": {}}',
        '"text"',
      ]) {
        await expectLater(repo.importJson(bad), throwsFormatException);
      }
    });

    test('import replaces existing data and keeps audio paths', () async {
      await repo.saveAttempt(cannedRiverAttempt.copyWith(id: 'old'));
      final backup = ProgressBackup(
        exportedAt: now,
        profile: const UserProfile(level: 2, keepRecordings: true),
        attempts: [cannedRiverAttempt.copyWith(audioPath: '/x/y.wav')],
      );
      await repo.importJson(jsonEncode(backup.toJson()));
      expect((await repo.attempts()).map((a) => a.id), [cannedRiverAttempt.id]);
      expect((await repo.attempts()).single.audioPath, '/x/y.wav');
      expect(await repo.soundStats(), isEmpty);
      expect((await repo.profile()).level, 2);
    });
  });

  group('deleteAll', () {
    test('also empties the recordings folder', () async {
      final stray = wav('stray.wav');
      final nested = await Directory('${recDir.path}/old').create();
      File('${nested.path}/x.wav').writeAsBytesSync([1]);
      await repo.deleteAll();
      expect(stray.existsSync(), isFalse);
      expect(recDir.listSync(), isEmpty);
      expect(recDir.existsSync(), isTrue);
    });
  });

  group('RecordingStore', () {
    test(
      'ignores null, empty and missing paths; tolerates no folder',
      () async {
        final store = RecordingStore();
        expect(await store.delete(null), isFalse);
        expect(await store.delete(''), isFalse);
        expect(await store.delete('${tmp.path}/none.wav'), isFalse);
        expect(await store.delete(wav('z.wav').path), isTrue);
        await store.deleteAll(['${tmp.path}/none.wav']);
        await RecordingStore(directory: Directory('${tmp.path}/missing'))
            .deleteAll(const []);
      },
    );

    test('a directory path is not deleted as a file', () async {
      final d = await Directory('${tmp.path}/dir.wav').create();
      expect(await RecordingStore().delete(d.path), isFalse);
      expect(d.existsSync(), isTrue);
    });
  });
}
