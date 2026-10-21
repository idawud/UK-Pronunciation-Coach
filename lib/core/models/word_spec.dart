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
  /// - [alternatives]: other accepted British pronunciations of the word (weak and
  ///   strong forms, dictionary variants, "-day" as /deɪ/, "ex-" as /ɛk/ ...), not
  ///   including [phonemes]. The scorer scores the word against [phonemes] and every
  ///   alternative and keeps the best match. Empty when the word has only one.
  const factory WordSpec({
    required String text,
    required int index,
    @Default(<PhonemeSpec>[]) List<PhonemeSpec> phonemes,
    @Default(true) bool scorable,
    int? offset,
    @Default(<List<PhonemeSpec>>[]) List<List<PhonemeSpec>> alternatives,
  }) = _WordSpec;

  /// Decodes from JSON.
  factory WordSpec.fromJson(Map<String, dynamic> json) =>
      _$WordSpecFromJson(json);
}
