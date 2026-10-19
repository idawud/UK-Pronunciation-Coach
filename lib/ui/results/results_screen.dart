import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/contracts.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import 'passage_text.dart';
import 'score_summary.dart';
import 'word_sheet.dart';

/// Width from which Results shows two panes (scores left, passage right).
const double resultsTwoPaneWidth = 720;

/// Results: overall, accuracy and fluency, the passage coloured word by word (tap a
/// word to hear it and retry it), a legend, an optional level-change message, and
/// "Fix N red words" / "Next passage".
///
/// A retried word updates here straight away and is saved through
/// `ProgressRepository.updateWordResult` (the attempt's totals stay unchanged, as in
/// the contract). With the light model tier only word scores are shown.
class ResultsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ResultsScreen({super.key, required this.args});

  /// The scored attempt and any level change.
  final ResultsArgs args;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late AttemptResult _result = widget.args.result;
  Passage? _passage;
  bool _passageFailed = false;
  bool _loadingNext = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPassage());
  }

  Future<void> _loadPassage() async {
    try {
      final p = await ref
          .read(contentRepositoryProvider)
          .byId(_result.passageId);
      if (mounted) setState(() => _passage = p);
    } catch (_) {
      if (mounted) setState(() => _passageFailed = true);
    }
  }

  bool get _light => _result.tier == ModelTier.light;

  WordSpec? _specFor(int index) {
    final p = _passage;
    if (p == null || index < 0 || index >= p.words.length) return null;
    return p.words[index];
  }

  void _replaceWord(WordResult word) {
    setState(() {
      _result = _result.copyWith(
        words: [
          for (final w in _result.words)
            if (w.index == word.index) word else w,
        ],
      );
    });
  }

  Future<void> _onRetried(WordResult word) async {
    _replaceWord(word);
    try {
      await ref
          .read(progressRepositoryProvider)
          .updateWordResult(_result.id, word);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save this retry.")),
      );
    }
  }

  Future<void> _openWord(int index) async {
    final word = _result.words.where((w) => w.index == index).firstOrNull;
    if (word == null) return;
    await WordSheet.show(
      context,
      result: word,
      word: _specFor(index),
      tier: _result.tier,
      onRetried: _onRetried,
    );
  }

  Future<void> _fixRedWords() async {
    final updated = await context.push<AttemptResult>(
      AppRoutes.fix,
      extra: FixArgs(result: _result),
    );
    if (updated != null && mounted) setState(() => _result = updated);
  }

  Future<void> _nextPassage() async {
    setState(() => _loadingNext = true);
    try {
      final next = await ref.read(practiceEngineProvider).nextPassage();
      if (!mounted) return;
      context.pushReplacement(
        AppRoutes.read,
        extra: ReadArgs(passageId: next.id),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingNext = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't choose the next passage.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = ref.watch(userProfileProvider).value?.textScale ?? 1.0;
    final passageStyle = theme.textTheme.bodyLarge!.copyWith(
      fontSize: 20 * textScale,
      height: 1.6,
    );
    final reds = _result.redWords.length;
    final change = widget.args.levelChange;

    final summary = <Widget>[
      ScoreSummary(result: _result),
      if (change != null) ...[
        const SizedBox(height: 16),
        LevelChangeCard(change: change),
      ],
      if (_light) ...[
        const SizedBox(height: 12),
        Text(
          'Light model: word scores only.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ];

    final Widget passageBody;
    if (_result.words.isEmpty) {
      passageBody = Text(
        'Nothing was scored. Try reading the passage again.',
        style: theme.textTheme.bodyLarge,
      );
    } else if (_passage == null && !_passageFailed) {
      passageBody = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      passageBody = PassageText(
        key: const Key('resultsPassage'),
        words: _result.words,
        passage: _passage,
        onWordTap: _openWord,
        style: passageStyle,
      );
    }

    final passage = <Widget>[
      if (_passage != null) ...[
        Text(_passage!.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
      ],
      passageBody,
      if (_passageFailed) ...[
        const SizedBox(height: 8),
        Text(
          "Couldn't load the passage text, so retries are off.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
      const SizedBox(height: 16),
      const ScoreLegend(),
      const SizedBox(height: 8),
      Text(
        'Tap any word to hear it and try again',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];

    final next = _loadingNext ? null : _nextPassage;
    const nextIcon = Icon(Icons.arrow_forward);
    const nextLabel = Text('Next passage');
    final buttons = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (reds > 0) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: _fixRedWords,
                icon: const Icon(Icons.build_outlined),
                label: Text(
                  reds == 1 ? 'Fix 1 red word' : 'Fix $reds red words',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: next,
                icon: nextIcon,
                label: nextLabel,
              ),
            ),
          ] else
            Expanded(
              child: FilledButton.icon(
                onPressed: next,
                icon: nextIcon,
                label: nextLabel,
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= resultsTwoPaneWidth) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: summary,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: passage,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [...summary, const SizedBox(height: 24), ...passage],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: buttons,
          ),
        ),
      ),
    );
  }
}
