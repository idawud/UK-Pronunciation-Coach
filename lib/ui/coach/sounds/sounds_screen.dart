import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contracts/navigation.dart';
import '../../../core/contracts/voice_service.dart';
import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../shell/state_views.dart';
import '../../theme/theme.dart';
import 'coach_data.dart';
import 'coach_exercises.dart';
import 'coach_speech.dart';

/// Sounds section of the Coach tab: a simple speech-therapy coach. Guided exercises for the user's weakest
/// sounds (from `coachDataProvider`) sit above a fixed library of warm-ups, tongue
/// twisters and pace and breathing exercises. The coach speaks each model line with
/// the offline en-GB voice; nothing is scored.
class SoundsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SoundsScreen({super.key});

  @override
  ConsumerState<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends ConsumerState<SoundsScreen> {
  /// Captured here so speech can be stopped in [dispose] without a ref.
  late final VoiceService _voice;
  late final CoachSpeech _speech;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceServiceProvider);
    _speech = CoachSpeech(_voice);
  }

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }

  Future<void> _practisePassage(String ipa) async {
    try {
      final passage = await ref
          .read(practiceEngineProvider)
          .nextPassage(soundTag: ipa);
      await _speech.stop();
      if (!mounted) return;
      await context.push<Object?>(
        AppRoutes.read,
        extra: ReadArgs(passageId: passage.id),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No passage found for this sound.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(coachDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sounds')),
      body: switch (data) {
        AsyncValue(:final List<GuidedExercise> value) => _CoachBody(
          guided: value,
          speech: _speech,
          onPractise: _practisePassage,
        ),
        AsyncValue(error: != null) => MessageView.error(
          onRetry: () => ref.invalidate(coachDataProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _CoachBody extends StatelessWidget {
  const _CoachBody({
    required this.guided,
    required this.speech,
    required this.onPractise,
  });

  final List<GuidedExercise> guided;
  final CoachSpeech speech;
  final ValueChanged<String> onPractise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ReadingWidth(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('For your weakest sounds', style: text.titleMedium),
        ),
        if (guided.isEmpty)
          ReadingWidth(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const _EmptyGuided(),
          )
        else
          for (final g in guided)
            ReadingWidth(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _GuidedCard(
                exercise: g,
                speech: speech,
                onPractise: () => onPractise(g.stat.ipa),
              ),
            ),
        ReadingWidth(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Exercise library', style: text.titleMedium),
        ),
        for (final category in CoachCategory.values)
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: Text(category.label),
                initiallyExpanded: category == CoachCategory.warmUp,
                children: [
                  for (final ex in coachLibrary.where(
                    (e) => e.category == category,
                  ))
                    _ExerciseTile(exercise: ex, speech: speech),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyGuided extends StatelessWidget {
  const _EmptyGuided();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.graphic_eq, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Read a passage first and your coach will pick exercises',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidedCard extends StatelessWidget {
  const _GuidedCard({
    required this.exercise,
    required this.speech,
    required this.onPractise,
  });

  final GuidedExercise exercise;
  final CoachSpeech speech;
  final VoidCallback onPractise;

  @override
  Widget build(BuildContext context) {
    final stat = exercise.stat;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppTypography.slashes([stat.ipa]),
                    style: AppTypography.ipa(context, size: 24),
                  ),
                ),
                ScoreBadge(score: stat.accuracy.round(), suffix: '%'),
              ],
            ),
            Text(
              '${stat.attempts} ${stat.attempts == 1 ? 'time' : 'times'} heard',
              style: text.bodySmall,
            ),
            if (exercise.tip != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(exercise.tip!, style: text.bodyMedium)),
                ],
              ),
            ],
            for (final pair in exercise.pairs) ...[
              const SizedBox(height: 12),
              _PairRow(pair: pair, speech: speech),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonal(
                onPressed: onPractise,
                child: const Text('Practise passage'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairRow extends StatelessWidget {
  const _PairRow({required this.pair, required this.speech});

  final MinimalPair pair;
  final CoachSpeech speech;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${pair.wordA} · ${pair.wordB}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _SpeakButton(
              speech: speech,
              id: 'pair/${pair.wordA}/normal',
              text: pair.wordA,
              label: pair.wordA,
            ),
            _SpeakButton(
              speech: speech,
              id: 'pair/${pair.wordA}/slow',
              text: pair.wordA,
              rate: VoiceService.slowRate,
              icon: Icons.slow_motion_video,
              label: '${pair.wordA} slowly',
            ),
            _SpeakButton(
              speech: speech,
              id: 'pair/${pair.wordB}/normal',
              text: pair.wordB,
              label: pair.wordB,
            ),
            _SpeakButton(
              speech: speech,
              id: 'pair/${pair.wordB}/slow',
              text: pair.wordB,
              rate: VoiceService.slowRate,
              icon: Icons.slow_motion_video,
              label: '${pair.wordB} slowly',
            ),
          ],
        ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.speech});

  final CoachExercise exercise;
  final CoachSpeech speech;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(exercise.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.instructions),
          const SizedBox(height: 4),
          Text(
            exercise.speakText,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      trailing: _SpeakButton(
        speech: speech,
        id: 'exercise/${exercise.id}',
        text: exercise.speakText,
        rate: exercise.rate,
        tooltip: 'Play ${exercise.title}',
      ),
    );
  }
}

/// A play button that shows stop while its own utterance plays. Icon-only when [label]
/// is null, otherwise a text button labelled with [label].
class _SpeakButton extends StatelessWidget {
  const _SpeakButton({
    required this.speech,
    required this.id,
    required this.text,
    this.rate = VoiceService.normalRate,
    this.icon = Icons.play_arrow,
    this.label,
    this.tooltip,
  });

  final CoachSpeech speech;
  final String id;
  final String text;
  final double rate;
  final IconData icon;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: speech.playing,
      builder: (context, playingId, _) {
        final isPlaying = playingId == id;
        final shownIcon = isPlaying ? Icons.stop : icon;
        void onPressed() => speech.toggle(id, text, rate: rate);
        if (label == null) {
          return IconButton(
            icon: Icon(shownIcon),
            tooltip: isPlaying ? 'Stop' : (tooltip ?? 'Play'),
            onPressed: onPressed,
          );
        }
        return TextButton.icon(
          icon: Icon(shownIcon),
          label: Text(label!),
          onPressed: onPressed,
        );
      },
    );
  }
}
