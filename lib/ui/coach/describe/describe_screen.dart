import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/voice_service.dart';
import '../../../core/providers.dart';
import '../../shell/state_views.dart';
import '../../theme/theme.dart';
import '../sounds/coach_speech.dart';
import 'describe_content.dart';
import 'describe_providers.dart';

/// Coach section "Describe it": two tabs. "Describe it" shows a target word you must
/// explain without saying it, with optional hint chips and a 30-second countdown.
/// "Phrases" drills fluent phrases with normal and slow playback and a practice count.
/// Progress is saved through the Coach store; the voice is offline en-GB.
class DescribeScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DescribeScreen({super.key});

  @override
  ConsumerState<DescribeScreen> createState() => _DescribeScreenState();
}

class _DescribeScreenState extends ConsumerState<DescribeScreen> {
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Describe it'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Describe it'),
              Tab(text: 'Phrases'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DescribeTab(speech: _speech),
            _PhrasesTab(speech: _speech),
          ],
        ),
      ),
    );
  }
}

/// The "Describe it" tab: loads the saved round, then shows the body.
class _DescribeTab extends ConsumerWidget {
  const _DescribeTab({required this.speech});

  final CoachSpeech speech;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circ = ref.watch(describeCircProvider);
    if (circ.hasValue) {
      return _DescribeBody(initial: circ.requireValue, speech: speech);
    }
    if (circ.hasError) {
      return MessageView.error(
        onRetry: () => ref.invalidate(describeCircProvider),
      );
    }
    return const LoadingView();
  }
}

/// One prompt at a time. Done marks it saved for today and moves on; Skip moves on
/// without saving.
class _DescribeBody extends ConsumerStatefulWidget {
  const _DescribeBody({required this.initial, required this.speech});

  final CircState initial;
  final CoachSpeech speech;

  @override
  ConsumerState<_DescribeBody> createState() => _DescribeBodyState();
}

class _DescribeBodyState extends ConsumerState<_DescribeBody> {
  static const List<CircumlocutionPrompt> _prompts = circumlocutionPrompts;

  late Set<String> _doneIds;
  CircumlocutionPrompt? _current;
  final Set<int> _revealed = <int>{};
  int? _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _doneIds = {...widget.initial.doneIds};
    _current = pickPrompt(prompts: _prompts, doneIds: _doneIds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _moveOn({String? exclude}) {
    _stopTimer();
    unawaited(widget.speech.stop());
    _revealed.clear();
    _current = pickPrompt(
      prompts: _prompts,
      doneIds: _doneIds,
      exclude: exclude,
    );
  }

  Future<void> _done() async {
    final current = _current;
    if (current == null) return;
    final completesRound = roundComplete(
      prompts: _prompts,
      doneIds: {..._doneIds, current.id},
    );
    final next = await ref
        .read(describeRepositoryProvider)
        .markDone(current.id);
    if (!mounted) return;
    setState(() {
      _doneIds = {...next.doneIds};
      _moveOn(exclude: current.id);
    });
    if (completesRound && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Round complete. Starting again.')),
      );
    }
  }

  void _skip() {
    final current = _current;
    setState(() => _moveOn(exclude: current?.id));
  }

