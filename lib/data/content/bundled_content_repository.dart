import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/contracts/content_repository.dart';
import '../../core/contracts/errors.dart';
import '../../core/models/models.dart';
import 'britfone_lexicon.dart';

/// [ContentRepository] over the content bundle in assets/content/ (built by
/// tools/content/build.py): passages.v1.json, minimal_pairs.json and the Britfone
/// table britfone.v1.tsv. Everything is read once, lazily, and kept in memory.
class BundledContentRepository implements ContentRepository {
  /// Reads the assets from [bundle] (defaults to [rootBundle]).
  BundledContentRepository({AssetBundle? bundle})
    : _load = ((path) => (bundle ?? rootBundle).loadString(path, cache: false));

  /// Uses [load] to read each asset path (tests read the files from disk).
  BundledContentRepository.withLoader(Future<String> Function(String path) load)
    : _load = load;

  /// Asset paths.
  static const passagesAsset = 'assets/content/passages.v1.json';
  static const pairsAsset = 'assets/content/minimal_pairs.json';
  static const britfoneAsset = 'assets/content/britfone.v1.tsv';

  final Future<String> Function(String path) _load;

  Future<_Library>? _library;
  Future<BritfoneLexicon>? _lexicon;
  Future<List<MinimalPair>>? _pairs;

  Future<_Library> get _lib => _library ??= _readLibrary();

  Future<_Library> _readLibrary() async {
    final json = jsonDecode(await _load(passagesAsset)) as Map<String, dynamic>;
    List<Passage> read(String key) => [
      for (final p in json[key] as List<dynamic>)
        Passage.fromJson(p as Map<String, dynamic>),
    ];
    final passages = read('passages')
      ..sort(
        (a, b) => a.level != b.level ? a.level - b.level : a.id.compareTo(b.id),
      );
    final placement = read('placement');
    return _Library(List.unmodifiable(passages), List.unmodifiable(placement), {
      for (final p in [...passages, ...placement]) p.id: p,
    });
  }

  /// The bundled dictionary (loaded on first use).
  Future<BritfoneLexicon> lexicon() async =>
      _lexicon ??= _load(britfoneAsset).then(BritfoneLexicon.parse);

  @override
  Future<List<Passage>> all() async => (await _lib).passages;

  @override
  Future<List<Passage>> byLevel(int level) async =>
      (await _lib).passages.where((p) => p.level == level).toList();

  @override
  Future<Passage> byId(String id) async =>
      (await _lib).byId[id] ?? (throw PassageNotFoundException(id));

  @override
  Future<List<Passage>> placementPassages() async => (await _lib).placement;

  @override
  Future<List<WordSpec>> lookup(String customText) async {
    if (!BritfoneLexicon.wordPattern.hasMatch(customText)) return const [];
    return (await lexicon()).lookup(customText);
  }

  @override
  Future<List<MinimalPair>> minimalPairs() async =>
      _pairs ??= _load(pairsAsset).then((text) {
        final json = jsonDecode(text) as Map<String, dynamic>;
        return List<MinimalPair>.unmodifiable([
          for (final p in json['pairs'] as List<dynamic>)
            MinimalPair.fromJson(p as Map<String, dynamic>),
        ]);
      });
}

class _Library {
  const _Library(this.passages, this.placement, this.byId);

  final List<Passage> passages;
  final List<Passage> placement;
  final Map<String, Passage> byId;
}
