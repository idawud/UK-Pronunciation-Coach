import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/models/enums.dart';
import 'model_manifest.dart';

/// Paths of one tier's installed model and vocab.
class ModelFiles {
  /// Creates the pair.
  const ModelFiles(this.modelPath, this.vocabPath);

  /// The `.onnx` file.
  final String modelPath;

  /// The `vocab.json` file.
  final String vocabPath;
}

/// Where the light (bundled) tier comes from.
abstract interface class LightModelSource {
  /// The installed files, or null when the app has no light model (e.g. a dev build
  /// before A4's files were fetched).
  Future<ModelFiles?> resolve();
}

/// Light model files already on disk (development and tests).
class DirectoryLightModel implements LightModelSource {
  /// Uses [files] as they are.
  const DirectoryLightModel(this.files);

  /// The files.
  final ModelFiles files;

  @override
  Future<ModelFiles?> resolve() async =>
      File(files.modelPath).existsSync() && File(files.vocabPath).existsSync()
      ? files
      : null;
}

/// Light model bundled as Flutter assets (`assets/models/<name>`, the manifest's
/// `tier: light, bundle: true` entries). ONNX Runtime needs a file path, so the
/// assets are copied once into [dir] (app support storage) and re-copied only when
/// the size differs from the manifest (i.e. after an app update changed the model).
class BundledLightModel implements LightModelSource {
  /// Creates the source.
  BundledLightModel({
    required this._bundle,
    required this._manifest,
    required this.dir,
  });

  final AssetBundle _bundle;
  final ModelManifest _manifest;

  /// Install folder.
  final Directory dir;

  Future<ModelFiles?>? _resolved;

  @override
  Future<ModelFiles?> resolve() => _resolved ??= _install().then((files) {
    if (files == null) _resolved = null; // allow a retry
    return files;
  });

  Future<ModelFiles?> _install() async {
    final pair = _manifest.pairFor(ModelTier.light);
    if (pair == null || !pair.model.bundle || !pair.vocab.bundle) return null;
    final model = await _copy(pair.model);
    final vocab = await _copy(pair.vocab);
    if (model == null || vocab == null) return null;
    return ModelFiles(model, vocab);
  }

  Future<String?> _copy(ModelFileEntry entry) async {
    final target = File('${dir.path}/${entry.basename}');
    if (target.existsSync() && target.lengthSync() == entry.size) {
      return target.path;
    }
    final ByteData data;
    try {
      data = await _bundle.load('assets/models/${entry.name}');
    } on FlutterError {
      return null; // not bundled in this build
    }
    await dir.create(recursive: true);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await tmp.rename(target.path);
    return target.path;
  }
}

/// Loads `assets/models/manifest.json` from [bundle], or [ModelManifest.empty] when
/// the build has none.
Future<ModelManifest> loadBundledManifest(AssetBundle bundle) async {
  try {
    return ModelManifest.fromJson(
      await bundle.loadString(modelManifestAsset, cache: false),
    );
  } on FlutterError {
    return ModelManifest.empty;
  }
}
