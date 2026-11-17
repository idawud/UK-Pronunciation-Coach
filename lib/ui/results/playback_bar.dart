import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import 'playback_controller.dart';
import 'speech_segments.dart';

/// Three play buttons for the attempt's passage: the whole sentence, the stressed
/// passage (non-good words slowed) and only the wrong words.
///
/// The button for the active [PlaybackKind] shows a stop icon. The mistakes-only
/// button is disabled when every word is good.
class PlaybackBar extends StatelessWidget {
  /// Creates the bar for [words], playing through [player].
  const PlaybackBar({super.key, required this.words, required this.player});

  /// The scored words of the attempt.
  final List<WordResult> words;

  /// Shared player that runs the speech and reports the active kind.
  final SegmentPlayer player;

  @override
  Widget build(BuildContext context) {
    final hasWrong = wrongWordsSegments(words).isNotEmpty;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final active = player.active;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _button(
              kind: PlaybackKind.sentence,
              icon: Icons.play_arrow,
              tooltip: 'Play sentence',
              active: active,
              segments: () => fullSentenceSegments(words),
            ),
            _button(
              kind: PlaybackKind.stressed,
              icon: Icons.record_voice_over,
              tooltip: 'Play with stressed words slowed',
              active: active,
              segments: () => stressedSegments(words),
            ),
            _button(
              kind: PlaybackKind.wrongWords,
              icon: Icons.spellcheck,
              tooltip: 'Play mistakes only',
              active: active,
              enabled: hasWrong,
              segments: () => wrongWordsSegments(words),
            ),
          ],
        );
      },
    );
  }

  Widget _button({
    required PlaybackKind kind,
    required IconData icon,
    required String tooltip,
    required PlaybackKind? active,
    required List<SpeechSegment> Function() segments,
    bool enabled = true,
  }) {
    final isActive = active == kind;
    return IconButton.filledTonal(
      tooltip: tooltip,
      isSelected: isActive,
      icon: Icon(isActive ? Icons.stop : icon),
      onPressed: enabled ? () => player.play(kind, segments()) : null,
    );
  }
}
