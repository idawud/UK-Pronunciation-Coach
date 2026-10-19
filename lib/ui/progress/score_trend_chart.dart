import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../theme/score_colors.dart';
import 'progress_data.dart';

/// Line chart of overall scores, oldest attempt on the left. Bands at 60 and 80 use the
/// score colour tokens; the line uses the theme's primary colour.
class ScoreTrendChart extends StatelessWidget {
  /// Creates the chart for [attempts] (oldest first).
  const ScoreTrendChart({super.key, required this.attempts});

  /// Attempts, oldest first.
  final List<AttemptResult> attempts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = ScoreColors.of(context);
    final textTheme = theme.textTheme;
    final scores = [for (final a in attempts) a.overall];
    final latest = scores.last;
    final best = scores.reduce((a, b) => a > b ? a : b);
    final average = (scores.reduce((a, b) => a + b) / scores.length).round();
    final labelStyle = textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _Stat(label: 'Latest', value: '$latest'),
            _Stat(label: 'Best', value: '$best'),
            _Stat(label: 'Average', value: '$average'),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          label:
              'Score trend over ${scores.length} readings: latest $latest, '
              'best $best, average $average.',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: scores.length <= 1 ? 1 : (scores.length - 1).toDouble(),
                  minY: 0,
                  maxY: 100,
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: WordStatus.defaultGood.toDouble(),
                        color: colors.good,
                        strokeWidth: 1,
                        dashArray: const [6, 4],
                      ),
                      HorizontalLine(
                        y: WordStatus.defaultClose.toDouble(),
                        color: colors.close,
                        strokeWidth: 1,
                        dashArray: const [2, 4],
                      ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: _labelInterval(scores.length),
                        getTitlesWidget: (value, meta) {
                          final i = value.round();
                          if (i != value || i < 0 || i >= attempts.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              formatShortDay(attempts[i].at),
                              style: labelStyle,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 20,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text('${value.round()}', style: labelStyle),
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < scores.length; i++)
                          FlSpot(i.toDouble(), scores[i].toDouble()),
                      ],
                      color: scheme.primary,
                      barWidth: 3,
                      isCurved: false,
                      dotData: FlDotData(
                        show: scores.length <= 15,
                        getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                          radius: 3.5,
                          color: scheme.primary,
                          strokeWidth: 1.5,
                          strokeColor: scheme.surface,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
                duration: Duration.zero,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Legend(color: colors.good, dashed: true, label: 'Good (80+)'),
            _Legend(color: colors.close, dashed: true, label: 'Close (60+)'),
          ],
        ),
      ],
    );
  }

  static double _labelInterval(int count) {
    if (count <= 4) return 1;
    return ((count - 1) / 3).ceilToDouble();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.labelMedium),
        Text(value, style: t.headlineSmall),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < (dashed ? 3 : 1); i++)
          Container(
            width: dashed ? 5 : 16,
            height: 2,
            margin: const EdgeInsets.only(right: 2),
            color: color,
          ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
