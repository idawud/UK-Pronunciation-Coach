import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/content_repository.dart';
import '../../core/contracts/navigation.dart';
import '../../core/contracts/progress_repository.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';

/// Everything the Practise tab shows.
class PractiseData {
  /// Creates the data.
  const PractiseData({
    required this.level,
    required this.passages,
    required this.sounds,
    required this.due,
  });

  /// Current level, 1-6.
  final int level;

  /// Library passages, by level then id.
  final List<Passage> passages;

  /// Sound stats, weakest first.
  final List<SoundStat> sounds;

  /// Review items due now, soonest first.
  final List<ReviewItem> due;

  /// Passages at levels above `level + 1` are locked.
  bool isLocked(int passageLevel) => passageLevel > level + 1;
}

/// How many weak sounds the Practise tab lists.
const int practiseSoundCount = 12;

/// Practise data; refreshes after every progress write.
final practiseDataProvider = FutureProvider.autoDispose<PractiseData>((
  ref,
) async {
  ref.watch(progressChangesProvider);
  final engine = ref.watch(practiceEngineProvider);
  return PractiseData(
    level: await engine.currentLevel(),
    passages: await ref.watch(contentRepositoryProvider).all(),
    sounds: await engine.weakestSounds(count: practiseSoundCount),
    due: await engine.dueReviews(),
  );
});

/// Where tapping a due word goes: Fix a word on the latest attempt containing it, or,
/// when no attempt has it, a word retry in the Read screen for its passage. Null when
/// neither is possible.
Future<({String path, Object extra})?> reviewTargetFor(
  ReviewItem item, {
  required ProgressRepository progress,
  required ContentRepository content,
}) async {
  final attempts = item.passageId == null
      ? await progress.attempts(limit: 50)
      : await progress.attempts(passageId: item.passageId, limit: 10);
  for (final a in attempts) {
    for (final w in a.words) {
      if (w.text.toLowerCase() == item.key) {
        return (
          path: AppRoutes.fix,
          extra: FixArgs(result: a, wordIndexes: [w.index]),
        );
      }
    }
  }
  final passageId = item.passageId;
  if (passageId == null) return null;
  try {
    final passage = await content.byId(passageId);
    for (final w in passage.words) {
      if (w.text.toLowerCase() == item.key && w.scorable) {
        return (
          path: AppRoutes.read,
          extra: ReadArgs(
            passageId: passageId,
            mode: ReadMode.word,
            wordIndex: w.index,
          ),
        );
      }
    }
  } on Object {
    return null;
  }
  return null;
}
