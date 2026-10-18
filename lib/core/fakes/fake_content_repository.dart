import '../contracts/content_repository.dart';
import '../contracts/errors.dart';
import '../models/models.dart';
import 'sample_data.dart';

/// In-memory [ContentRepository] over the sample passages (or [passages]).
class FakeContentRepository implements ContentRepository {
  /// Creates the fake. [passages] defaults to `samplePassages` (levels 1, 3, 5), which
  /// also serve as the placement set.
  FakeContentRepository({
    List<Passage>? passages,
    List<Passage>? placement,
    Map<String, List<PhonemeSpec>>? lexicon,
  }) : _passages = List.unmodifiable(
         <Passage>[...(passages ?? samplePassages)]..sort(
           (a, b) => a.level != b.level
               ? a.level.compareTo(b.level)
               : a.id.compareTo(b.id),
         ),
       ),
       _placement = placement ?? samplePassages,
       _lexicon = lexicon ?? _buildLexicon(passages ?? samplePassages);

  final List<Passage> _passages;
  final List<Passage> _placement;
  final Map<String, List<PhonemeSpec>> _lexicon;

  static Map<String, List<PhonemeSpec>> _buildLexicon(List<Passage> passages) {
    final lex = <String, List<PhonemeSpec>>{...sampleExtraLexicon};
    for (final p in passages) {
      for (final w in p.words) {
        if (w.scorable) lex.putIfAbsent(w.text.toLowerCase(), () => w.phonemes);
      }
    }
    return lex;
  }

  @override
  Future<List<Passage>> all() async => _passages;

  @override
  Future<List<Passage>> byLevel(int level) async =>
      _passages.where((p) => p.level == level).toList();

  @override
  Future<Passage> byId(String id) async {
    for (final p in [..._passages, ..._placement]) {
      if (p.id == id) return p;
    }
    throw PassageNotFoundException(id);
  }

  @override
  Future<List<Passage>> placementPassages() async => _placement;

  @override
  Future<List<WordSpec>> lookup(String customText) async {
    final out = <WordSpec>[];
    for (final m in wordPattern.allMatches(customText)) {
      final text = m.group(0)!;
      final phonemes = _lexicon[text.toLowerCase()];
      out.add(
        WordSpec(
          text: text,
          index: out.length,
          offset: m.start,
          phonemes: phonemes ?? const [],
          scorable: phonemes != null,
        ),
      );
    }
    return out;
  }

  @override
  Future<List<MinimalPair>> minimalPairs() async =>
      [...sampleMinimalPairs]..sort((a, b) => a.contrast.compareTo(b.contrast));
}
