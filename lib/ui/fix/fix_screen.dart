import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/contracts.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../results/passage_text.dart';
import '../results/word_status_style.dart';
import 'word_practice.dart';

/// Target score for a fixed word.
const int fixTarget = WordStatus.defaultGood;

enum _Phase { loading, error, empty, word, sentence, done }

/// Fix a word: steps through the red words of an attempt. For each word: the word,
/// expected vs heard IPA, sound chips with the wrong sound marked, a tip, Play British /
/// Play slowly, hold-to-record and last score vs target 80. The user repeats until 80+
/// or skips. After the last word of a sentence that was fixed, the user reads that
/// sentence once (Read route, [ReadMode.sentence]).
///
/// Each word's last try is saved through `ProgressRepository.updateWordResult` when
/// the user moves on. The screen pops with the updated [AttemptResult] so Results can
/// refresh its colours. Sentence readings are shown but not saved.
class FixScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const FixScreen({super.key, required this.args});

  /// The attempt and words to fix.
  final FixArgs args;

  @override
  ConsumerState<FixScreen> createState() => _FixScreenState();
}

class _FixScreenState extends ConsumerState<FixScreen> {
  late AttemptResult _result = widget.args.result;
  late final List<int> _indexes =
      widget.args.wordIndexes ?? [for (final w in _result.redWords) w.index];
  late final Map<int, WordResult> _original = {
    for (final w in widget.args.result.words) w.index: w,
  };

  Passage? _passage;
  _Phase _phase = _Phase.loading;
  int _step = 0;
  int _tries = 0;
  final Set<int> _fixed = {};

