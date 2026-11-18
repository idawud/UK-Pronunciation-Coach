import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme.dart';
import 'ipa_content.dart';
import 'ipa_providers.dart';
import 'ipa_sound_screen.dart';

/// Coach section "IPA lessons": the hub. Shows overall progress, the intro lesson, the
/// full chart and one entry per group. Sub-pages are pushed with the navigator, so
/// the back button returns here.
class IpaScreen extends ConsumerWidget {
  /// Creates the hub.
  const IpaScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learned = ref.watch(ipaLearnedProvider).value ?? const <String>{};
    return Scaffold(
      appBar: AppBar(title: const Text('IPA lessons')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: IpaProgressCard(learned: learned),
          ),
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _HubTile(
              icon: Icons.help_outline,
              title: 'What is the IPA?',
              subtitle: 'Symbols, slashes, length and stress marks',
              onTap: () => _open(context, const IpaIntroScreen()),
            ),
          ),
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _HubTile(
              icon: Icons.grid_view,
              title: 'Full chart',
              subtitle: 'All $ipaSoundCount sounds on one page',
              onTap: () => _open(context, const IpaGridScreen()),
            ),
          ),
          for (final group in IpaGroup.values)
            ReadingWidth(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _HubTile(
                icon: switch (group) {
                  IpaGroup.vowels => Icons.radio_button_unchecked,
                  IpaGroup.diphthongs => Icons.swap_horiz,
                  IpaGroup.consonants => Icons.record_voice_over_outlined,
                },
                title: group.label,
                subtitle:
                    '${ipaSoundsIn(group).length} sounds · '
                    '${_learnedIn(group, learned)} learned',
                onTap: () => _open(context, IpaGridScreen(group: group)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Learned sounds in [group], counting only symbols the lessons cover.
int _learnedIn(IpaGroup group, Set<String> learned) => [
  for (final s in ipaSoundsIn(group))
    if (learned.contains(s.symbol)) s,
].length;

/// Overall progress, e.g. "12 / 44 learned".
class IpaProgressCard extends StatelessWidget {
  /// Creates the card for the symbols in [learned].
  const IpaProgressCard({super.key, required this.learned});

  /// Symbols marked learned.
  final Set<String> learned;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = [
      for (final s in ipaSounds)
        if (learned.contains(s.symbol)) s,
    ].length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count / $ipaSoundCount learned',
              key: const ValueKey('ipa-progress-text'),
              style: text.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: count / ipaSoundCount),
          ],
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

/// The "What is the IPA?" lesson: short paragraphs and a worked example.
class IpaIntroScreen extends StatelessWidget {
  /// Creates the lesson.
  const IpaIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('What is the IPA?')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final point in ipaIntroPoints)
            ReadingWidth(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(point.title, style: text.titleMedium),
                      const SizedBox(height: 6),
                      Text(point.body, style: text.bodyLarge),
                    ],
                  ),
                ),
              ),
            ),
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Worked example', style: text.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'ship   /ʃɪp/',
                      style: AppTypography.ipa(context, size: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'sheep  /ʃiːp/',
                      style: AppTypography.ipa(context, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Same consonants, different vowel: one short, one long.',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grid of symbol chips: one group, or every group when [group] is null (the full
/// chart). Consonants are split by manner. Tapping a chip opens the sound's page.
class IpaGridScreen extends ConsumerWidget {
  /// Creates the grid for [group], or the full chart when null.
  const IpaGridScreen({super.key, this.group});

  /// Group to show, or null for every group.
  final IpaGroup? group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learned = ref.watch(ipaLearnedProvider).value ?? const <String>{};
    final text = Theme.of(context).textTheme;
    final groups = group == null ? IpaGroup.values : [group!];
    return Scaffold(
      appBar: AppBar(title: Text(group?.label ?? 'Full chart')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (group != null)
                  Text(group!.description, style: text.bodyMedium),
                const SizedBox(height: 8),
                IpaProgressCard(learned: learned),
              ],
            ),
          ),
          for (final g in groups)
            ReadingWidth(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _GroupSection(
                group: g,
                learned: learned,
                showHeading: group == null,
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.learned,
    required this.showHeading,
  });

  final IpaGroup group;
  final Set<String> learned;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sounds = ipaSoundsIn(group);
    final sections = group == IpaGroup.consonants
        ? [
            for (final m in IpaManner.values)
              (
                label: m.label,
                sounds: [
                  for (final s in sounds)
                    if (s.manner == m) s,
                ],
              ),
          ]
        : [(label: null, sounds: sounds)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(group.label, style: text.titleLarge),
          const SizedBox(height: 4),
        ],
        for (final section in sections) ...[
          if (section.label != null) ...[
            const SizedBox(height: 8),
            Text(section.label!, style: text.titleSmall),
            const SizedBox(height: 4),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in section.sounds)
                IpaSymbolChip(
                  symbol: s.symbol,
                  learned: learned.contains(s.symbol),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => IpaSoundScreen(sound: s),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A tappable chip showing one IPA symbol. Learned sounds get a check mark and a
/// tinted background, so the state does not rely on colour alone.
class IpaSymbolChip extends StatelessWidget {
  /// Creates a chip for [symbol].
  const IpaSymbolChip({
    super.key,
    required this.symbol,
    required this.learned,
    required this.onTap,
  });

  /// IPA symbol shown inside the chip, without slashes.
  final String symbol;

  /// Whether the sound is marked learned.
  final bool learned;

  /// Opens the sound's page.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: learned ? '$symbol, learned' : symbol,
      child: Material(
        color: learned
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('chip-$symbol'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(symbol, style: AppTypography.ipa(context, size: 22)),
                  if (learned) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, size: 16, color: scheme.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
