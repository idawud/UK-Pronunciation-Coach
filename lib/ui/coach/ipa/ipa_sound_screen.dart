import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/voice_service.dart';
import '../../../core/providers.dart';
import '../../theme/theme.dart';
import '../sounds/coach_speech.dart';
import 'ipa_content.dart';
import 'ipa_providers.dart';
import 'ipa_quiz.dart';

/// Detail page for one IPA sound: the symbol, example words (normal and slow), the
/// mouth tip, the common mistake, a contrast pair and a Quick check.
///
/// The voice cannot say a single sound reliably, so every play button speaks a whole
/// example word that contains the sound.
class IpaSoundScreen extends ConsumerStatefulWidget {
  /// Creates the page for [sound].
  const IpaSoundScreen({super.key, required this.sound});

  /// The sound to show.
  final IpaSound sound;

  @override
  ConsumerState<IpaSoundScreen> createState() => _IpaSoundScreenState();
}

class _IpaSoundScreenState extends ConsumerState<IpaSoundScreen> {
  /// Captured here so speech can be stopped in [dispose] without a ref.
  late final VoiceService _voice;
  late final CoachSpeech _speech;
  late final Random _random;

  /// Null while the saved state loads.
  bool? _learned;

  IpaQuizQuestion? _question;
  String? _picked;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceServiceProvider);
    _speech = CoachSpeech(_voice);
    _random = ref.read(ipaRandomProvider);
    unawaited(_loadLearned());
  }

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }

  Future<void> _loadLearned() async {
    final learned = await ref.read(ipaRepositoryProvider).loadLearned();
    if (!mounted) return;
    setState(() => _learned = learned.contains(widget.sound.symbol));
  }

  Future<void> _toggleLearned() async {
    final next = !(_learned ?? false);
    // Captured before the await: the container outlives this widget's ref.
    final container = ProviderScope.containerOf(context);
    setState(() => _learned = next);
    await ref.read(ipaRepositoryProvider).setLearned(widget.sound.symbol, next);
    container.invalidate(ipaLearnedProvider);
  }

  void _startQuiz() {
    setState(() {
      _question = buildIpaQuizQuestion(
        target: widget.sound,
        pool: ipaSoundsIn(widget.sound.group),
        random: _random,
      );
      _picked = null;
    });
  }

  void _answer(String option) {
    if (_picked != null) return;
    setState(() => _picked = option);
  }

  @override
  Widget build(BuildContext context) {
    final sound = widget.sound;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lexical = sound.lexicalSet ?? sound.manner?.label ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(sound.group.label)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      sound.symbol,
                      key: const ValueKey('ipa-symbol'),
                      style: AppTypography.ipa(context, size: 72),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lexical,
                      style: text.labelLarge?.copyWith(color: scheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text('as in "${sound.keyword}"', style: text.bodyLarge),
                    if (sound.voiced != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        sound.voiced!
                            ? 'Voiced: your vocal cords buzz'
                            : 'Voiceless: your vocal cords stay still',
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      key: const ValueKey('learned-toggle'),
                      onPressed: _learned == null ? null : _toggleLearned,
                      icon: Icon(
                        _learned == true
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                      ),
                      label: Text(
                        _learned == true ? 'Learned' : 'Mark as learned',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Example words', style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'The voice speaks whole words, because a single sound cannot '
                      'be spoken reliably on its own. Listen for the highlighted sound.',
                      style: text.bodySmall,
                    ),
                    for (var i = 0; i < sound.examples.length; i++)
                      _ExampleRow(
                        index: i,
                        example: sound.examples[i],
                        speech: _speech,
                      ),
                  ],
                ),
              ),
            ),
          ),
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _TextCard(title: 'How to make it', body: sound.mouthTip),
          ),
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _TextCard(title: 'Common mistake', body: sound.pitfall),
          ),
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _ContrastCard(
              contrast: sound.contrast,
              symbol: sound.symbol,
              speech: _speech,
            ),
          ),
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _QuizCard(
              question: _question,
              picked: _picked,
              speech: _speech,
              onStart: _startQuiz,
              onAnswer: _answer,
              onNext: _startQuiz,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium),
            const SizedBox(height: 6),
            Text(body, style: text.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// One example word: the spelling with the sound in bold, then normal and slow play.
class _ExampleRow extends StatelessWidget {
  const _ExampleRow({
    required this.index,
    required this.example,
    required this.speech,
  });

  final int index;
  final IpaExample example;
  final CoachSpeech speech;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final word = example.word;
    final start = example.highlightStart;
    final end = example.highlightEnd;
    final normalKey = 'ex-normal-$index';
    final slowKey = 'ex-slow-$index';
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: word.substring(0, start)),
                TextSpan(
                  text: word.substring(start, end),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: word.substring(end)),
              ],
            ),
            style: text.titleLarge,
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: speech.playing,
          builder: (context, playing, _) => IconButton(
            key: ValueKey(normalKey),
            tooltip: 'Play $word',
            onPressed: () =>
                speech.toggle(normalKey, word, rate: VoiceService.normalRate),
            icon: Icon(playing == normalKey ? Icons.stop : Icons.play_arrow),
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: speech.playing,
          builder: (context, playing, _) => IconButton(
            key: ValueKey(slowKey),
            tooltip: 'Play $word slowly',
            onPressed: () =>
                speech.toggle(slowKey, word, rate: VoiceService.slowRate),
            icon: Icon(
              playing == slowKey ? Icons.stop : Icons.slow_motion_video,
            ),
          ),
        ),
      ],
    );
  }
}

