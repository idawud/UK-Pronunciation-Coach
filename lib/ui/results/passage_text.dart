import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../theme/score_colors.dart';
import 'word_status_style.dart';

/// The passage (or sentence) text with each word coloured by its result. Close words
/// get a dotted underline, red words a solid underline and an icon. Tapping a word
/// calls [onWordTap] with its index.
///
/// Uses `WordSpec.offset` to keep the original punctuation; without a [passage] (or
/// offsets) the words are joined with spaces.
class PassageText extends StatefulWidget {
  /// Creates the text for [words] of [passage].
  const PassageText({
    super.key,
    required this.words,
    this.passage,
    this.onWordTap,
    this.style,
    this.start = 0,
    this.end,
  });

  /// Results by word; matched to passage words by `index`.
  final List<WordResult> words;

  /// The passage read, if loaded.
  final Passage? passage;

  /// Called with a word's passage index when tapped; null makes the text read-only.
  final ValueChanged<int>? onWordTap;

  /// Base text style (defaults to bodyLarge at 20).
  final TextStyle? style;

  /// First passage word index to show (for a sentence).
  final int start;

  /// End (exclusive) passage word index to show; null for the end of the passage.
  final int? end;

  @override
  State<PassageText> createState() => _PassageTextState();
}

class _PassageTextState extends State<PassageText> {
  final Map<int, TapGestureRecognizer> _recognizers = {};

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer? _recognizer(int index) {
    if (widget.onWordTap == null) return null;
    return _recognizers.putIfAbsent(
      index,
      () => TapGestureRecognizer()..onTap = () => widget.onWordTap?.call(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ScoreColors.of(context);
    final base =
        widget.style ??
        Theme.of(context).textTheme.bodyLarge!
            .copyWith(fontSize: 20, height: 1.6);
    final byIndex = {for (final w in widget.words) w.index: w};
    final spans = <InlineSpan>[];

    InlineSpan wordSpan(int index, String text) {
      final r = byIndex[index];
      if (r == null) return TextSpan(text: text);
      final scored =
          r.status != WordStatus.notScored && r.status != WordStatus.missed;
      final span = TextSpan(
        text: text,
        style: WordStatusStyle.textStyle(base, r.status, colors),
        recognizer: _recognizer(index),
        semanticsLabel: scored
            ? '$text, ${r.score}, ${WordStatusStyle.label(r.status)}'
            : '$text, ${WordStatusStyle.label(r.status)}',
      );
      if (!WordStatusStyle.hasInlineIcon(r.status)) return span;
      return TextSpan(
        children: [
          span,
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ExcludeSemantics(
              child: Icon(
                WordStatusStyle.icon(r.status),
                size: (base.fontSize ?? 20) * 0.8,
                color: colors.forStatus(r.status),
              ),
            ),
          ),
        ],
      );
    }

    final passage = widget.passage;
    final hasOffsets =
        passage != null &&
        passage.words.isNotEmpty &&
        passage.words.every((w) => w.offset != null);
    if (hasOffsets) {
      final end = widget.end ?? passage.words.length;
      final words = passage.words.sublist(widget.start, end);
      var cursor = words.isEmpty ? 0 : words.first.offset!;
      for (final w in words) {
        if (w.offset! > cursor) {
          spans.add(TextSpan(text: passage.text.substring(cursor, w.offset)));
        }
        spans.add(wordSpan(w.index, w.text));
        cursor = w.offset! + w.text.length;
      }
      // Trailing punctuation of the last word shown ("river.").
      final next = end < passage.words.length
          ? passage.words[end].offset!
          : passage.text.length;
      final tail = passage.text.substring(cursor, next).trimRight();
      if (tail.isNotEmpty) spans.add(TextSpan(text: tail));
    } else {
      final source =
          passage?.words.map((w) => (w.index, w.text)).toList() ??
          widget.words.map((w) => (w.index, w.text)).toList();
      final shown = source
          .where(
            (w) =>
                w.$1 >= widget.start &&
                (widget.end == null || w.$1 < widget.end!),
          )
          .toList();
      for (var i = 0; i < shown.length; i++) {
        if (i > 0) spans.add(const TextSpan(text: ' '));
        spans.add(wordSpan(shown[i].$1, shown[i].$2));
      }
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
