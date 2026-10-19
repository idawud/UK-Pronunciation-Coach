import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/data/content/britfone_lexicon.dart';
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
        BundledContentRepository.britfoneAsset,
        BundledContentRepository.pairsAsset,
      ]);
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
