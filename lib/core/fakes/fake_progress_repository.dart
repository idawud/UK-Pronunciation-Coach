import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../contracts/clock.dart';
import '../contracts/errors.dart';
import '../contracts/progress_repository.dart';
import '../models/models.dart';

/// Working in-memory [ProgressRepository]. Deletes recording files like the real one.
class FakeProgressRepository implements ProgressRepository {
  /// Creates an empty repository; [clock] stamps exports.
  FakeProgressRepository({this._clock = systemClock});

  final Clock _clock;
  final _changes = StreamController<void>.broadcast();
  final Map<String, AttemptResult> _attempts = {};
  final Map<String, SoundStat> _stats = {};
  final Map<String, ReviewItem> _reviews = {};
  final List<LevelChange> _levels = [];
  final List<PracticeSession> _sessions = [];
  UserProfile _profile = const UserProfile();

  void _changed() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  void _foldPhonemes(Iterable<WordResult> words, DateTime at) {
    for (final w in words) {
      if (w.status == WordStatus.notScored) continue;
      for (final p in w.phonemes) {
        final s = _stats[p.expected];
        _stats[p.expected] = s == null
            ? SoundStat.first(p.expected, p.score, at)
            : s.update(p.score, at);
      }
    }
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> saveAttempt(AttemptResult attempt) async {
    var a = attempt;
    if (!_profile.keepRecordings && a.audioPath != null) {
      await _deleteFile(a.audioPath);
      a = a.copyWith(audioPath: null);
    }
    _attempts[a.id] = a;
    _foldPhonemes(a.words, a.at);
    _changed();
  }

  @override
  Future<AttemptResult?> attempt(String id) async => _attempts[id];

  @override
  Future<List<AttemptResult>> attempts({
    String? passageId,
    DateTime? since,
    int? limit,
  }) async {
    final list =
        _attempts.values
            .where((a) => passageId == null || a.passageId == passageId)
            .where((a) => since == null || !a.at.isBefore(since))
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    return limit == null || list.length <= limit
        ? list
        : list.sublist(0, limit);
  }

  @override
  Future<AttemptResult> updateWordResult(
    String attemptId,
    WordResult word,
  ) async {
    final a = _attempts[attemptId];
    if (a == null) throw AttemptNotFoundException(attemptId);
    RangeError.checkValidIndex(word.index, a.words, 'word.index');
    final updated = a.copyWith(
      words: [
        for (final w in a.words)
          if (w.index == word.index) word else w,
      ],
    );
    _attempts[attemptId] = updated;
    final now = _clock();
    _foldPhonemes([word], now);
    final key = word.text.toLowerCase();
    final queued = _reviews[key];
    if (queued != null) {
      final next = queued.afterScore(word.score, now);
      if (next == null) {
        _reviews.remove(key);
      } else {
        _reviews[key] = next;
      }
    } else if (word.status.isRed) {
      _reviews[key] = ReviewItem.enqueue(
        word: word.text,
        now: now,
        score: word.score,
        passageId: a.passageId,
      );
    }
    _changed();
    return updated;
  }

  @override
  Future<List<SoundStat>> soundStats() async =>
      _stats.values.toList()..sort((a, b) {
        final c = a.accuracy.compareTo(b.accuracy);
        return c != 0 ? c : a.ipa.compareTo(b.ipa);
      });

  @override
  Future<UserProfile> profile() async => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    _changed();
  }

  List<ReviewItem> _sortedReviews() =>
      _reviews.values.toList()..sort((a, b) => a.due.compareTo(b.due));

  @override
  Future<List<ReviewItem>> reviewQueue() async => _sortedReviews();

  @override
  Future<List<ReviewItem>> dueReviews(DateTime now) async =>
      _sortedReviews().where((r) => r.isDue(now)).toList();

  @override
  Future<void> upsertReview(ReviewItem item) async {
    _reviews[item.key] = item;
    _changed();
  }

  @override
  Future<void> removeReview(String word) async {
    if (_reviews.remove(word.toLowerCase()) != null) _changed();
  }

  @override
  Future<void> saveLevelChange(LevelChange change) async {
    _levels.add(change);
    _changed();
  }

  @override
  Future<List<LevelChange>> levelHistory() async =>
      _levels.toList()..sort((a, b) => a.at.compareTo(b.at));

  @override
  Future<void> logPractice(PracticeSession session) async {
    _sessions.add(session);
    _changed();
  }

  @override
  Future<List<PracticeSession>> practiceSessions({DateTime? since}) async =>
      _sessions.where((s) => since == null || !s.start.isBefore(since)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  @override
  Future<String> exportJson() async => jsonEncode(
    ProgressBackup(
      exportedAt: _clock(),
      profile: _profile,
      attempts: await attempts(),
      soundStats: await soundStats(),
      reviewQueue: _sortedReviews(),
      levelHistory: await levelHistory(),
      practiceSessions: await practiceSessions(),
    ).toJson(),
  );

  @override
  Future<void> importJson(String json) async {
    final ProgressBackup backup;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Backup must be a JSON object');
      }
      backup = ProgressBackup.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid backup: $e');
    }
    if (backup.schemaVersion > ProgressBackup.currentSchemaVersion) {
      throw FormatException(
        'Backup schema ${backup.schemaVersion} is newer than supported '
        '${ProgressBackup.currentSchemaVersion}',
      );
    }
    _clear();
    _profile = backup.profile;
    for (final a in backup.attempts) {
      _attempts[a.id] = a;
    }
    for (final s in backup.soundStats) {
      _stats[s.ipa] = s;
    }
    for (final r in backup.reviewQueue) {
      _reviews[r.key] = r;
    }
    _levels.addAll(backup.levelHistory);
    _sessions.addAll(backup.practiceSessions);
    _changed();
  }

  void _clear() {
    _attempts.clear();
    _stats.clear();
    _reviews.clear();
    _levels.clear();
    _sessions.clear();
    _profile = const UserProfile();
  }

  @override
  Future<void> deleteAll() async {
    for (final a in _attempts.values) {
      await _deleteFile(a.audioPath);
    }
    _clear();
    _changed();
  }
}