  void _startTimer() {
    _stopTimer();
    final ticker = ref.read(describeTimerProvider);
    setState(() => _secondsLeft = describeTimerSeconds);
    _timer = ticker(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        final left = (_secondsLeft ?? 0) - 1;
        _secondsLeft = left;
        if (left <= 0) {
          timer.cancel();
          _timer = null;
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _secondsLeft = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final current = _current;
    if (current == null) {
      return const MessageView(
        icon: Icons.info_outline,
        title: 'No prompts yet',
        message: 'Prompts will appear here.',
      );
    }
    final timerLabel = switch (_secondsLeft) {
      null => null,
      0 => "Time's up",
      final s => '$s s left',
    };
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ReadingWidth(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '${_doneIds.length} of ${_prompts.length} done this round',
            style: text.labelLarge,
          ),
        ),
        ReadingWidth(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.category.label,
                    style: text.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(current.target, style: text.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Describe it without saying the word.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < current.hints.length; i++)
                        ActionChip(
                          key: ValueKey('hint-$i'),
                          label: Text(
                            _revealed.contains(i)
                                ? current.hints[i]
                                : 'Hint ${i + 1}',
                          ),
                          onPressed: () => setState(() => _revealed.add(i)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ValueListenableBuilder<String?>(
                        valueListenable: widget.speech.playing,
                        builder: (context, playing, _) => OutlinedButton.icon(
                          onPressed: () =>
                              widget.speech.toggle('target', current.target),
                          icon: Icon(
                            playing == 'target'
                                ? Icons.stop
                                : Icons.volume_up_outlined,
                          ),
                          label: Text(
                            playing == 'target' ? 'Stop' : 'Hear the word',
                          ),
                        ),
                      ),
                      if (timerLabel != null)
                        Text(timerLabel, style: text.titleMedium),
                      if (_secondsLeft == null || _secondsLeft == 0)
                        TextButton.icon(
                          onPressed: _startTimer,
                          icon: const Icon(Icons.timer_outlined),
                          label: Text('${describeTimerSeconds}s timer'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ReadingWidth(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _skip, child: const Text('Skip')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _done,
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The "Phrases" tab: category filter, most-practised summary and one card per phrase.
class _PhrasesTab extends ConsumerStatefulWidget {
  const _PhrasesTab({required this.speech});

  final CoachSpeech speech;

  @override
  ConsumerState<_PhrasesTab> createState() => _PhrasesTabState();
}

class _PhrasesTabState extends ConsumerState<_PhrasesTab> {
  /// Selected group, or null for every phrase.
  PhraseCategory? _filter;

  Future<void> _practise(String id) async {
    await ref.read(describeRepositoryProvider).practise(id);
    ref.invalidate(chunkCountsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chunkCountsProvider);
    if (!async.hasValue) {
      return async.hasError
          ? MessageView.error(
              onRetry: () => ref.invalidate(chunkCountsProvider),
            )
          : const LoadingView();
    }
    final counts = async.requireValue;
    final top = mostPractised(counts);
    final shown = [
      for (final c in phraseChunks)
        if (_filter == null || c.category == _filter) c,
    ];
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ReadingWidth(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final category in PhraseCategory.values)
                FilterChip(
                  label: Text(category.label),
                  selected: _filter == category,
                  onSelected: (_) => setState(() => _filter = category),
                ),
            ],
          ),
        ),
        if (top.isNotEmpty)
          ReadingWidth(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Most practised', style: text.titleMedium),
                    for (final c in top)
                      Text(
                        '${c.text} · ${counts[c.id]}×',
                        style: text.bodyLarge,
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (shown.isEmpty)
          const ReadingWidth(
            padding: EdgeInsets.all(24),
            child: Text('No phrases in this group yet.'),
          ),
        for (final chunk in shown)
          ReadingWidth(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _PhraseCard(
              chunk: chunk,
              count: counts[chunk.id] ?? 0,
              speech: widget.speech,
              onPractised: () => _practise(chunk.id),
            ),
          ),
      ],
    );
  }
}

class _PhraseCard extends StatelessWidget {
  const _PhraseCard({
    required this.chunk,
    required this.count,
    required this.speech,
    required this.onPractised,
  });

  final PhraseChunk chunk;
  final int count;
  final CoachSpeech speech;
  final VoidCallback onPractised;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final normalKey = 'play:${chunk.id}';
    final slowKey = 'slow:${chunk.id}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chunk.text, style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${chunk.category.label} · practised $count×',
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: speech.playing,
                  builder: (context, playing, _) => IconButton.filledTonal(
                    tooltip: 'Play phrase',
                    onPressed: () => speech.toggle(normalKey, chunk.text),
                    icon: Icon(
                      playing == normalKey ? Icons.stop : Icons.play_arrow,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<String?>(
                  valueListenable: speech.playing,
                  builder: (context, playing, _) => IconButton.outlined(
                    tooltip: 'Play slowly',
                    onPressed: () => speech.toggle(
                      slowKey,
                      chunk.text,
                      rate: VoiceService.slowRate,
                    ),
                    icon: Icon(
                      playing == slowKey ? Icons.stop : Icons.slow_motion_video,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onPractised,
                  icon: const Icon(Icons.check),
                  label: const Text('Practised'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
