import 'package:freezed_annotation/freezed_annotation.dart';

import 'phoneme_spec.dart';

part 'word_spec.freezed.dart';
part 'word_spec.g.dart';

/// One word of a passage (or of custom text) with its expected British phonemes.
@freezed
abstract class WordSpec with _$WordSpec {
  /// - [text]: the word as written, without surrounding punctuation ("Thursday", "don't").
  /// - [index]: 0-based position among the passage's words; equals its list index.
  /// - [phonemes]: expected phonemes in order; empty when [scorable] is false.
  /// - [scorable]: false for words not in the British dictionary (shown grey, not scored).
  /// - [offset]: character offset of [text] inside `Passage.text`, so the UI can colour
  ///   the original text (`Passage.text.substring(offset, offset + text.length) == text`).
  ///   Null for custom text where no source string exists.
  const factory WordSpec({
    required String text,
    required int index,
    @Default(<PhonemeSpec>[]) List<PhonemeSpec> phonemes,
    @Default(true) bool scorable,
    int? offset,
  }) = _WordSpec;

  /// Decodes from JSON.
  factory WordSpec.fromJson(Map<String, dynamic> json) =>
      _$WordSpecFromJson(json);
}
