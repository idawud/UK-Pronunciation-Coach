import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

/// Shared behaviour every [ContentRepository] must have.
///
/// [fullLibrary] also checks the launch library: 20 passages at each of levels 1-6
/// (C1's real repository must pass it; the fake has 3 sample passages).
void runContentRepositoryContract(
  Future<ContentRepository> Function() create, {
  bool fullLibrary = true,
}) {
  group('ContentRepository contract', () {
    late ContentRepository repo;
    setUp(() async => repo = await create());

    void checkPassage(Passage p) {
      expect(p.id, isNotEmpty);
      expect(p.level, inInclusiveRange(1, 6));
      expect(p.title, isNotEmpty);
      expect(p.words, isNotEmpty, reason: p.id);
      for (var i = 0; i < p.words.length; i++) {
        final w = p.words[i];
        expect(w.index, i, reason: '${p.id} word $i');
        expect(w.text, isNotEmpty);
        if (w.scorable) {
          expect(w.phonemes, isNotEmpty, reason: '${p.id}: ${w.text}');
        }
        for (final ph in w.phonemes) {
          expect(ph.ipa, isNotEmpty);
          expect(ph.ipa, isNot(contains('ˈ')));
          expect(ph.stress, inInclusiveRange(0, 2));
        }
        final o = w.offset;
        if (o != null) {
          expect(
            p.text.substring(o, o + w.text.length),
            w.text,
            reason: '${p.id}: offset of ${w.text}',
          );
        }
      }
    }

    test('every passage is well formed, ids unique, ordered', () async {
      final all = await repo.all();
      expect(all, isNotEmpty);
      all.forEach(checkPassage);
      expect(all.map((p) => p.id).toSet().length, all.length);
      for (var i = 1; i < all.length; i++) {
        final a = all[i - 1];
        final b = all[i];
        expect(
          a.level < b.level || (a.level == b.level && a.id.compareTo(b.id) < 0),
          isTrue,
          reason: 'ordered by level then id: ${a.id}, ${b.id}',
        );
      }
    });

    if (fullLibrary) {
      test('20 passages per level 1-6', () async {
        for (var level = 1; level <= 6; level++) {
          expect((await repo.byLevel(level)).length, 20, reason: 'L$level');
        }
      });
    }

    test('byLevel filters all()', () async {
      final all = await repo.all();
      for (var level = 0; level <= 7; level++) {
        expect(
          (await repo.byLevel(level)).map((p) => p.id),
          all.where((p) => p.level == level).map((p) => p.id),
        );
      }
    });

    test('byId finds every passage and rejects unknown ids', () async {
      for (final p in await repo.all()) {
        expect(await repo.byId(p.id), p);
      }
      await expectLater(
        repo.byId('no-such-passage'),
        throwsA(isA<PassageNotFoundException>()),
      );
    });

    test('placement passages are levels 1, 3, 5 and resolvable', () async {
      final placement = await repo.placementPassages();
      expect(placement.map((p) => p.level), [1, 3, 5]);
      for (final p in placement) {
        checkPassage(p);
        expect(await repo.byId(p.id), p);
      }
    });

    test('lookup splits words, finds known ones, flags unknown', () async {
      expect(await repo.lookup(''), isEmpty);
      final words = await repo.lookup('Hello, world! zzqxv');
      expect(words.map((w) => w.text), ['Hello', 'world', 'zzqxv']);
      expect(words.map((w) => w.index), [0, 1, 2]);
      expect(words.map((w) => w.offset), [0, 7, 14]);
      expect(words[0].scorable, isTrue);
      expect(words[0].phonemes, isNotEmpty);
      expect(words[1].scorable, isTrue);
      expect(words[2].scorable, isFalse);
      expect(words[2].phonemes, isEmpty);
    });

    test('minimal pairs are grouped by contrast', () async {
      final pairs = await repo.minimalPairs();
      expect(pairs, isNotEmpty);
      for (var i = 0; i < pairs.length; i++) {
        final p = pairs[i];
        expect(p.contrast, isNotEmpty);
        expect(p.wordA, isNot(p.wordB));
        expect(p.phonemesA, isNotEmpty);
        expect(p.phonemesB, isNotEmpty);
        if (i > 0 && pairs[i - 1].contrast != p.contrast) {
          expect(
            pairs.take(i - 1).map((e) => e.contrast),
            isNot(contains(p.contrast)),
            reason: 'pairs with the same contrast are adjacent',
          );
        }
      }
    });
  });
}
