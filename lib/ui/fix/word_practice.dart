import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/contracts.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../results/word_status_style.dart';
import 'hold_to_record.dart';
import 'sound_chips.dart';
import 'sound_marks.dart';

/// The details and controls for practising one word, shared by the Results word sheet
/// and Fix a word: expected (and, on the full tier, heard) IPA, sound chips with the
/// wrong sound marked, a tip, Play British / Play slowly, and hold-to-record.
///
/// With [lightTier] only the word score is shown: no heard IPA, chips or tip.
class WordPractice extends ConsumerWidget {
  /// Creates the panel for [result] (and [word], its passage spec, if known).
  const WordPractice({
    super.key,
    required this.result,
    required this.word,
    required this.onScored,
    this.lightTier = false,
    this.tier = ModelTier.full,
    this.showHeader = true,
  });

  /// Latest score of the word.
  final WordResult result;

  /// Passage spec of the word; null when the passage could not be loaded (no retry).
  final WordSpec? word;

  /// Called with each scored retry.
  final ValueChanged<WordResult> onScored;

  /// Hide per-sound detail (light model tier).
  final bool lightTier;

  /// Tier to load for retries if none is loaded.
  final ModelTier tier;

  /// Show the word and its score badge at the top.
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final word = this.word;
    final phonemes = result.phonemes;
    final showSounds = !lightTier && phonemes.isNotEmpty;
    final issues = showSounds && hasSoundIssues(phonemes);
    final worst = showSounds ? worstSound(phonemes) : null;
    final tip = worst == null
        ? null
        : ref.read(tipsProvider).tipFor(worst.expected, worst.heard);
    final expected = word != null && word.phonemes.isNotEmpty
        ? expectedIpa(word)
        : phonemes.isNotEmpty
        ? expectedIpaOf(phonemes)
        : null;
    final voice = ref.read(voiceServiceProvider);
    final scorable = word?.scorable ?? result.status != WordStatus.notScored;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader)
          Row(
            children: [
              Expanded(
                child: Text(
                  result.text,
                  style: text.headlineMedium,
                  key: const Key('practiceWord'),
                ),
              ),
              ScoreBadge(score: result.score, status: result.status),
            ],
          ),
        if (expected != null) ...[
          const SizedBox(height: 8),
          _IpaLine(label: 'British', ipa: expected),
        ],
        if (issues) ...[
          const SizedBox(height: 4),
          _IpaLine(label: 'You said', ipa: heardIpa(phonemes), wrong: true),
        ],
        if (result.status == WordStatus.missed) ...[
          const SizedBox(height: 8),
          Text("We didn't hear this word.", style: text.bodyLarge),
        ],
        if (!scorable) ...[
          const SizedBox(height: 8),
          Text(
            "This word isn't in the British dictionary, so it isn't scored.",
            style: text.bodyLarge,
          ),
        ],
        if (showSounds) ...[
          const SizedBox(height: 12),
          SoundChips(phonemes: phonemes),
        ],
        if (lightTier && scorable) ...[
          const SizedBox(height: 8),
          Text(
            'Word score only. Download the full model in Settings to see each '
            'sound.',
            style: text.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (tip != null) ...[const SizedBox(height: 12), _TipCard(tip: tip)],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => unawaited(voice.speak(result.text)),
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Play British'),
            ),
            OutlinedButton.icon(
              onPressed: () => unawaited(
                voice.speak(result.text, rate: VoiceService.slowRate),
              ),
              icon: const Icon(Icons.slow_motion_video),
              label: const Text('Play slowly'),
            ),
          ],
        ),
        if (word != null && scorable) ...[
          const SizedBox(height: 16),
          Center(
            child: HoldToRecordButton(
              key: ValueKey('record-${word.index}'),
              word: word,
              tier: tier,
              onScored: onScored,
            ),
          ),
        ],
      ],
    );
  }
}

class _IpaLine extends StatelessWidget {
  const _IpaLine({required this.label, required this.ipa, this.wrong = false});

  final String label;
  final String ipa;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(child: Text(ipa, style: theme.textTheme.titleLarge)),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              key: const Key('tipText'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
