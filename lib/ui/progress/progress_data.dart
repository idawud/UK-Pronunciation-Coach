import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';

/// Everything the Progress screen shows, loaded in one go.
class ProgressData {
  /// Creates the data.
  const ProgressData({
    required this.level,
    required this.attempts,
    required this.levelHistory,
    required this.soundStats,
    required this.daily,
    required this.today,
  });

  /// Current level, 1-6.
  final int level;

  /// Recent passage attempts, oldest first (for the trend chart).
  final List<AttemptResult> attempts;

  /// Level changes, oldest first.
  final List<LevelChange> levelHistory;

  /// Sound accuracy, weakest first.
  final List<SoundStat> soundStats;

  /// Streak, minutes today, goal and practised days.
  final DailyProgress daily;

  /// Today's local date (midnight), for the streak calendar.
  final DateTime today;

  /// True for a new user with nothing to show yet.
  bool get isEmpty =>
      attempts.isEmpty && levelHistory.isEmpty && daily.practisedDays.isEmpty;

  /// Whether the newest attempt was scored with the light model (word scores only).
  bool get lightTierOnly =>
      attempts.isNotEmpty && attempts.last.tier == ModelTier.light;
}

/// How many attempts the trend chart shows at most.
const int trendAttemptLimit = 30;

/// Loads [ProgressData]; refreshes after every progress write.
final progressDataProvider = FutureProvider<ProgressData>((ref) async {
  ref.watch(progressChangesProvider);
  final repo = ref.watch(progressRepositoryProvider);
  final engine = ref.watch(practiceEngineProvider);
  final now = ref.watch(clockProvider)();
  final results = await Future.wait<Object>([
    engine.currentLevel(),
    repo.attempts(limit: trendAttemptLimit),
    repo.levelHistory(),
    repo.soundStats(),
    engine.dailyProgress(),
  ]);
  return ProgressData(
    level: results[0] as int,
    attempts: (results[1] as List<AttemptResult>).reversed.toList(),
    levelHistory: results[2] as List<LevelChange>,
    soundStats: results[3] as List<SoundStat>,
    daily: results[4] as DailyProgress,
    today: DateTime(now.year, now.month, now.day),
  );
});

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats [d] as "12 Oct 2026" (British order, no locale data needed).
String formatDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Formats [d] as "12 Oct".
String formatShortDay(DateTime d) => '${d.day} ${_months[d.month - 1]}';
