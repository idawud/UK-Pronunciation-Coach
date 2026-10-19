import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_files.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';

import 'helpers/fakes.dart';

/// Asset bundle over an in-memory map; counts loads.
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.assets);

  final Map<String, Uint8List> assets;
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('a2_files'));
  tearDown(() => tmp.delete(recursive: true));

  final model = Uint8List.fromList(List.generate(300, (i) => i & 0xff));
  final vocab = Uint8List.fromList(utf8.encode('{"<pad>": 0, "a": 1}'));
  final m = entryFor(
    'light/model.onnx',
    model,
    tier: ModelTier.light,
    bundle: true,
  );
  final v = entryFor(
    'light/vocab.json',
    vocab,
    tier: ModelTier.light,
    bundle: true,
  );

  test('DirectoryLightModel resolves only existing files', () async {
    expect(await tinyLight.resolve(), isNotNull);
    const missing = DirectoryLightModel(ModelFiles('/nope.onnx', '/nope.json'));
    expect(await missing.resolve(), isNull);
  });

  test('BundledLightModel copies assets once and reuses them', () async {
    final bundle = _MapBundle({
      'assets/models/${m.name}': model,
      'assets/models/${v.name}': vocab,
    });
    final dir = Directory('${tmp.path}/light');
    BundledLightModel make() => BundledLightModel(
      bundle: bundle,
      manifest: ModelManifest([m, v]),
      dir: dir,
    );
    final files = await make().resolve();
    expect(files, isNotNull);
    expect(File(files!.modelPath).readAsBytesSync(), model);
    expect(File(files.vocabPath).readAsBytesSync(), vocab);
    expect(bundle.loads, 2);

    final again = make();
    expect((await again.resolve())!.modelPath, files.modelPath);
    expect(await again.resolve(), isNotNull); // memoised
    expect(bundle.loads, 2, reason: 'same size on disk: no re-copy');
  });

  test('BundledLightModel is null without a bundled light tier', () async {
    final dir = Directory('${tmp.path}/light');
    final empty = _MapBundle({});
    expect(
      await BundledLightModel(
        bundle: empty,
        manifest: ModelManifest.empty,
        dir: dir,
      ).resolve(),
      isNull,
    );
    final notBundled = entryFor(
      'light/model.onnx',
      model,
      tier: ModelTier.light,
    );
    expect(
      await BundledLightModel(
        bundle: empty,
        manifest: ModelManifest([notBundled, v]),
        dir: dir,
      ).resolve(),
      isNull,
    );
    // Listed but missing from this build: null, and retried on the next call.
    final source = BundledLightModel(
      bundle: empty,
      manifest: ModelManifest([m, v]),
      dir: dir,
    );
    expect(await source.resolve(), isNull);
    empty.assets['assets/models/${m.name}'] = model;
    empty.assets['assets/models/${v.name}'] = vocab;
    expect(await source.resolve(), isNotNull);
  });

  test('loadBundledManifest parses the asset or returns empty', () async {
    final json = jsonEncode({
      'files': [
        {
          'name': m.name,
          'tier': 'light',
          'url': m.url,
          'sha256': m.sha256,
          'size': m.size,
          'bundle': true,
        },
      ],
    });
    final bundle = _MapBundle({
      modelManifestAsset: Uint8List.fromList(utf8.encode(json)),
    });
    expect((await loadBundledManifest(bundle)).files.single.name, m.name);
    expect((await loadBundledManifest(_MapBundle({}))).files, isEmpty);
  });
}
