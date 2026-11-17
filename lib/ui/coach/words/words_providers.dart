import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/coach/coach_store.dart';
import 'lost_word.dart';
import 'lost_word_repository.dart';

/// The lost-word bank over the Coach store and the app clock.
final lostWordRepositoryProvider = Provider<LostWordRepository>(
  (ref) => LostWordRepository(
    store: ref.watch(coachStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Snapshot of the bank: every word (newest first) and the words due now.
typedef LostWordBank = ({List<LostWord> words, List<LostWord> due});

/// Loads the bank. Invalidate it after any add, review or removal.
final lostWordBankProvider = FutureProvider.autoDispose<LostWordBank>((
  ref,
) async {
  final repo = ref.watch(lostWordRepositoryProvider);
  final words = await repo.list();
  final due = await repo.dueNow();
  return (words: words, due: due);
});
