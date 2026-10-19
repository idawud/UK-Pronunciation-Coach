import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../theme/score_colors.dart';

/// How a word status looks: colour from [ScoreColors], plus a non-colour cue
/// (underline style and icon) so close and fix words differ without colour.
abstract final class WordStatusStyle {
  /// Short label for [status].
  static String label(WordStatus status) => switch (status) {
    WordStatus.good => 'Good',
    WordStatus.close => 'Close',
    WordStatus.fix => 'Fix',
    WordStatus.missed => 'Missed',
    WordStatus.notScored => 'Not scored',
  };

  /// Icon for [status] (used in badges, the legend and after red words).
  static IconData icon(WordStatus status) => switch (status) {
    WordStatus.good => Icons.check_circle_outline,
    WordStatus.close => Icons.adjust,
    WordStatus.fix || WordStatus.missed => Icons.error_outline,
    WordStatus.notScored => Icons.remove_circle_outline,
  };

  /// Whether a word with [status] gets an icon after it in the passage text.
  static bool hasInlineIcon(WordStatus status) => status.isRed;

  /// [base] coloured for [status]: close words get a dotted underline, red words a
  /// thick solid underline (and an inline icon, see [hasInlineIcon]).
  static TextStyle textStyle(
    TextStyle base,
    WordStatus status,
    ScoreColors colors,
  ) {
    final color = colors.forStatus(status);
    return switch (status) {
      WordStatus.good => base.copyWith(color: color),
      WordStatus.notScored => base.copyWith(
        color: color,
        fontStyle: FontStyle.italic,
      ),
      WordStatus.close => base.copyWith(
        color: color,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: color,
        decorationThickness: 2,
      ),
      WordStatus.fix || WordStatus.missed => base.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.solid,
        decorationColor: color,
        decorationThickness: 2.5,
      ),
    };
  }

  /// Colour for a 0-100 score using the default thresholds.
  static Color scoreColor(BuildContext context, int score) =>
      ScoreColors.of(context).forStatus(WordStatus.fromScore(score));
}

/// A pill showing a score with its status icon and colour, e.g. "58 Fix".
class ScoreBadge extends StatelessWidget {
  /// Creates a badge for [score] with [status].
  const ScoreBadge({
    super.key,
    required this.score,
    required this.status,
    this.large = false,
  });

  /// 0-100.
  final int score;

  /// Colour band.
  final WordStatus status;

  /// Bigger text (Fix a word header).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = ScoreColors.of(context).forStatus(status);
    final text = Theme.of(context).textTheme;
    final style = (large ? text.titleMedium : text.labelLarge)?.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    );
    final scored =
        status != WordStatus.notScored && status != WordStatus.missed;
    return Semantics(
      label: scored
          ? 'Score $score, ${WordStatusStyle.label(status)}'
          : WordStatusStyle.label(status),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8,
          vertical: large ? 6 : 3,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              WordStatusStyle.icon(status),
              size: large ? 20 : 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              scored
                  ? '$score ${WordStatusStyle.label(status)}'
                  : WordStatusStyle.label(status),
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
