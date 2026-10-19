import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../fix/word_practice.dart';

/// Bottom sheet for one word on Results: expected vs heard IPA, score, play buttons
/// and a hold-to-record retry. Each retry updates the sheet and calls [onRetried].
class WordSheet extends StatefulWidget {
  /// Creates the sheet for [result].
  const WordSheet({
    super.key,
    required this.result,
    required this.word,
    required this.onRetried,
    this.tier = ModelTier.full,
  });

  /// The word's current result.
  final WordResult result;

  /// The word's passage spec; null when the passage could not be loaded.
  final WordSpec? word;

  /// Called with each scored retry.
  final ValueChanged<WordResult> onRetried;

  /// Tier of the attempt; light hides per-sound detail.
  final ModelTier tier;

  /// Opens the sheet.
  static Future<void> show(
    BuildContext context, {
    required WordResult result,
    required WordSpec? word,
    required ValueChanged<WordResult> onRetried,
    ModelTier tier = ModelTier.full,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (_) =>
        WordSheet(result: result, word: word, onRetried: onRetried, tier: tier),
  );

  @override
  State<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<WordSheet> {
  late WordResult _result = widget.result;
  bool _retried = false;

  void _onScored(WordResult r) {
    setState(() {
      _result = r;
      _retried = true;
    });
    widget.onRetried(r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          WordPractice(
            result: _result,
            word: widget.word,
            onScored: _onScored,
            lightTier: widget.tier == ModelTier.light,
            tier: widget.tier,
          ),
          if (_retried) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                _result.score >= WordStatus.defaultGood
                    ? 'Saved. Well done!'
                    : 'Saved. Listen again and have another go.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
