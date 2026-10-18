import 'package:freezed_annotation/freezed_annotation.dart';

import 'word_spec.dart';

part 'passage.freezed.dart';
part 'passage.g.dart';

/// A reading passage from the content bundle (assets/content/passages.v1.json).
@freezed
abstract class Passage with _$Passage {
  const Passage._();

  /// - [id]: stable unique id, e.g. "l3-012".
  /// - [level]: difficulty 1-6 (see docs/SPEC.md level table).
  /// - [title]: short display title.
  /// - [text]: the full passage text exactly as displayed.
  /// - [words]: every word in reading order with expected phonemes.
  /// - [soundTags]: IPA phonemes (or feature tags such as "weak-forms") it practises.
  const factory Passage({
    required String id,
    required int level,
    required String title,
    required String text,
    required List<WordSpec> words,
    @Default(<String>[]) List<String> soundTags,
  }) = _Passage;

  /// Decodes from JSON.
  factory Passage.fromJson(Map<String, dynamic> json) =>
      _$PassageFromJson(json);

  /// Word index range `[start, end)` of the sentence containing word [wordIndex].
  ///
  /// A sentence ends after a word when the text between it and the next word contains
  /// `.`, `!` or `?`. Without word offsets the whole passage is one sentence.
  /// Throws [RangeError] for an invalid [wordIndex].
  ({int start, int end}) sentenceRange(int wordIndex) {
    RangeError.checkValidIndex(wordIndex, words, 'wordIndex');
    bool endsSentenceAfter(int i) {
      final w = words[i];
      if (i + 1 >= words.length) return true;
      final next = words[i + 1];
      if (w.offset == null || next.offset == null) return false;
      final gap = text.substring(w.offset! + w.text.length, next.offset);
      return gap.contains(RegExp(r'[.!?]'));
    }

    var start = wordIndex;
    while (start > 0 && !endsSentenceAfter(start - 1)) {
      start--;
    }
    var end = wordIndex;
    while (!endsSentenceAfter(end)) {
      end++;
    }
    return (start: start, end: end + 1);
  }

  /// A passage made of words `[start, end)`, re-indexed from 0, with [text] cut to
  /// those words and offsets shifted to match, and id `"$id#$start-$end"`.
  /// Add [start] to a result's word index to map it back to this passage.
  Passage slice(int start, int end) {
    RangeError.checkValidRange(start, end, words.length);
    if (start == end) {
      return copyWith(id: '$id#$start-$end', text: '', words: const []);
    }
    final part = words.sublist(start, end);
    final first = part.first.offset;
    final last = part.last;
    final hasOffsets = part.every((w) => w.offset != null);
    final sliceText = hasOffsets
        ? text.substring(first!, last.offset! + last.text.length)
        : part.map((w) => w.text).join(' ');
    return copyWith(
      id: '$id#$start-$end',
      text: sliceText,
      words: [
        for (var i = 0; i < part.length; i++)
          part[i].copyWith(
            index: i,
            offset: hasOffsets ? part[i].offset! - first! : null,
          ),
      ],
    );
  }
}
