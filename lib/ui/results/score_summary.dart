import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../theme/score_colors.dart';
import 'word_status_style.dart';

/// Overall score ring with accuracy and fluency bars.
class ScoreSummary extends StatelessWidget {
  /// Creates the summary for [result].
  const ScoreSummary({super.key, required this.result});

  /// The attempt.
  final AttemptResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ScoreColors.of(context);
    final overallColor = colors.forStatus(WordStatus.fromScore(result.overall));
    return Row(
      children: [
        Semantics(
          label: 'Overall score ${result.overall} out of 100',
          excludeSemantics: true,
          child: SizedBox.square(
            dimension: 104,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: result.overall / 100,
                  strokeWidth: 10,
                  color: overallColor,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${result.overall}',
                        key: const Key('overallScore'),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Overall', style: theme.textTheme.labelMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bar(label: 'Accuracy', value: result.accuracy),
              const SizedBox(height: 12),
              _Bar(label: 'Fluency', value: result.fluency),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label $value out of 100',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              Text('$value', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: WordStatusStyle.scoreColor(context, value),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

/// Key to the word colours, each with its non-colour cue.
class ScoreLegend extends StatelessWidget {
  /// Creates the legend.
  const ScoreLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ScoreColors.of(context);
    final base = theme.textTheme.bodyMedium!;
    Widget item(WordStatus status, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          WordStatusStyle.icon(status),
          size: 16,
          color: colors.forStatus(status),
        ),
        const SizedBox(width: 4),
        Text(text, style: WordStatusStyle.textStyle(base, status, colors)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(WordStatus.good, 'Good 80+'),
        item(WordStatus.close, 'Close 60-79'),
        item(WordStatus.fix, 'Fix under 60'),
      ],
    );
  }
}

/// Message for a level change caused by the attempt.
class LevelChangeCard extends StatelessWidget {
  /// Creates the card for [change].
  const LevelChangeCard({super.key, required this.change});

  /// The change.
  final LevelChange change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = change.isUp ? scheme.primaryContainer : scheme.tertiaryContainer;
    final fg = change.isUp
        ? scheme.onPrimaryContainer
        : scheme.onTertiaryContainer;
    return Card(
      color: bg,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              change.isUp ? Icons.trending_up : Icons.trending_down,
              color: fg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    change.isUp
                        ? 'Level up: level ${change.to}'
                        : 'Back to level ${change.to}',
                    style: theme.textTheme.titleMedium?.copyWith(color: fg),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    change.reason,
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
