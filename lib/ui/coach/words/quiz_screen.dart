import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/voice_service.dart';
import '../../../core/providers.dart';
import '../../shell/state_views.dart';
import '../../theme/theme.dart';
import 'lost_word.dart';
import 'words_providers.dart';

/// Review quiz for the lost-word bank. Each card shows the note (what the user was
/// trying to say); the user thinks of the word, then taps Reveal, which speaks it with
/// the offline en-GB voice and shows it. "I knew it" or "Didn't" is saved at once with
/// the Leitner rules, so an answer survives leaving the screen.
///
/// Works through the [words] it was given (a snapshot of what was due), so a word
/// missed here is not asked again in the same session.
class WordQuizScreen extends ConsumerStatefulWidget {
  /// Creates the quiz over [words], in the order to ask them.
  const WordQuizScreen({super.key, required this.words});

  /// Words to review, in order.
  final List<LostWord> words;

  @override
  ConsumerState<WordQuizScreen> createState() => _WordQuizScreenState();
}

class _WordQuizScreenState extends ConsumerState<WordQuizScreen> {
  /// Captured in `initState` so speech can be stopped in `dispose` without a ref.
  late final VoiceService _voice;

  int _index = 0;
  int _recalled = 0;
  int _missed = 0;
  bool _revealed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceServiceProvider);
  }

  @override
  void dispose() {
    unawaited(_voice.stop().catchError((Object _) {}));
    super.dispose();
  }

  bool get _finished => _index >= widget.words.length;

  void _speak(String word) {
    unawaited(_voice.speak(word).catchError((Object _) {}));
  }

  void _reveal(LostWord w) {
    setState(() => _revealed = true);
    _speak(w.word);
  }

  Future<void> _answer(LostWord w, {required bool recalled}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(lostWordRepositoryProvider)
          .review(w.word, recalled: recalled);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that answer. Try again.')),
      );
      return;
    }
    if (!mounted) return;
    unawaited(_voice.stop().catchError((Object _) {}));
    setState(() {
      if (recalled) {
        _recalled++;
      } else {
        _missed++;
      }
      _index++;
      _revealed = false;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: widget.words.isEmpty
          ? MessageView(
              icon: Icons.task_alt,
              title: 'Nothing due right now',
              message: 'Words come back here when they are due.',
              actionLabel: 'Back',
              onAction: () => Navigator.of(context).pop(),
            )
          : _finished
          ? _Finished(
              recalled: _recalled,
              missed: _missed,
              onDone: () => Navigator.of(context).pop(),
            )
          : _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.words.length;
    final w = widget.words[_index];
    final note = w.note;
    return ReadingWidth(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Word ${_index + 1} of $total',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _index / total),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'What I was trying to say',
                      style: theme.textTheme.labelLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      note ??
                          'No note saved. Picture the sentence you were in.',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (_revealed) ...[
                      const SizedBox(height: 32),
                      Text(
                        w.word,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      TextButton.icon(
                        onPressed: () => _speak(w.word),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('Hear it again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!_revealed)
            FilledButton.icon(
              onPressed: () => _reveal(w),
              icon: const Icon(Icons.volume_up),
              label: const Text('Reveal'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => _answer(w, recalled: false),
                    child: const Text("Didn't"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () => _answer(w, recalled: true),
                    child: const Text('I knew it'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Summary shown after the last word.
class _Finished extends StatelessWidget {
  const _Finished({
    required this.recalled,
    required this.missed,
    required this.onDone,
  });

  final int recalled;
  final int missed;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReadingWidth(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.task_alt, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Review finished',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Knew it: $recalled. Didn\'t: $missed.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (missed > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Missed words are due again now.',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}