  ({int start, int end})? _sentence;
  int? _sentenceWord;
  AttemptResult? _sentenceResult;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final p = await ref
          .read(contentRepositoryProvider)
          .byId(_result.passageId);
      final valid = _indexes.every(
        (i) => i >= 0 && i < p.words.length && _wordResult(i) != null,
      );
      if (!mounted) return;
      setState(() {
        _passage = p;
        _phase = !valid
            ? _Phase.error
            : _indexes.isEmpty
            ? _Phase.empty
            : _Phase.word;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  WordResult? _wordResult(int index) =>
      _result.words.where((w) => w.index == index).firstOrNull;

  int get _index => _indexes[_step];

  WordResult get _current => _wordResult(_index)!;

  bool get _light => _result.tier == ModelTier.light;

  void _onScored(WordResult r) {
    setState(() {
      _tries++;
      _result = _result.copyWith(
        words: [
          for (final w in _result.words)
            if (w.index == r.index) r else w,
        ],
      );
      if (r.score >= fixTarget) _fixed.add(r.index);
    });
  }

  Future<void> _save(WordResult word) async {
    try {
      await ref
          .read(progressRepositoryProvider)
          .updateWordResult(_result.id, word);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't save your try at \"${word.text}\".")),
      );
    }
  }

  Future<void> _finishWord() async {
    final index = _index;
    if (_tries > 0) await _save(_current);
    if (!mounted) return;
    final range = _passage!.sentenceRange(index);
    final hasNext = _step + 1 < _indexes.length;
    final nextInSentence =
        hasNext &&
        _indexes[_step + 1] >= range.start &&
        _indexes[_step + 1] < range.end;
    final fixedHere = _fixed.where((i) => i >= range.start && i < range.end);
    setState(() {
      if (!nextInSentence && fixedHere.isNotEmpty) {
        _phase = _Phase.sentence;
        _sentence = range;
        _sentenceWord = fixedHere.last;
        _sentenceResult = null;
      } else {
        _advance();
      }
    });
  }

  /// Moves to the next word or the end. Call inside setState.
  void _advance() {
    _tries = 0;
    _sentence = null;
    _sentenceResult = null;
    if (_step + 1 < _indexes.length) {
      _step++;
      _phase = _Phase.word;
    } else {
      _phase = _Phase.done;
    }
  }

  Future<void> _readSentence() async {
    final r = await context.push<AttemptResult>(
      AppRoutes.read,
      extra: ReadArgs(
        passageId: _passage!.id,
        mode: ReadMode.sentence,
        wordIndex: _sentenceWord,
      ),
    );
    if (!mounted) return;
    if (r == null) {
      setState(_advance);
    } else {
      setState(() => _sentenceResult = r);
    }
  }

  void _close() => Navigator.of(context).pop(_result);

  @override
  Widget build(BuildContext context) {
    return PopScope<AttemptResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fix a word'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Back to results',
            onPressed: _close,
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _body(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) => switch (_phase) {
    _Phase.loading => const Center(child: CircularProgressIndicator()),
    _Phase.error => _Message(
      icon: Icons.error_outline,
      text: "Couldn't load these words. Go back and try again.",
      action: 'Back to results',
      onAction: _close,
    ),
    _Phase.empty => _Message(
      icon: Icons.check_circle_outline,
      text: 'No red words to fix. Nice reading!',
      action: 'Back to results',
      onAction: _close,
    ),
    _Phase.word => _wordStep(context),
    _Phase.sentence => _sentenceStep(context),
    _Phase.done => _doneStep(context),
  };

  Widget _wordStep(BuildContext context) {
    final theme = Theme.of(context);
    final current = _current;
    final reached = current.score >= fixTarget;
    final lastLabel = _tries == 0 ? 'Reading score' : 'Last score';
    return ListView(
      key: ValueKey('fix-word-$_index'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Word ${_step + 1} of ${_indexes.length}',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (_step + (reached ? 1 : 0)) / _indexes.length,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 16),
        WordPractice(
          result: current,
          word: _passage!.words[_index],
          onScored: _onScored,
          lightTier: _light,
          tier: _result.tier,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$lastLabel ', style: theme.textTheme.titleMedium),
            ScoreBadge(score: current.score, status: current.status),
            Text(
              '  Target $fixTarget',
              style: theme.textTheme.titleMedium,
              key: const Key('fixTarget'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_tries > 0)
          Text(
            reached
                ? 'Well done! That sounds British.'
                : 'Not quite yet. Listen again and have another go.',
            key: const Key('fixFeedback'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (reached)
              FilledButton.icon(
                onPressed: _finishWord,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              )
            else
              TextButton.icon(
                onPressed: _finishWord,
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sentenceStep(BuildContext context) {
    final theme = Theme.of(context);
    final range = _sentence!;
    final r = _sentenceResult;
    return ListView(
      key: const ValueKey('fix-sentence'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          r == null ? 'Now say the whole sentence' : 'Your sentence',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        if (r == null)
          Text(
            'Read it once with the fixed word in it.',
            style: theme.textTheme.bodyLarge,
          ),
        const SizedBox(height: 16),
        PassageText(
          key: const Key('fixSentence'),
          passage: _passage,
          // Before reading: the fixed words' latest scores; after: the sentence's.
          words: r?.words ?? _result.words,
          start: range.start,
          end: range.end,
        ),
        if (r != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Sentence score ', style: theme.textTheme.titleMedium),
              ScoreBadge(
                score: r.overall,
                status: WordStatus.fromScore(r.overall),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (r == null) ...[
              TextButton(
                onPressed: () => setState(_advance),
                child: const Text('Skip'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _readSentence,
                icon: const Icon(Icons.mic_none),
                label: const Text('Read the sentence'),
              ),
            ] else
              FilledButton.icon(
                onPressed: () => setState(_advance),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _doneStep(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey('fix-done'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Fixed ${_fixed.length} of ${_indexes.length} '
          '${_indexes.length == 1 ? 'word' : 'words'}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        for (final i in _indexes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_wordResult(i)!.text),
            subtitle: Text('Was ${_original[i]?.score ?? 0}'),
            trailing: ScoreBadge(
              score: _wordResult(i)!.score,
              status: _wordResult(i)!.status,
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _close, child: const Text('Back to results')),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
