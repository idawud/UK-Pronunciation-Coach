import 'package:freezed_annotation/freezed_annotation.dart';

import 'phoneme_spec.dart';

part 'minimal_pair.freezed.dart';
part 'minimal_pair.g.dart';

/// A minimal pair from assets/content/minimal_pairs.json (C1), e.g. ship / sheep.
@freezed
abstract class MinimalPair with _$MinimalPair {
  /// - [contrast]: the two phonemes contrasted, e.g. "ɪ-iː" (pairs are grouped by it).
  /// - [wordA], [wordB]: the two words.
  /// - [phonemesA], [phonemesB]: their expected phonemes.
  const factory MinimalPair({
    required String contrast,
    required String wordA,
    required String wordB,
    @Default(<PhonemeSpec>[]) List<PhonemeSpec> phonemesA,
    @Default(<PhonemeSpec>[]) List<PhonemeSpec> phonemesB,
  }) = _MinimalPair;

  /// Decodes from JSON.
  factory MinimalPair.fromJson(Map<String, dynamic> json) =>
      _$MinimalPairFromJson(json);
}
