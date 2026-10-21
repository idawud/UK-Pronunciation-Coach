import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/contracts/content_repository.dart';
import '../../core/contracts/errors.dart';
import '../../core/models/models.dart';
import 'britfone_lexicon.dart';

/// [ContentRepository] over the content bundle in assets/content/ (built by
/// tools/content/build.py): passages.v1.json, minimal_pairs.json and the Britfone
/// table britfone.v1.tsv. Everything is read once, lazily, and kept in memory.
///
/// Words get their other accepted pronunciations ([WordSpec.alternatives]) from
/// alternatives.v1.json (passage words: Britfone variants, weak forms, pre-vowel
/// forms, extra forms and the "-day" / "ex-" rules) and, for custom text, also from
/// every Britfone variant of the word.
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
  static const alternativesAsset = 'assets/content/alternatives.v1.json';

  final Future<String> Function(String path) _load;

  Future<_Library>? _library;
  Future<BritfoneLexicon>? _lexicon;
  Future<List<MinimalPair>>? _pairs;
  Future<Map<String, List<String>>>? _alternatives;

  /// Word (lookup key) -> accepted pronunciations, preferred first. Empty when the
  /// asset is missing or unreadable: alternatives are a refinement, not required.
  Future<Map<String, List<String>>> _alts() => _alternatives ??= () async {
    try {
      final json =
          jsonDecode(await _load(alternativesAsset)) as Map<String, dynamic>;
      return {
        for (final e in (json['alternatives'] as Map<String, dynamic>).entries)
          e.key: [for (final p in e.value as List<dynamic>) p as String],
      };
    } on Object {
      return const <String, List<String>>{};
    }
  }();

  /// [word] with every pronunciation in [prons] that differs from its own phonemes
  /// (ignoring stress) as an alternative.
  static WordSpec _withAlternatives(WordSpec word, Iterable<String> prons) {
    if (!word.scorable) return word;
    String plain(List<PhonemeSpec> ps) => ps.map((p) => p.ipa).join(' ');
    final seen = {plain(word.phonemes)};
    final alternatives = <List<PhonemeSpec>>[];
    for (final pron in prons) {
      final phonemes = BritfoneLexicon.toPhonemes(pron);
      if (phonemes.isNotEmpty && seen.add(plain(phonemes))) {
        alternatives.add(phonemes);
      }
    }
    return alternatives.isEmpty
        ? word
        : word.copyWith(alternatives: List.unmodifiable(alternatives));
  }

  Future<_Library> get _lib => _library ??= _readLibrary();

  Future<_Library> _readLibrary() async {
    final json = jsonDecode(await _load(passagesAsset)) as Map<String, dynamic>;
    final alts = await _alts();
    Passage withAlternatives(Passage p) => p.copyWith(
      words: [
        for (final w in p.words)
          _withAlternatives(w, alts[BritfoneLexicon.key(w.text)] ?? const []),
      ],
    );
    List<Passage> read(String key) => [
      for (final p in json[key] as List<dynamic>)
        withAlternatives(Passage.fromJson(p as Map<String, dynamic>)),
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
    final lexicon = await this.lexicon();
    final alts = await _alts();
    return [
      for (final w in lexicon.lookup(customText))
        _withAlternatives(w, [
          ...?alts[BritfoneLexicon.key(w.text)],
          ...?lexicon.pronunciations(w.text),
        ]),
    ];
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
