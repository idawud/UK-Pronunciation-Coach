import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import 'level_info.dart';

/// Everything the Home screen shows, loaded together.
class HomeData {
  /// Creates the data.
  const HomeData({
    required this.level,
    required this.daily,
    required this.weakSounds,
    required this.dueWords,
    required this.levelUpRun,
  });

  /// Current level, 1-6.
  final int level;

  /// Streak and today's minutes.
  final DailyProgress daily;

  /// Up to 3 weakest sounds, weakest first.
  final List<SoundStat> weakSounds;

  /// Words due for review now.
  final List<String> dueWords;

  /// Latest passages in a row at 85+ since the last level change (0-3).
  final int levelUpRun;

  /// Progress towards the next level, 0-1.
  double get levelProgress => level >= LevelInfo.maxLevel
      ? 1
      : (levelUpRun / LevelInfo.levelUpRun).clamp(0, 1).toDouble();
}

/// Counts the newest [attempts] (newest first) at 85+ made after [since].
int levelUpRunOf(List<AttemptResult> attempts, DateTime? since) {
  var run = 0;
  for (final a in attempts) {
    if (since != null && !a.at.isAfter(since)) break;
    if (a.overall < LevelInfo.levelUpScore) break;
    run++;
  }
  return run.clamp(0, LevelInfo.levelUpRun);
}

/// Home data from the practice engine and progress store; refreshes after every
/// progress write.
final homeDataProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  ref.watch(progressChangesProvider);
  final engine = ref.watch(practiceEngineProvider);
  final progress = ref.watch(progressRepositoryProvider);
  final history = await progress.levelHistory();
  final recent = await progress.attempts(limit: LevelInfo.levelUpRun);
  return HomeData(
    level: await engine.currentLevel(),
    daily: await engine.dailyProgress(),
    weakSounds: await engine.weakestSounds(count: 3),
    dueWords: await engine.dueReviewWords(),
    levelUpRun: levelUpRunOf(recent, history.isEmpty ? null : history.last.at),
  );
});
