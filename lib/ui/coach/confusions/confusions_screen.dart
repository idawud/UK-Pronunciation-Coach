import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../shell/state_views.dart';
import '../../theme/theme.dart';
import 'confusion_logic.dart';
import 'confusions_providers.dart';
import 'daily_session_screen.dart';

/// Coach section "Confusions": the sounds the user most often swaps (for example `ʌ`
/// heard as `æ`), with example words, the streak and a button for today's session.
///
/// Nothing here is scored. The list is estimated from the phoneme results of recent
/// attempts.
class ConfusionsScreen extends ConsumerWidget {
  /// Creates the screen.
  const ConfusionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(confusionsDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Confusions')),
      body: data.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => MessageView.error(
          onRetry: () => ref.invalidate(confusionsDataProvider),
        ),
        data: (value) => value.confusions.isEmpty
            ? _Empty(streak: value.streak)
            : _List(data: value),
      ),
    );
  }
}

/// Opens today's session on top of the current route.
void _openSession(BuildContext context) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DailySessionScreen()),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return ReadingWidth(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _StreakCard(streak: streak),
          Expanded(
            child: MessageView(
              icon: Icons.compare_arrows,
              title: 'No confusions yet',
              message:
                  'Read a few passages. When the coach hears one sound where you '
                  'meant another, twice or more, it shows up here.',
              actionLabel: "Start today's session",
              onAction: () => _openSession(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.data});

  final ConfusionsData data;

  @override
  Widget build(BuildContext context) {
    return ReadingWidth(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StreakCard(streak: data.streak),
          const SizedBox(height: 16),
          Text(
            'Sounds you swap',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final confusion in data.confusions)
            _ConfusionTile(confusion: confusion),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openSession(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text("Start today's session"),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_fire_department_outlined),
        title: Text(streak == 0 ? 'No streak yet' : '$streak-day streak'),
        subtitle: const Text('One finished session a day keeps it going.'),
      ),
    );
  }
}

class _ConfusionTile extends StatelessWidget {
  const _ConfusionTile({required this.confusion});

  final Confusion confusion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scores = ScoreColors.of(context);
    final expected = AppTypography.slashes([confusion.expected]);
    final heard = AppTypography.slashes([confusion.heard]);
    final times = confusion.count == 1 ? 'once' : '${confusion.count} times';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          container: true,
          label:
              '$expected heard as $heard, $times, average score '
              '${confusion.avgScore.round()}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(expected, style: AppTypography.ipa(context, size: 22)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(heard, style: AppTypography.ipa(context, size: 22)),
                  const Spacer(),
                  Text(times, style: theme.textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              if (confusion.exampleWords.isNotEmpty)
                Text(
                  'Examples: ${confusion.exampleWords.join(', ')}',
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    ScoreCue.icon(WordStatus.fix),
                    size: 18,
                    color: scores.fix,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Average ${confusion.avgScore.round()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scores.fix,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
