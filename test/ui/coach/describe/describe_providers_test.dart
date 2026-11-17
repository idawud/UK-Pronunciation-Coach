import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/describe/describe_content.dart';
import 'package:uk_pronunciation_coach/ui/coach/describe/describe_providers.dart';

const _prompts = [
  CircumlocutionPrompt(
    id: 'a',
    target: 'alpha',
    hints: ['one', 'two', 'three'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'b',
    target: 'bravo',
    hints: ['one', 'two', 'three'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'c',
    target: 'charlie',
    hints: ['one', 'two', 'three'],
    category: DescribeCategory.action,
  ),
];

DescribeRepository _repo(CoachStore store, DateTime now) =>
    DescribeRepository(store, () => now);

void main() {
  group('pickPrompt', () {
    test('never returns a done prompt', () {
      final random = Random(7);
      for (var i = 0; i < 200; i++) {
        final p = pickPrompt(
          prompts: _prompts,
          doneIds: {'a', 'b'},
          random: random,
        );
        expect(p?.id, 'c');
      }
    });

    test('resets to every prompt when all are done', () {
      final seen = <String>{};
      final random = Random(3);
      for (var i = 0; i < 200; i++) {
        final p = pickPrompt(
          prompts: _prompts,
          doneIds: {'a', 'b', 'c'},
          random: random,
        );
        expect(p, isNotNull);
        seen.add(p!.id);
      }
      expect(seen, {'a', 'b', 'c'});
    });

    test('avoids the excluded prompt when another choice exists', () {
      final random = Random(1);
      for (var i = 0; i < 100; i++) {
        final p = pickPrompt(
          prompts: _prompts,
          doneIds: {'b'},
          exclude: 'a',
          random: random,
        );
        expect(p?.id, 'c');
      }
    });

    test('may repeat the excluded prompt when it is the only one left', () {
      final p = pickPrompt(
        prompts: _prompts,
        doneIds: {'a', 'b'},
        exclude: 'c',
        random: Random(0),
      );
      expect(p?.id, 'c');
    });

    test('an empty list gives null', () {
      expect(pickPrompt(prompts: const [], doneIds: const {}), isNull);
    });
  });

  group('DescribeRepository', () {
    test('markDone saves the id and today, and round-trips', () async {
      final store = InMemoryCoachStore();
      final now = DateTime(2026, 11, 17, 9, 30);
      final state = await _repo(store, now).markDone('stapler');
      expect(state.doneIds, {'stapler'});
      expect(state.lastDay, '2026-11-17');

      // A fresh repository over the same store sees the saved progress.
      final reloaded = await _repo(store, now).loadCirc();
      expect(reloaded.doneIds, {'stapler'});
      expect(reloaded.lastDay, '2026-11-17');
    });

    test('marking the last prompt resets the round', () async {
      final store = InMemoryCoachStore();
      final repo = _repo(store, DateTime(2026, 11, 17));
      CircState? last;
      for (final p in circumlocutionPrompts) {
        last = await repo.markDone(p.id);
      }
      expect(last!.doneIds, isEmpty);
      expect((await repo.loadCirc()).doneIds, isEmpty);
    });

    test('malformed stored data reads as an empty round', () async {
      final store = InMemoryCoachStore();
      await store.write(describeCircKey, {'doneIds': 'oops'});
      await store.write(describeChunksKey, {'counts': 4});
      final repo = _repo(store, DateTime(2026, 11, 17));
      expect((await repo.loadCirc()).doneIds, isEmpty);
      expect(await repo.loadCounts(), isEmpty);
    });

    test('practise increments a phrase count and persists it', () async {
      final store = InMemoryCoachStore();
      final repo = _repo(store, DateTime(2026, 11, 17));
      expect(await repo.practise('to-be-honest'), {'to-be-honest': 1});
      expect(await repo.practise('to-be-honest'), {'to-be-honest': 2});
      expect(await repo.practise('arguably'), {
        'to-be-honest': 2,
        'arguably': 1,
      });

      final reloaded = await _repo(store, DateTime(2026, 11, 17)).loadCounts();
      expect(reloaded, {'to-be-honest': 2, 'arguably': 1});
      expect(await store.read(describeChunksKey), {
        'counts': {'to-be-honest': 2, 'arguably': 1},
      });
    });
  });

  test('mostPractised lists the top counts above zero', () {
    final top = mostPractised(
      const {'to-be-honest': 5, 'arguably': 9, 'probably': 0},
      chunks: const [
        PhraseChunk(
          id: 'to-be-honest',
          text: 'To be honest',
          category: PhraseCategory.hedging,
        ),
        PhraseChunk(
          id: 'arguably',
          text: 'Arguably',
          category: PhraseCategory.hedging,
        ),
        PhraseChunk(
          id: 'probably',
          text: 'Probably',
          category: PhraseCategory.hedging,
        ),
      ],
    );
    expect(top.map((c) => c.id), ['arguably', 'to-be-honest']);
  });
}
