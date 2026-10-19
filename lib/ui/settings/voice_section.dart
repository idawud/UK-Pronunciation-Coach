import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'settings_providers.dart';

/// Sentence spoken by "Play a sample".
const String voiceSample =
    'Hello. This is how your British model voice sounds.';

/// British voice check: the voice in use with a sample, or how to install an
/// English (UK) voice when none is available.
class VoiceSection extends ConsumerWidget {
  /// Creates the section.
  const VoiceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(voiceStatusProvider);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      AsyncData(:final value) when value.hasBritishVoice => ListTile(
        leading: Icon(Icons.record_voice_over_outlined, color: scheme.primary),
        title: const Text('British voice ready'),
        subtitle: Text(value.name ?? 'English (United Kingdom)'),
        trailing: TextButton(
          onPressed: () => ref.read(voiceServiceProvider).speak(voiceSample),
          child: const Text('Play a sample'),
        ),
      ),
      AsyncData() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_outlined, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('No British voice found', style: t.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'To hear words in a British accent, install an English (United '
              'Kingdom) voice. It works offline once installed.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(_installSteps(), style: t.bodyMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(voiceStatusProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Check again'),
            ),
          ],
        ),
      ),
      AsyncError() => ListTile(
        leading: Icon(Icons.error_outline, color: scheme.error),
        title: const Text("Couldn't check the voice"),
        trailing: TextButton(
          onPressed: () => ref.invalidate(voiceStatusProvider),
          child: const Text('Try again'),
        ),
      ),
      _ => const ListTile(
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Checking for a British voice…'),
      ),
    };
  }
}

String _installSteps() {
  final platform = defaultTargetPlatform;
  return platform == TargetPlatform.iOS
      ? 'On iPhone: Settings > Accessibility > Spoken Content > Voices > '
            'English > English (UK), then download a voice.'
      : 'On Android: Settings > System > Languages > Text-to-speech output > '
            'the settings icon next to your engine > Install voice data > '
            'English (United Kingdom).';
}
