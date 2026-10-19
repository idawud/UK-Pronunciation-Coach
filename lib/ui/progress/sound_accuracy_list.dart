import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../theme/score_colors.dart';

/// Sound accuracy rows, weakest first: IPA, bar coloured by score band, the number and
/// an icon for close / fix bands (non-colour cue).
class SoundAccuracyList extends StatelessWidget {
  /// Creates the list. [stats] must already be sorted weakest first.
  const SoundAccuracyList({super.key, required this.stats, this.limit});

  /// Sound stats, weakest first.
  final List<SoundStat> stats;

  /// Show at most this many rows (all when null).
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final shown = limit == null ? stats : stats.take(limit!).toList();
    return Column(children: [for (final s in shown) _SoundRow(stat: s)]);
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({required this.stat});

  final SoundStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ScoreColors.of(context);
    final score = stat.accuracy.round();
    final status = WordStatus.fromScore(score);
    final color = colors.forStatus(status);
    final (icon, label) = switch (status) {
      WordStatus.good => (Icons.check_circle_outline, 'good'),
      WordStatus.close => (Icons.change_history, 'close'),
      _ => (Icons.error_outline, 'needs work'),
    };
    final times = stat.attempts == 1 ? '1 time' : '${stat.attempts} times';
    return Semantics(
      label: 'Sound ${stat.ipa}: $score, $label, heard $times',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  '/${stat.ipa}/',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stat.accuracy.clamp(0, 100) / 100,
                    minHeight: 10,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 32,
                child: Text(
                  '$score',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
