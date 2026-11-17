import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/lost_word_repository.dart';

void main() {
  late InMemoryCoachStore store;
  late DateTime now;
  late LostWordRepository repo;

  setUp(() {
    store = InMemoryCoachStore();
    now = DateTime(2026, 10, 19, 9, 30);
    repo = LostWordRepository(store: store, clock: () => now);
  });

  group('add', () {
    test('trims the word and stores the note', () async {
      expect(await repo.add('  scaffold  ', note: ' the frame '), isTrue);
      final words = await repo.list();
      expect(words.single.word, 'scaffold');
      expect(words.single.note, 'the frame');
      expect(words.single.box, 1);
      expect(words.single.due, now);
    });

    test('de-duplicates case-insensitively after trimming', () async {
      expect(await repo.add('Scaffold'), isTrue);
      expect(await repo.add('  scaffold '), isFalse);
      expect(await repo.add('SCAFFOLD', note: 'again'), isFalse);
      expect(await repo.list(), hasLength(1));
    });

    test('ignores empty and whitespace-only words', () async {
      expect(await repo.add(''), isFalse);
      expect(await repo.add('   '), isFalse);
      expect(await repo.list(), isEmpty);
    });

    test('an empty or blank note is stored as null', () async {
      await repo.add('quay', note: '   ');
      expect((await repo.list()).single.note, isNull);
    });

    test('concurrent adds are all kept', () async {
      final results = await Future.wait([
        for (final w in ['a', 'b', 'c', 'd', 'e']) repo.add(w),
      ]);
      expect(results, everyElement(isTrue));
      expect(await repo.list(), hasLength(5));
    });
  });

  test('a new repository over the same store reads the same bank', () async {
    await repo.add('scaffold', note: 'the frame');
    now = now.add(const Duration(minutes: 1));
    await repo.add('quay');
    final reopened = LostWordRepository(store: store, clock: () => now);
    final words = await reopened.list();
    expect(words.map((w) => w.word), ['quay', 'scaffold']);
    expect(words.last.note, 'the frame');
    expect(words.last.addedAt, now.subtract(const Duration(minutes: 1)));
  });

  test('list is newest first', () async {
    await repo.add('first');
    now = now.add(const Duration(minutes: 5));
    await repo.add('second');
    expect((await repo.list()).map((w) => w.word), ['second', 'first']);
  });

  group('dueNow', () {
    test('filters by the clock and sorts most overdue first', () async {
      await repo.add('alpha');
      now = now.add(const Duration(minutes: 1));
      await repo.add('beta');
      await repo.review('beta', recalled: true); // due tomorrow

      final dueNow = await repo.dueNow();
      expect(dueNow.map((w) => w.word), ['alpha']);

      now = DateTime(2026, 10, 20, 9, 29);
      expect((await repo.dueNow()).map((w) => w.word), ['alpha']);

      now = DateTime(2026, 10, 20, 9, 31);
      expect((await repo.dueNow()).map((w) => w.word), ['alpha', 'beta']);
    });
  });

  group('review', () {
    test('saves the Leitner result and returns it', () async {
      await repo.add('scaffold');
      final updated = await repo.review('Scaffold', recalled: true);
      expect(updated?.box, 2);
      expect(updated?.due, now.add(const Duration(days: 1)));
      final stored = (await repo.list()).single;
      expect(stored.box, 2);
      expect(stored.due, now.add(const Duration(days: 1)));
    });

    test('a miss resets the box and counts a lapse', () async {
      await repo.add('scaffold');
      await repo.review('scaffold', recalled: true);
      final missed = await repo.review('scaffold', recalled: false);
      expect(missed?.box, 1);
      expect(missed?.lapses, 1);
      expect(missed?.due, now);
    });

    test('an unknown word returns null and changes nothing', () async {
      await repo.add('scaffold');
      expect(await repo.review('quay', recalled: true), isNull);
      expect(await repo.list(), hasLength(1));
    });
  });

  test('remove deletes a word, case-insensitively', () async {
    await repo.add('scaffold');
    expect(await repo.remove('SCAFFOLD'), isTrue);
    expect(await repo.remove('scaffold'), isFalse);
    expect(await repo.list(), isEmpty);
  });

  test('malformed entries in the store are skipped', () async {
    await store.write(lostWordsKey, {
      'version': 1,
      'words': [
        {'word': 42},
        'not a map',
        {
          'word': 'quay',
          'addedAt': now.toUtc().toIso8601String(),
          'due': now.toUtc().toIso8601String(),
          'box': 1,
          'lapses': 0,
        },
      ],
    });
    expect((await repo.list()).map((w) => w.word), ['quay']);
  });

  test('a corrupt bank reads as empty and the next add replaces it', () async {
    await store.write(lostWordsKey, {'words': 'nonsense'});
    expect(await repo.list(), isEmpty);
    expect(await repo.add('quay'), isTrue);
    expect((await repo.list()).single.word, 'quay');
  });
}