/// The contrast pair, each word with its own play button.
class _ContrastCard extends StatelessWidget {
  const _ContrastCard({
    required this.contrast,
    required this.symbol,
    required this.speech,
  });

  final IpaContrast contrast;
  final String symbol;
  final CoachSpeech speech;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final other = contrast.otherSymbol;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Often confused with', style: text.titleMedium),
            const SizedBox(height: 6),
            Text(
              other == null
                  ? '/$symbol/ against no sound at all'
                  : '/$symbol/ and /$other/',
              style: text.bodyLarge,
            ),
            _WordPlayRow(
              playKey: 'contrast-a',
              word: contrast.word,
              speech: speech,
            ),
            _WordPlayRow(
              playKey: 'contrast-b',
              word: contrast.otherWord,
              speech: speech,
            ),
          ],
        ),
      ),
    );
  }
}

class _WordPlayRow extends StatelessWidget {
  const _WordPlayRow({
    required this.playKey,
    required this.word,
    required this.speech,
  });

  final String playKey;
  final String word;
  final CoachSpeech speech;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(word, style: Theme.of(context).textTheme.titleLarge),
      ),
      ValueListenableBuilder<String?>(
        valueListenable: speech.playing,
        builder: (context, playing, _) => IconButton.filledTonal(
          key: ValueKey(playKey),
          tooltip: 'Play $word',
          onPressed: () => speech.toggle(playKey, word),
          icon: Icon(playing == playKey ? Icons.stop : Icons.play_arrow),
        ),
      ),
    ],
  );
}

/// Quick check: hear a word, choose the sound it contains, then see the answer.
class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.question,
    required this.picked,
    required this.speech,
    required this.onStart,
    required this.onAnswer,
    required this.onNext,
  });

  final IpaQuizQuestion? question;
  final String? picked;
  final CoachSpeech speech;
  final VoidCallback onStart;
  final ValueChanged<String> onAnswer;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final q = question;
    final answered = picked != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick check', style: text.titleMedium),
            const SizedBox(height: 6),
            if (q == null) ...[
              Text(
                'Hear a word and choose the sound it contains.',
                style: text.bodyLarge,
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('quiz-start'),
                onPressed: onStart,
                child: const Text('Start'),
              ),
            ] else ...[
              Text(
                'Which sound is in the word you hear?',
                style: text.bodyLarge,
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String?>(
                valueListenable: speech.playing,
                builder: (context, playing, _) => OutlinedButton.icon(
                  key: const ValueKey('quiz-play'),
                  onPressed: () => speech.toggle('quiz', q.word),
                  icon: Icon(
                    playing == 'quiz' ? Icons.stop : Icons.volume_up_outlined,
                  ),
                  label: Text(playing == 'quiz' ? 'Stop' : 'Hear the word'),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in q.options)
                    ChoiceChip(
                      key: ValueKey('quiz-option-$option'),
                      label: Text(
                        '/$option/',
                        style: AppTypography.ipa(context, size: 18),
                      ),
                      selected: picked == option,
                      onSelected: answered ? null : (_) => onAnswer(option),
                    ),
                ],
              ),
              if (answered) ...[
                const SizedBox(height: 12),
                Text(
                  picked == q.answer
                      ? "Correct. '${q.word}' contains /${q.answer}/."
                      : "Not quite. '${q.word}' contains /${q.answer}/, "
                            'not /$picked/.',
                  key: const ValueKey('quiz-feedback'),
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey('quiz-next'),
                  onPressed: onNext,
                  child: const Text('Next'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
