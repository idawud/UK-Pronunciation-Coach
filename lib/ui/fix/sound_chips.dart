import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../theme/score_colors.dart';
import 'sound_marks.dart';

/// One chip per expected sound of a word. Sounds heard wrongly (substituted, dropped,
/// added r) are highlighted in the fix colour with a thick border, an icon and a
/// "heard" line, so the cue does not rely on colour alone.
class SoundChips extends StatelessWidget {
  /// Creates chips for [phonemes].
  const SoundChips({super.key, required this.phonemes});

  /// Scored sounds of the word, in order.
  final List<PhonemeResult> phonemes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final p in phonemes) _SoundChip(p)],
    );
  }
}

class _SoundChip extends StatelessWidget {
  const _SoundChip(this.p);

  final PhonemeResult p;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ScoreColors.of(context);
    final issue = soundIssue(p);
    final wrong = issue != SoundIssue.ok;
    final status = wrong ? WordStatus.fix : WordStatus.fromScore(p.score);
    final color = wrong ? colors.fix : theme.colorScheme.outline;
    final note = switch (issue) {
      SoundIssue.ok => null,
      SoundIssue.substituted => 'heard /${p.heard}/',
      SoundIssue.dropped => 'missing',
      SoundIssue.addedR => 'added r',
    };
    final semantics = switch (issue) {
      SoundIssue.ok => 'Sound ${p.expected}, score ${p.score}',
      SoundIssue.substituted =>
        'Sound ${p.expected}, heard ${p.heard} instead, score ${p.score}',
      SoundIssue.dropped => 'Sound ${p.expected} was left out',
      SoundIssue.addedR => 'Sound ${p.expected} was said with an r',
    };
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: wrong
              ? colors.fix.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: color, width: wrong ? 2.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (wrong) ...[
                  Icon(Icons.error_outline, size: 16, color: colors.fix),
                  const SizedBox(width: 2),
                ],
                Text(
                  '/${p.expected}/',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: wrong ? colors.fix : null,
                    fontWeight: wrong ? FontWeight.w700 : null,
                    decoration: issue == SoundIssue.dropped
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: colors.fix,
                  ),
                ),
              ],
            ),
            if (note != null)
              Text(
                note,
                style: theme.textTheme.labelSmall?.copyWith(color: colors.fix),
              )
            else if (status != WordStatus.good)
              Text(
                '${p.score}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.forStatus(status),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
