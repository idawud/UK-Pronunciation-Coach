import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'phoneme_result.dart';

part 'word_result.freezed.dart';
part 'word_result.g.dart';

/// Score for one word of an attempt (A3), shown coloured on Results (U3).
@freezed
abstract class WordResult with _$WordResult {
  /// - [index]: matches `WordSpec.index` in the passage.
  /// - [text]: the word as written.
  /// - [score]: 0-100 (0 for [WordStatus.missed] and [WordStatus.notScored]).
  /// - [phonemes]: per-phoneme results in order (empty when not scored or missed).
  /// - [status]: colour band (see [WordStatus]).
  const factory WordResult({
    required int index,
    required String text,
    required int score,
    @Default(<PhonemeResult>[]) List<PhonemeResult> phonemes,
    required WordStatus status,
  }) = _WordResult;

  /// Decodes from JSON.
  factory WordResult.fromJson(Map<String, dynamic> json) =>
      _$WordResultFromJson(json);
}
