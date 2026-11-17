import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../data/coach/coach_store.dart';
import 'confusion_logic.dart';
import 'daily_session.dart';

/// Coach store key that holds this section's streak.
const String confusionsStoreKey = 'confusions';

/// Attempts older than this are not counted as confusions.
const Duration confusionWindow = Duration(days: 60);

/// Most attempts loaded for the confusion count.
const int confusionAttemptLimit = 1000;

/// Everything the Confusions screen and the session need, loaded once per progress
/// write.
class ConfusionsData {
  /// Creates the data.
  const ConfusionsData({
    required this.confusions,
    required this.pairs,
    required this.soundStats,
    required this.streak,
  });

  /// Confusions seen at least twice in the window, most frequent first.
  final List<Confusion> confusions;

  /// All minimal pairs from the bundled content.
  final List<MinimalPair> pairs;

  /// Sound stats, weakest first.
  final List<SoundStat> soundStats;

  /// Streak to show today (0 when the last session was before yesterday).
  final int streak;
}

/// Reads the streak from the Coach store. A corrupt or unreadable value counts as no
/// streak.
Future<SessionStreak> readSessionStreak(CoachStore store) async {
  try {
    return SessionStreak.fromJson(await store.read(confusionsStoreKey));
  } on Object {
    return const SessionStreak();
  }
}

/// The Confusions screen data. Refreshes after every progress write.
final confusionsDataProvider = FutureProvider.autoDispose<ConfusionsData>((
  ref,
) async {
  ref.watch(progressChangesProvider);
  final now = ref.watch(clockProvider)();
  final since = now.subtract(confusionWindow);
  final progress = ref.watch(progressRepositoryProvider);
  final attempts = await progress.attempts(
    since: since,
    limit: confusionAttemptLimit,
  );
  final stats = await progress.soundStats();
  final pairs = await ref.watch(contentRepositoryProvider).minimalPairs();
  final streak = await readSessionStreak(ref.watch(coachStoreProvider));
  return ConfusionsData(
    confusions: buildConfusions(attempts, since: since),
    pairs: pairs,
    soundStats: stats,
    streak: streak.currentAt(now),
  );
});

/// Today's session steps, built from [confusionsDataProvider].
final dailySessionProvider = FutureProvider.autoDispose<List<SessionStep>>((
  ref,
) async {
  final data = await ref.watch(confusionsDataProvider.future);
  return buildDailySession(
    data.confusions,
    data.pairs,
    soundStats: data.soundStats,
  );
});
