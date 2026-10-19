import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import 'score_colors.dart';

/// Non-colour cues for word statuses, so colour-blind users can tell them apart:
/// close words get a dashed underline, fix / missed words a solid thick underline and
/// an icon. Use these everywhere a score colour is shown.
abstract final class ScoreCue {
  /// Icon for [status] (shown next to scores, in legends and after red words).
  static IconData icon(WordStatus status) => switch (status) {
    WordStatus.good => Icons.check_circle_outline,
    WordStatus.close => Icons.change_history,
    WordStatus.fix => Icons.error_outline,
    WordStatus.missed => Icons.remove_circle_outline,
    WordStatus.notScored => Icons.help_outline,
  };

  /// Short label for [status] (legend text and semantics).
  static String label(WordStatus status) => switch (status) {
    WordStatus.good => 'Good',
    WordStatus.close => 'Close',
    WordStatus.fix => 'Fix',
    WordStatus.missed => 'Missed',
    WordStatus.notScored => 'Not scored',
  };

  /// Whether [status] is underlined (close, fix, missed).
  static bool underlined(WordStatus status) =>
      status == WordStatus.close || status.isRed;

  /// Whether [status] carries an icon after the word in passage text (fix, missed).
  static bool showsIconInText(WordStatus status) => status.isRed;

  /// [base] coloured for [status] with its underline cue. Use for passage words.
  static TextStyle wordStyle(
    BuildContext context,
    WordStatus status, {
    TextStyle? base,
  }) {
    final color = ScoreColors.of(context).forStatus(status);
    final style = (base ?? const TextStyle()).copyWith(color: color);
    if (!underlined(status)) {
      return status == WordStatus.notScored
          ? style.copyWith(fontStyle: FontStyle.italic)
          : style;
    }
    final red = status.isRed;
    return style.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: color,
      decorationStyle: red
          ? TextDecorationStyle.solid
          : TextDecorationStyle.dashed,
      decorationThickness: red ? 2.5 : 1.5,
      fontWeight: red ? FontWeight.w600 : style.fontWeight,
    );
  }
}

/// The status icon in its score colour.
class ScoreIcon extends StatelessWidget {
  /// Creates the icon for [status].
  const ScoreIcon(this.status, {super.key, this.size = 18});

  /// Word status.
  final WordStatus status;

  /// Icon size.
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    ScoreCue.icon(status),
    size: size,
    color: ScoreColors.of(context).forStatus(status),
    semanticLabel: ScoreCue.label(status),
  );
}

/// A 0-100 score with its colour and icon, e.g. "72" with a triangle in amber.
class ScoreBadge extends StatelessWidget {
  /// Creates the badge for [score]; [suffix] is appended (e.g. '%').
  const ScoreBadge({
    super.key,
    required this.score,
    this.suffix = '',
    this.style,
  });

  /// 0-100 score.
  final int score;

  /// Text after the number.
  final String suffix;

  /// Text style (defaults to titleMedium).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final status = WordStatus.fromScore(score);
    final color = ScoreColors.of(context).forStatus(status);
    final text = style ?? Theme.of(context).textTheme.titleMedium!;
    return Semantics(
      label: '$score$suffix, ${ScoreCue.label(status)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScoreIcon(status, size: (text.fontSize ?? 16) + 2),
          const SizedBox(width: 4),
          Text(
            '$score$suffix',
            style: text.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Legend for the word colours: good, close and fix, each with its cue.
class ScoreLegend extends StatelessWidget {
  /// Creates the legend; [statuses] defaults to good, close, fix.
  const ScoreLegend({
    super.key,
    this.statuses = const [WordStatus.good, WordStatus.close, WordStatus.fix],
  });

  /// Statuses to list.
  final List<WordStatus> statuses;

  static String _range(WordStatus s) => switch (s) {
    WordStatus.good => '80+',
    WordStatus.close => '60-79',
    WordStatus.fix => 'under 60',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodyMedium!;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final s in statuses)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScoreIcon(s),
              const SizedBox(width: 4),
              Text(
                [
                  ScoreCue.label(s),
                  _range(s),
                ].where((e) => e.isNotEmpty).join(' '),
                style: ScoreCue.wordStyle(context, s, base: text),
              ),
            ],
          ),
      ],
    );
  }
}
