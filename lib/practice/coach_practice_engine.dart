import 'dart:math';

import '../core/contracts/clock.dart';
import '../core/contracts/content_repository.dart';
import '../core/contracts/practice_engine.dart';
import '../core/contracts/progress_repository.dart';
import '../core/models/models.dart';
import 'level_rules.dart';
import 'local_days.dart';
import 'passage_picker.dart';
import 'review_updates.dart';

/// The real [PracticeEngine] (C3): level rules, the 70 / 20 / 10 passage mix, spaced
/// review, placement, streaks and daily minutes.
///
/// Pure Dart over the [ContentRepository] and [ProgressRepository] contracts. Inject
/// [clock], [random] (seed it for repeatable tests) and [wallClock] (the user's time
/// zone; defaults to the device's).
class CoachPracticeEngine implements PracticeEngine {
  /// Creates the engine.
  CoachPracticeEngine({
    required this._content,
    required this._progress,
    this._clock = systemClock,
    Random? random,
    this._wallClock = deviceWallClock,
  }) : _picker = PassagePicker(random ?? Random());

  final ContentRepository _content;
  final ProgressRepository _progress;
  final Clock _clock;
  final WallClock _wallClock;
  final PassagePicker _picker;

  /// Passage ids known to the content bundle (library + placement), loaded once.
  Future<Map<String, Passage>>? _passages;

  Future<Map<String, Passage>> _knownPassages() => _passages ??= () async {
    final all = await _content.all();
    final placement = await _content.placementPassages();
    return {
      for (final p in [...placement, ...all]) p.id: p,
    };
  }();

  @override
  Future<int> currentLevel() async =>
      (await _progress.profile()).level.clamp(minLevel, maxLevel);

  @override
  Future<Passage> nextPassage({String? soundTag}) async {
    final level = await currentLevel();
    final library = await _content.all();
    final recent = await _progress.attempts(
      limit: PassagePicker.noRepeatWithin,
    );
    final weak = await weakestSounds();
    final queue = await _progress.reviewQueue();
    final due = queue.where((r) => r.isDue(_clock())).toList();
    return _picker
        .pick(
          library: library,
          level: level,
          weakSounds: [for (final s in weak) s.ipa],
          reviewWords: {for (final r in due.isNotEmpty ? due : queue) r.key},
          recentIds: [for (final a in recent) a.passageId],
          soundTag: soundTag,
        )
        .passage;
  }

  @override
  Future<LevelChange?> recordAttempt(AttemptResult result) async {
    final now = _clock();
    await _progress.saveAttempt(result);

    final known = await _knownPassages();
    final passage = known[result.passageId];
    await _updateReviews(result, passage, now);

    var profile = await _progress.profile();
    final level = profile.level.clamp(minLevel, maxLevel);
    LevelChange? change;
    if (passage != null) {
      final history = await _progress.levelHistory();
      final since = history.isEmpty ? null : history.last.at;
      final run = <int>[];
      for (final a in await _progress.attempts(since: since)) {
        if (since != null && !a.at.isAfter(since)) continue;
        if (!known.containsKey(a.passageId)) continue;
        run.add(a.overall);
        if (run.length == runLength) break;
      }
      final at = result.at.isAfter(now) ? result.at : now;
      change = levelChangeFor(level, run, at);
      if (change != null) {
        await _progress.saveLevelChange(change);
        profile = profile.copyWith(level: change.to);
      }
    }

    final daily = await dailyProgress();
    await _progress.saveProfile(
      profile.copyWith(
        streak: daily.streak,
        lastPractice: _latest(profile, now),
      ),
    );
    return change;
  }

  static DateTime _latest(UserProfile profile, DateTime now) {
    final last = profile.lastPractice;
    return last != null && last.isAfter(now) ? last : now;
  }

  Future<void> _updateReviews(
    AttemptResult result,
    Passage? passage,
    DateTime now,
  ) async {
    final queue = {for (final r in await _progress.reviewQueue()) r.key: r};
    final missing = [
      for (final w in result.words)
        if (passage == null || w.index >= passage.words.length) w.text,
    ];
    final looked = <String, List<PhonemeSpec>>{};
    if (missing.isNotEmpty) {
      for (final spec in await _content.lookup(missing.join(' '))) {
        looked[spec.text.toLowerCase()] = spec.phonemes;
      }
    }
    final updates = reviewUpdatesFor(
      words: result.words,
      queue: queue,
      now: now,
      passageId: result.passageId,
      phonemesFor: (w) => passage != null && w.index < passage.words.length
          ? passage.words[w.index].phonemes
          : looked[w.text.toLowerCase()] ?? const [],
    );
    for (final word in updates.removals) {
      await _progress.removeReview(word);
    }
    for (final item in updates.upserts) {
      await _progress.upsertReview(item);
    }
  }

  @override
  Future<List<String>> dueReviewWords() async => [
    for (final r in await dueReviews()) r.word,
  ];

  @override
  Future<List<ReviewItem>> dueReviews() => _progress.dueReviews(_clock());

  @override
  Future<List<SoundStat>> weakestSounds({int count = 3}) async {
    if (count <= 0) return const [];
    return (await _progress.soundStats()).take(count).toList();
  }

  @override
  Future<void> logPracticeTime(Duration duration) async {
    if (duration <= Duration.zero) return;
    final now = _clock();
    await _progress.logPractice(
      PracticeSession(start: now, duration: duration),
    );
    final profile = await _progress.profile();
    final daily = await dailyProgress();
    await _progress.saveProfile(
      profile.copyWith(
        streak: daily.streak,
        lastPractice: _latest(profile, now),
      ),
    );
  }

  @override
  Future<DailyProgress> dailyProgress() async {
    final today = LocalDay.of(_clock(), _wallClock);
    final minutes = <LocalDay, Duration>{};
    for (final s in await _progress.practiceSessions()) {
      for (final MapEntry(:key, :value) in splitByLocalDay(
        s,
        _wallClock,
      ).entries) {
        minutes[key] = (minutes[key] ?? Duration.zero) + value;
      }
    }
    final days = <LocalDay>{
      ...minutes.keys,
      for (final a in await _progress.attempts()) LocalDay.of(a.at, _wallClock),
    };
    final sorted = days.toList()
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return DailyProgress(
      streak: streakFor(days, today),
      minutesToday: (minutes[today] ?? Duration.zero).inMinutes,
      dailyGoalMinutes: (await _progress.profile()).dailyGoalMinutes,
      practisedDays: [for (final d in sorted) d.toDate()],
    );
  }

  @override
  Future<List<Passage>> placementPassages() => _content.placementPassages();

  @override
  int placementLevel(List<AttemptResult> results) =>
      placementLevelFor([for (final r in results) r.overall]);

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
