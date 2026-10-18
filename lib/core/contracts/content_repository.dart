import '../models/minimal_pair.dart';
import '../models/passage.dart';
import '../models/word_spec.dart';

/// Read-only access to the bundled passages and the British dictionary (C1).
abstract interface class ContentRepository {
  /// All library passages, ordered by level then id.
  Future<List<Passage>> all();

  /// Library passages at [level] (1-6), ordered by id. Empty for other levels.
  Future<List<Passage>> byLevel(int level);

  /// The passage with [id], including placement passages.
  /// Throws [PassageNotFoundException] when unknown.
  Future<Passage> byId(String id);

  /// The 3 placement passages (levels 1, 3 and 5), in that order.
  Future<List<Passage>> placementPassages();

  /// Splits [customText] into words and looks each up in the bundled Britfone table.
  /// Returns one [WordSpec] per word, indexed from 0, with `offset` into [customText].
  /// Words not in the dictionary get `scorable: false` and no phonemes. Never uses the
  /// network or eSpeak. Empty text gives an empty list.
  Future<List<WordSpec>> lookup(String customText);

  /// Minimal pairs from assets/content/minimal_pairs.json, grouped (ordered) by contrast.
  Future<List<MinimalPair>> minimalPairs();
}
