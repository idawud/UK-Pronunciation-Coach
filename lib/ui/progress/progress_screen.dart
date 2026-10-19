import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/navigation.dart';
import '../../core/models/models.dart';
import 'progress_data.dart';
import 'score_trend_chart.dart';
import 'sound_accuracy_list.dart';
import 'streak_calendar.dart';

/// Width at which Progress switches to two columns.
const double progressTwoColumnWidth = 700;

/// Progress: score trend, level and level history, sound accuracy (weakest first) and
/// the streak calendar. Shows an empty state for a new user.
class ProgressScreen extends ConsumerWidget {
  /// Creates the screen.
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(progressDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: switch (data) {
        AsyncData(:final value) when value.isEmpty => const _EmptyProgress(),
        AsyncData(:final value) => _ProgressBody(data: value),
        AsyncError() => _ProgressError(
          onRetry: () => ref.invalidate(progressDataProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.data});

  final ProgressData data;

  @override
  Widget build(BuildContext context) {
    final summary = _SummaryCard(data: data);
    final trend = _Section(
      title: 'Score trend',
      child: data.attempts.isEmpty
          ? const _Hint('Read a passage to start your score trend.')
          : ScoreTrendChart(attempts: data.attempts),
    );
    final levels = _Section(
      title: 'Level history',
      child: _LevelHistory(level: data.level, history: data.levelHistory),
    );
    final sounds = _Section(
      title: 'Sounds, weakest first',
      child: data.soundStats.isEmpty
          ? _Hint(
              data.lightTierOnly
                  ? 'Per-sound scores need the full model. Download it in '
                        'Settings to see them.'
                  : 'Sound scores appear after your first reading.',
            )
          : SoundAccuracyList(stats: data.soundStats),
    );
    final calendar = _Section(
      title: 'Streak calendar',
      child: StreakCalendar(
        today: data.today,
        practisedDays: data.daily.practisedDays,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= progressTwoColumnWidth;
        final content = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: [summary, trend, levels])),
                  const SizedBox(width: 16),
                  Expanded(child: Column(children: [calendar, sounds])),
                ],
              )
            : Column(children: [summary, trend, calendar, sounds, levels]);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1100 : 680),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final ProgressData data;

  @override
  Widget build(BuildContext context) {
    final daily = data.daily;
    final streak = daily.streak == 1 ? '1 day' : '${daily.streak} days';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryItem(
                icon: Icons.school_outlined,
                label: 'Level',
                value: '${data.level} of 6',
              ),
            ),
            Expanded(
              child: _SummaryItem(
                icon: Icons.local_fire_department_outlined,
                label: 'Streak',
                value: streak,
              ),
            ),
            Expanded(
              child: _SummaryItem(
                icon: daily.goalMet ? Icons.task_alt : Icons.timer_outlined,
                label: 'Today',
                value: '${daily.minutesToday} / ${daily.dailyGoalMinutes} min',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: t.labelMedium?.copyWith(color: color)),
            Text(
              value,
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _LevelHistory extends StatelessWidget {
  const _LevelHistory({required this.level, required this.history});

  final int level;
  final List<LevelChange> history;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You are on level $level of 6.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const _Hint(
            'Three passages in a row at 85 or more moves you up a level.',
          ),
        for (final change in history.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              change.isUp ? Icons.trending_up : Icons.trending_down,
              color: change.isUp ? scheme.primary : scheme.onSurfaceVariant,
            ),
            title: Text('Level ${change.from} to ${change.to}'),
            subtitle: Text('${formatDay(change.at)}. ${change.reason}'),
          ),
      ],
    );
  }
}

class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined, size: 64, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'No progress yet',
                style: t.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Read your first passage and your scores, sounds and streak '
                'will show here.',
                style: t.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => GoRouter.maybeOf(context)?.go(AppRoutes.home),
                icon: const Icon(Icons.mic),
                label: const Text("Start today's passage"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressError extends StatelessWidget {
  const _ProgressError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              "Your progress couldn't be loaded.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
