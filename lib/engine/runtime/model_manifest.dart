import 'dart:convert';

import '../../core/models/enums.dart';

/// Asset key of the model manifest (format documented in `tools/ci/fetch_models.py`).
const String modelManifestAsset = 'assets/models/manifest.json';

/// One file in `assets/models/manifest.json`.
class ModelFileEntry {
  /// Creates an entry.
  const ModelFileEntry({
    required this.name,
    required this.tier,
    required this.url,
    required this.sha256,
    required this.size,
    this.bundle = false,
  });

  /// Parses one `files[]` object.
  factory ModelFileEntry.fromJson(Map<String, dynamic> json) {
    final tierName = json['tier'];
    final tier = ModelTier.values.where((t) => t.name == tierName).firstOrNull;
    if (tier == null) throw FormatException('Unknown tier "$tierName"');
    final sha = (json['sha256'] as String).toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw FormatException('Bad sha256 for ${json['name']}');
    }
    return ModelFileEntry(
      name: json['name'] as String,
      tier: tier,
      url: json['url'] as String,
      sha256: sha,
      size: (json['size'] as num).toInt(),
      bundle: json['bundle'] as bool? ?? false,
    );
  }

  /// Path relative to `assets/models/` (bundled) or to the download folder, e.g.
  /// `light_model.onnx` or `full/vocab.json`.
  final String name;

  /// Tier the file belongs to.
  final ModelTier tier;

  /// Download URL (GitHub Release asset).
  final String url;

  /// Lower-case hex SHA-256.
  final String sha256;

  /// Size in bytes.
  final int size;

  /// True when the file ships inside the app (the light tier).
  final bool bundle;

  /// File name without folders.
  String get basename => name.split('/').last;

  /// True for the ONNX model file (as opposed to `vocab.json`).
  bool get isModel => basename.endsWith('.onnx');

  /// True for the vocab file.
  bool get isVocab => basename.endsWith('.json');
}

/// The parsed model manifest.
class ModelManifest {
  /// Creates a manifest from [files].
  ModelManifest(List<ModelFileEntry> files) : files = List.unmodifiable(files);

  /// Parses manifest JSON text.
  factory ModelManifest.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final files = (json['files'] as List<dynamic>? ?? const [])
        .map((e) => ModelFileEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return ModelManifest(files);
  }

  /// A manifest with no files (before A4 publishes the models).
  static final empty = ModelManifest(const []);

  /// Every listed file.
  final List<ModelFileEntry> files;

  /// Files of [tier].
  List<ModelFileEntry> filesFor(ModelTier tier) =>
      files.where((f) => f.tier == tier).toList();

  /// The model and vocab entry for [tier], or null if either is missing.
  ({ModelFileEntry model, ModelFileEntry vocab})? pairFor(ModelTier tier) {
    final list = filesFor(tier);
    final model = list.where((f) => f.isModel).firstOrNull;
    final vocab = list.where((f) => f.isVocab).firstOrNull;
    if (model == null || vocab == null) return null;
    return (model: model, vocab: vocab);
  }

  /// Total bytes of [tier]'s files, or null when the tier is not listed.
  int? sizeOf(ModelTier tier) {
    final pair = pairFor(tier);
    return pair == null ? null : pair.model.size + pair.vocab.size;
  }
}
