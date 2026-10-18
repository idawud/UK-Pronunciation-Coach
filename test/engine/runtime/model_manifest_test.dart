import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';

final _sha = 'A' * 64;

Map<String, Object?> _entry(
  String name,
  String tier, {
  int size = 10,
  bool? bundle,
}) => {
  'name': name,
  'tier': tier,
  'url': 'https://x.test/$name',
  'sha256': _sha,
  'size': size,
  'bundle': ?bundle,
};

void main() {
  test('parses the fetch_models.py format', () {
    final m = ModelManifest.fromJson(
      jsonEncode({
        'files': [
          _entry('light_model.onnx', 'light', size: 100, bundle: true),
          _entry('light_vocab.json', 'light', size: 5, bundle: true),
          _entry('full/model.onnx', 'full', size: 1000),
          _entry('full/vocab.json', 'full', size: 7),
        ],
      }),
    );
    expect(m.files, hasLength(4));
    final light = m.pairFor(ModelTier.light)!;
    expect(light.model.name, 'light_model.onnx');
    expect(light.model.bundle, isTrue);
    expect(light.vocab.isVocab, isTrue);
    final full = m.pairFor(ModelTier.full)!;
    expect(full.model.basename, 'model.onnx');
    expect(full.model.sha256, 'a' * 64, reason: 'lower-cased');
    expect(full.model.bundle, isFalse);
    expect(m.sizeOf(ModelTier.full), 1007);
    expect(m.sizeOf(ModelTier.light), 105);
  });

  test('missing tiers and empty manifests', () {
    expect(ModelManifest.fromJson('{}').files, isEmpty);
    expect(ModelManifest.empty.pairFor(ModelTier.full), isNull);
    expect(ModelManifest.empty.sizeOf(ModelTier.full), isNull);
    final onlyModel = ModelManifest.fromJson(
      jsonEncode({
        'files': [_entry('m.onnx', 'full')],
      }),
    );
    expect(onlyModel.pairFor(ModelTier.full), isNull);
  });

  test('rejects unknown tiers and bad hashes', () {
    expect(
      () => ModelManifest.fromJson(
        jsonEncode({
          'files': [_entry('m.onnx', 'huge')],
        }),
      ),
      throwsFormatException,
    );
    final bad = _entry('m.onnx', 'full')..['sha256'] = 'xyz';
    expect(
      () => ModelManifest.fromJson(
        jsonEncode({
          'files': [bad],
        }),
      ),
      throwsFormatException,
    );
  });
}
