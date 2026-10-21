import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/data/content/bundled_content_repository.dart';

import '../../contracts/content_repository_contract.dart';

BundledContentRepository fromDisk() =>
    BundledContentRepository.withLoader((path) => File(path).readAsString());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  runContentRepositoryContract(() async => fromDisk());

  group('BundledContentRepository', () {
    test('reads the real assets through the asset bundle', () async {
      final repo = BundledContentRepository();
      expect(await repo.all(), hasLength(120));
      expect((await repo.lookup('think')).single.scorable, isTrue);
      expect(await repo.minimalPairs(), hasLength(greaterThanOrEqualTo(40)));
    });

    test('accepts a custom AssetBundle', () async {
      final repo = BundledContentRepository(bundle: _DiskBundle());
      expect(await repo.placementPassages(), hasLength(3));
    });

    test('caches: each asset is read once', () async {
      final reads = <String>[];
      final repo = BundledContentRepository.withLoader((path) {
        reads.add(path);
        return File(path).readAsString();
      });
      await repo.all();
      await repo.byLevel(2);
      await repo.lookup('one two');
      await repo.lookup('three');
      await repo.minimalPairs();
      await repo.minimalPairs();
      expect(reads, [
        BundledContentRepository.passagesAsset,
        BundledContentRepository.alternativesAsset,
        BundledContentRepository.britfoneAsset,
        BundledContentRepository.pairsAsset,
      ]);
    });

    test('passage words carry their other accepted pronunciations', () async {
      final repo = fromDisk();
      final words = [for (final p in await repo.all()) ...p.words];
      String plain(List<PhonemeSpec> ps) => ps.map((p) => p.ipa).join(' ');
      final from = words.firstWhere((w) => w.text.toLowerCase() == 'from');
      final forms = from.alternatives.map(plain).toList();
      expect(forms, isNotEmpty);
      expect(forms, isNot(contains(plain(from.phonemes))));
      expect([
        plain(from.phonemes),
        ...forms,
      ], containsAll(['f ɹ ɒ m', 'f ɹ ə m']));
      // Every alternative differs from the main form and from each other.
      for (final w in words) {
        final all = [plain(w.phonemes), ...w.alternatives.map(plain)];
        expect(all.toSet(), hasLength(all.length), reason: w.text);
        if (!w.scorable) expect(w.alternatives, isEmpty);
      }
      expect(words.where((w) => w.alternatives.isNotEmpty), isNotEmpty);
    });

    test('lookup adds Britfone variants for custom text', () async {
      final repo = fromDisk();
      final words = await repo.lookup('Thursday from xyzzyq');
      expect(words[0].alternatives, isNotEmpty);
      expect(words[1].alternatives, isNotEmpty);
      expect(words[2].scorable, isFalse);
      expect(words[2].alternatives, isEmpty);
    });

    test('a missing alternatives file just means no alternatives', () async {
      final repo = BundledContentRepository.withLoader((path) async {
        if (path == BundledContentRepository.alternativesAsset) {
          throw StateError('missing');
        }
        return File(path).readAsString();
      });
      final passages = await repo.all();
      expect(passages, hasLength(120));
      expect(
        passages.expand((p) => p.words).every((w) => w.alternatives.isEmpty),
        isTrue,
      );
    });

    test('lookup of text without words does not load the dictionary', () async {
      final reads = <String>[];
      final repo = BundledContentRepository.withLoader((path) async {
        reads.add(path);
        return '';
      });
      expect(await repo.lookup('  ... 42 !'), isEmpty);
      expect(reads, isEmpty);
    });

    test('placement passages are not in the library', () async {
      final repo = fromDisk();
      final ids = (await repo.all()).map((p) => p.id).toSet();
      for (final p in await repo.placementPassages()) {
        expect(ids, isNot(contains(p.id)));
        expect(p.id, startsWith('placement-'));
      }
    });

    test('unknown ids throw', () async {
      await expectLater(
        fromDisk().byId('l9-001'),
        throwsA(isA<PassageNotFoundException>()),
      );
    });

    test('lookup(passage.text) agrees with the built passages', () async {
      // The Python build (tools/content/lexicon.py) and the Dart lexicon implement
      // the same rules. Words the build took from the reviewed overrides file are
      // not in the runtime table, so lookup marks them unscorable.
      final repo = fromDisk();
      final lex = await repo.lexicon();
      var compared = 0;
      for (final p in [
        ...await repo.all(),
        ...await repo.placementPassages(),
      ]) {
        final looked = await repo.lookup(p.text);
        expect(looked.length, p.words.length, reason: p.id);
        for (var i = 0; i < looked.length; i++) {
          final a = looked[i];
          final b = p.words[i];
          expect(a.text, b.text);
          expect(a.offset, b.offset);
          if (a.scorable) {
            expect(a.phonemes, b.phonemes, reason: '${p.id}: ${a.text}');
            compared++;
          } else {
            expect(lex.pronunciations(a.text), isNull);
          }
        }
      }
      expect(compared, greaterThan(10000));
    });
  });
}

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}
