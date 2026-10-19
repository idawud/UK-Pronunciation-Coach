import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/navigation.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../shell/state_views.dart';
import '../theme/theme.dart';
import 'home_data.dart';
import 'level_info.dart';

/// Greeting for the hour of [now].
String greetingFor(DateTime now) => now.hour < 12
    ? 'Good morning'
    : now.hour < 18
    ? 'Good afternoon'
    : 'Good evening';

/// Home: greeting, level and progress, streak and today's minutes, "Start today's
/// passage", weak sounds (top 3) and words due for review.
class HomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('UK Pronunciation Coach')),
      body: switch (data) {
        AsyncValue(:final HomeData value) => _HomeBody(data: value),
        AsyncValue(error: != null) => MessageView.error(
          onRetry: () => ref.invalidate(homeDataProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        ReadingWidth(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(greetingFor(now), style: text.headlineMedium),
              const SizedBox(height: 16),
              _LevelCard(data: data),
              const SizedBox(height: 12),
              _TodayRow(daily: data.daily),
              const SizedBox(height: 20),
              const StartPassageButton(),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, c) {
                  final weak = _WeakSoundsCard(sounds: data.weakSounds);
                  final due = _ReviewCard(count: data.dueWords.length);
                  if (c.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [weak, const SizedBox(height: 12), due],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: weak),
                        const SizedBox(width: 12),
                        Expanded(child: due),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = data.level >= LevelInfo.maxLevel;
    final caption = top
        ? 'Top level: keep your accuracy up.'
        : '${data.levelUpRun} of ${LevelInfo.levelUpRun} passages at '
              '${LevelInfo.levelUpScore}+ to reach level ${data.level + 1}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Level ${data.level}', style: text.titleLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LevelInfo.focus(data.level),
                    style: text.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: data.levelProgress,
                semanticsLabel: 'Progress to next level',
              ),
            ),
            const SizedBox(height: 8),
            Text(caption, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.daily});

  final DailyProgress daily;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = daily.streak == 1 ? 'day' : 'days';
    return Row(
      children: [
        Expanded(
          child: _Stat(
            icon: Icons.local_fire_department_outlined,
            color: scheme.tertiary,
            value: '${daily.streak} $days',
            label: 'Streak',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Stat(
            icon: daily.goalMet
                ? Icons.check_circle_outline
                : Icons.timer_outlined,
            color: scheme.primary,
            value: '${daily.minutesToday} of ${daily.dailyGoalMinutes} min',
            label: daily.goalMet ? "Today's goal met" : 'Today',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: text.titleMedium),
                  Text(label, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Start today's passage": asks the practice engine for the next passage and opens
/// the Read screen.
class StartPassageButton extends ConsumerStatefulWidget {
  /// Creates the button.
  const StartPassageButton({super.key});

  @override
  ConsumerState<StartPassageButton> createState() => _StartPassageButtonState();
}

class _StartPassageButtonState extends ConsumerState<StartPassageButton> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final passage = await ref.read(practiceEngineProvider).nextPassage();
      if (!mounted) return;
      setState(() => _busy = false);
      await context.push<Object?>(
        AppRoutes.read,
        extra: ReadArgs(passageId: passage.id),
      );
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open a passage. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: _busy ? null : _start,
    icon: _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.mic_none),
    label: const Text("Start today's passage"),
  );
}

class _WeakSoundsCard extends StatelessWidget {
  const _WeakSoundsCard({required this.sounds});

  final List<SoundStat> sounds;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('${AppRoutes.practise}?tab=sounds'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardHeader(title: 'Weak sounds', icon: Icons.graphic_eq),
              const SizedBox(height: 8),
              if (sounds.isEmpty)
                Text(
                  'Read a passage to find the sounds to work on.',
                  style: text.bodyMedium,
                )
              else
                for (final s in sounds)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppTypography.slashes([s.ipa]),
                            style: AppTypography.ipa(context, size: 20),
                          ),
                        ),
                        ScoreBadge(score: s.accuracy.round(), suffix: '%'),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final message = switch (count) {
      0 => 'No words due for review. Nice work!',
      1 => '1 word due for review',
      _ => '$count words due for review',
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('${AppRoutes.practise}?tab=review'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardHeader(title: 'Review', icon: Icons.event_repeat),
              const SizedBox(height: 8),
              Text(
                message,
                style: count == 0 ? text.bodyMedium : text.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}
