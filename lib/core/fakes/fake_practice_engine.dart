import '../contracts/clock.dart';
import '../contracts/content_repository.dart';
import '../contracts/practice_engine.dart';
import '../contracts/progress_repository.dart';
import '../models/models.dart';

/// Simple working [PracticeEngine] over any content and progress repositories.
///
/// Implements the documented rules plainly (no weighting or randomness): C3 builds the
/// real one. Good enough for screens and for the shared contract suite.
class FakePracticeEngine implements PracticeEngine {
  /// Creates the engine.
  FakePracticeEngine({
    required this._content,
    required this._progress,
    this._clock = systemClock,
  });

  final ContentRepository _content;
  final ProgressRepository _progress;
  final Clock _clock;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  Future<int> currentLevel() async => (await _progress.profile()).level;

  @override
  Future<Passage> nextPassage({String? soundTag}) async {
    final level = await currentLevel();
    final all = await _content.all();
    final recent = {
      for (final a in await _progress.attempts(limit: 10)) a.passageId,
    };
    Iterable<Passage> pool = all;
    if (soundTag != null) {
      final tagged = all.where((p) => p.soundTags.contains(soundTag));
      final near = tagged.where((p) => p.level <= level + 1);
      pool = near.isNotEmpty ? near : (tagged.isNotEmpty ? tagged : all);
    } else {
      final atLevel = all.where((p) => p.level == level);
      final nearby = all.where((p) => (p.level - level).abs() <= 1);
      pool = atLevel.isNotEmpty ? atLevel : (nearby.isNotEmpty ? nearby : all);
    }
    final list = pool.toList();
    if (list.isEmpty) throw StateError('No passages available');
    return list.firstWhere(
      (p) => !recent.contains(p.id),
      orElse: () => list.first,
    );
  }

  @override
  Future<LevelChange?> recordAttempt(AttemptResult result) async {
    await _progress.saveAttempt(result);
    final now = _clock();
    // Spaced review: reschedule queued words, enqueue new red words.
    final passage = await _content.byId(result.passageId);
    final queue = {for (final r in await _progress.reviewQueue()) r.key: r};
    for (final w in result.words) {
      if (w.status == WordStatus.notScored) continue;
      final key = w.text.toLowerCase();
      final queued = queue[key];
      if (queued != null) {
        final next = queued.afterScore(w.score, now);
        if (next == null) {
          await _progress.removeReview(w.text);
        } else {
          await _progress.upsertReview(next);
        }
      } else if (w.status.isRed) {
        await _progress.upsertReview(
          ReviewItem.enqueue(
            word: w.text,
            phonemes: w.index < passage.words.length
                ? passage.words[w.index].phonemes
                : const [],
            now: now,
            score: w.score,
            passageId: result.passageId,
          ),
        );
      }
    }
    // Level rules over attempts since the last level change.
    var profile = await _progress.profile();
    final history = await _progress.levelHistory();
    final since = history.isEmpty ? null : history.last.at;
    final run = (await _progress.attempts(limit: 3))
        .where((a) => since == null || a.at.isAfter(since))
        .toList();
    LevelChange? change;
    if (run.length == 3) {
      final level = profile.level;
      if (run.every((a) => a.overall >= 85) && level < 6) {
        change = LevelChange(
          from: level,
          to: level + 1,
          reason:
              'Three passages in a row at 85 or more: welcome to level '
              '${level + 1}.',
          at: now,
        );
      } else if (run.every((a) => a.overall < 60) && level > 1) {
        change = LevelChange(
          from: level,
          to: level - 1,
          reason:
              'Three passages in a row under 60: back to level '
              '${level - 1} for more practice.',
          at: now,
        );
      }
    }
    if (change != null) {
      await _progress.saveLevelChange(change);
      profile = profile.copyWith(level: change.to);
    }
    final daily = await _dailyProgress(extraDay: _day(now));
    await _progress.saveProfile(
      profile.copyWith(streak: daily.streak, lastPractice: now),
    );
    return change;
  }

  @override
  Future<List<String>> dueReviewWords() async => [
    for (final r in await dueReviews()) r.word,
  ];

  @override
  Future<List<ReviewItem>> dueReviews() => _progress.dueReviews(_clock());

  @override
  Future<List<SoundStat>> weakestSounds({int count = 3}) async =>
      (await _progress.soundStats()).take(count).toList();

  @override
  Future<void> logPracticeTime(Duration duration) => _progress.logPractice(
    PracticeSession(start: _clock(), duration: duration),
  );

  @override
  Future<DailyProgress> dailyProgress() => _dailyProgress();

  Future<DailyProgress> _dailyProgress({DateTime? extraDay}) async {
    final now = _clock();
    final today = _day(now);
    final sessions = await _progress.practiceSessions();
    final days = <DateTime>{
      for (final s in sessions) _day(s.start),
      for (final a in await _progress.attempts()) _day(a.at),
      ?extraDay,
    };
    var minutes = Duration.zero;
    for (final s in sessions) {
      if (_day(s.start) == today) minutes += s.duration;
    }
    var cursor = days.contains(today)
        ? today
        : DateTime(today.year, today.month, today.day - 1);
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return DailyProgress(
      streak: streak,
      minutesToday: minutes.inMinutes,
      dailyGoalMinutes: (await _progress.profile()).dailyGoalMinutes,
      practisedDays: days.toList()..sort(),
    );
  }

  @override
  Future<List<Passage>> placementPassages() => _content.placementPassages();

  @override
  int placementLevel(List<AttemptResult> results) {
    if (results.isEmpty) return 1;
    final avg =
        results.map((r) => r.overall).reduce((a, b) => a + b) / results.length;
    return (1 + ((avg - 40) / 10).floor()).clamp(1, 6);
  }

  @override
  Future<LevelChange?> completePlacement(List<AttemptResult> results) async {
    final level = placementLevel(results);
    final profile = await _progress.profile();
    await _progress.saveProfile(
      profile.copyWith(
        level: level,
        placementDone: true,
        placementLevel: level,
      ),
    );
    if (level == profile.level) return null;
    final change = LevelChange(
      from: profile.level,
      to: level,
      reason: 'Placement test: you start at level $level.',
      at: _clock(),
    );
    await _progress.saveLevelChange(change);
    return change;
  }
}
