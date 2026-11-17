import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../shell/state_views.dart';
import '../../theme/theme.dart';
import 'lost_word.dart';
import 'leitner.dart';
import 'quiz_screen.dart';
import 'words_providers.dart';

/// Coach section "Words": the lost-word bank. For words that slipped away mid-sentence:
/// type the word, optionally say what you were trying to say, and review it later in
/// the quiz. Swipe a row or tap its bin to delete it.
class WordsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const WordsScreen({super.key});

  @override
  ConsumerState<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends ConsumerState<WordsScreen> {
  final _wordController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _wordController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(lostWordBankProvider);

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _add() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      _message('Type the word you lost first.');
      return;
    }
    try {
      final added = await ref
          .read(lostWordRepositoryProvider)
          .add(word, note: _noteController.text);
      if (!mounted) return;
      if (added) {
        _wordController.clear();
        _noteController.clear();
        _refresh();
        _message('Saved "$word".');
      } else {
        _message('"$word" is already in your bank.');
      }
    } on Object {
      if (mounted) _message('Could not save. Please try again.');
    }
  }

  /// Deletes [w]. Returns false to the Dismissible so the row snaps back; the reload
  /// then drops it, which keeps the widget tree consistent during the refresh.
  Future<bool> _delete(LostWord w) async {
    try {
      await ref.read(lostWordRepositoryProvider).remove(w.word);
      if (!mounted) return false;
      _refresh();
      _message('Removed "${w.word}".');
    } on Object {
      if (mounted) _message('Could not delete. Please try again.');
    }
    return false;
  }

  Future<void> _startReview(List<LostWord> due) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => WordQuizScreen(words: due)),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(lostWordBankProvider);
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: const Text('Words')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add word'),
      ),
      body: ReadingWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _AddForm(
              wordController: _wordController,
              noteController: _noteController,
              onSubmit: _add,
            ),
            const SizedBox(height: 24),
            bank.when(
              data: (b) => _BankView(
                bank: b,
                now: now,
                onStartReview: () => _startReview(b.due),
                onDelete: _delete,
              ),
              error: (_, _) => MessageView.error(onRetry: _refresh),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: LoadingView(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The word and note fields. The FAB and the keyboard's submit action both add.
class _AddForm extends StatelessWidget {
  const _AddForm({
    required this.wordController,
    required this.noteController,
    required this.onSubmit,
  });

  final TextEditingController wordController;
  final TextEditingController noteController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('A word I lost', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: wordController,
          style: theme.textTheme.headlineSmall,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'e.g. scaffold',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteController,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: 'What I was trying to say (optional)',
            hintText: 'e.g. the thing that holds up the building',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

/// Due banner, saved words, or the empty state.
class _BankView extends StatelessWidget {
  const _BankView({
    required this.bank,
    required this.now,
    required this.onStartReview,
    required this.onDelete,
  });

  final LostWordBank bank;
  final DateTime now;
  final VoidCallback onStartReview;
  final Future<bool> Function(LostWord) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueCount = bank.due.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dueCount == 0
                        ? 'Nothing due today'
                        : '$dueCount ${dueCount == 1 ? 'word' : 'words'} due now',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: dueCount == 0 ? null : onStartReview,
                  child: const Text('Start review'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (bank.words.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: MessageView(
              icon: Icons.bookmark_border,
              title: 'No lost words yet',
              message:
                  'When a word slips away mid-sentence, type it above. Add what '
                  'you were trying to say, then review it here.',
            ),
          )
        else ...[
          Text(
            'Saved words (${bank.words.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final w in bank.words)
            _WordRow(
              key: ValueKey(w.key),
              word: w,
              now: now,
              onDelete: () => onDelete(w),
            ),
        ],
      ],
    );
  }
}

/// One saved word: swipe to delete, or tap the bin.
class _WordRow extends StatelessWidget {
  const _WordRow({
    super.key,
    required this.word,
    required this.now,
    required this.onDelete,
  });

  final LostWord word;
  final DateTime now;
  final Future<bool> Function() onDelete;

  String _dueText() {
    if (isDue(word, now)) return 'Due now';
    final days = word.due.difference(now).inHours / 24;
    final rounded = days.ceil();
    if (rounded <= 1) return 'Due tomorrow';
    return 'Due in $rounded days';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = word.note;
    return Dismissible(
      key: ValueKey('dismiss-${word.key}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => onDelete(),
      child: Card(
        child: ListTile(
          title: Text(word.word, style: theme.textTheme.titleLarge),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (note != null) Text(note),
              Text(_dueText()),
              Text('Box ${word.box} of 5'),
            ],
          ),
          isThreeLine: note != null,
          trailing: IconButton(
            tooltip: 'Delete word',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onDelete(),
          ),
        ),
      ),
    );
  }
}
