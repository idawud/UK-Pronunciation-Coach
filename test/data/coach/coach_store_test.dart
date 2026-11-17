import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('coach_store_test');
    file = File('${dir.path}${Platform.pathSeparator}coach_store.json');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  JsonFileCoachStore fileStore() =>
      JsonFileCoachStore(directoryProvider: () async => dir);

  group('JsonFileCoachStore', () {
    test('a fresh store reads null for every key', () async {
      expect(await fileStore().read('confusions'), isNull);
      expect(file.existsSync(), isFalse);
    });

    test(
      'round-trips a value and writes version 1 with the data key',
      () async {
        final store = fileStore();
        await store.write('confusions', {
          'ship': 3,
          'nested': {
            'ok': true,
            'list': [1, 2],
          },
        });
        expect(await store.read('confusions'), {
          'ship': 3,
          'nested': {
            'ok': true,
            'list': [1, 2],
          },
        });
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(json['version'], 1);
        expect(json['data'], isA<Map<String, Object?>>());
      },
    );

    test('a new instance over the same folder sees the saved data', () async {
      await fileStore().write('lostWords', {'bath': 1});
      expect(await fileStore().read('lostWords'), {'bath': 1});
    });

    test('keys are independent', () async {
      final store = fileStore();
      await store.write('confusions', {'a': 1});
      await store.write('lostWords', {'b': 2});
      expect(await store.read('confusions'), {'a': 1});
      expect(await store.read('lostWords'), {'b': 2});
      expect(await store.read('chunks'), isNull);

      await store.write('confusions', {'a': 9});
      expect(await store.read('lostWords'), {'b': 2});
    });

    test('concurrent writes to different keys keep both', () async {
      final store = fileStore();
      await Future.wait([
        store.write('confusions', {'a': 1}),
        store.write('shadow', {'b': 2}),
        store.write('circ', {'c': 3}),
      ]);
      expect(await store.read('confusions'), {'a': 1});
      expect(await store.read('shadow'), {'b': 2});
      expect(await store.read('circ'), {'c': 3});
    });

    test('clear removes every key and the file', () async {
      final store = fileStore();
      await store.write('confusions', {'a': 1});
      await store.write('chunks', {'b': 2});
      await store.clear();
      expect(await store.read('confusions'), isNull);
      expect(await store.read('chunks'), isNull);
      expect(file.existsSync(), isFalse);
    });

    test('clear on an empty store does nothing', () async {
      await fileStore().clear();
      expect(file.existsSync(), isFalse);
    });

    test('a corrupt file reads as empty and the next write recovers', () async {
      file.writeAsStringSync('{not json');
      final store = fileStore();
      expect(await store.read('confusions'), isNull);

      await store.write('confusions', {'a': 1});
      expect(await store.read('confusions'), {'a': 1});
      expect((jsonDecode(file.readAsStringSync()) as Map)['version'], 1);
    });

    test('a file with the wrong top-level shape reads as empty', () async {
      file.writeAsStringSync('[1, 2, 3]');
      expect(await fileStore().read('confusions'), isNull);
    });

    test('an unknown version reads as empty', () async {
      file.writeAsStringSync(
        jsonEncode({
          'version': 2,
          'data': {
            'confusions': {'a': 1},
          },
        }),
      );
      expect(await fileStore().read('confusions'), isNull);
    });

    test('a write leaves no temporary file behind', () async {
      await fileStore().write('confusions', {'a': 1});
      final names = dir.listSync().map((e) => e.uri.pathSegments.last).toList();
      expect(names, ['coach_store.json']);
    });

    test('rejects values that are not JSON-encodable', () async {
      await expectLater(
        () async => fileStore().write('confusions', {'when': DateTime(2026)}),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });
  });

  group('InMemoryCoachStore', () {
    test('a fresh store reads null', () async {
      expect(await InMemoryCoachStore().read('confusions'), isNull);
    });

    test('round-trips and keeps keys independent', () async {
      final store = InMemoryCoachStore();
      await store.write('confusions', {'a': 1});
      await store.write('lostWords', {'b': 2});
      expect(await store.read('confusions'), {'a': 1});
      expect(await store.read('lostWords'), {'b': 2});
      await store.write('confusions', {'a': 5});
      expect(await store.read('lostWords'), {'b': 2});
    });

    test('returns copies, so callers cannot change the stored value', () async {
      final store = InMemoryCoachStore();
      await store.write('confusions', {'a': 1});
      final read = await store.read('confusions');
      read!['a'] = 99;
      expect(await store.read('confusions'), {'a': 1});
    });

    test('clear removes every key', () async {
      final store = InMemoryCoachStore();
      await store.write('confusions', {'a': 1});
      await store.write('chunks', {'b': 2});
      await store.clear();
      expect(await store.read('confusions'), isNull);
      expect(await store.read('chunks'), isNull);
    });

    test('rejects values that are not JSON-encodable', () async {
      await expectLater(
        () async =>
            InMemoryCoachStore().write('confusions', {'when': DateTime(2026)}),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });
  });
}
