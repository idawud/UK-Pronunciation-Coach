import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/contracts/clock.dart';
import '../../core/contracts/errors.dart';
import '../../core/contracts/progress_repository.dart';
import '../../core/models/models.dart';
import 'codecs.dart';
import 'progress_database.dart';
import 'recording_store.dart';

/// [ProgressRepository] on SQLite (drift). See `docs/handoff/C2-data.md`.
///
/// Sound stats use the shared [SoundStat.update] rule and the review queue the shared
/// [ReviewItem.afterScore] rule, so this store and the practice engine agree.
class DriftProgressRepository implements ProgressRepository {
  /// Wraps an open [ProgressDatabase]. [clock] stamps retries and exports;
  /// [recordings] deletes audio files (defaults to one without a folder).
  DriftProgressRepository(
    this._db, {
    this._clock = systemClock,
    RecordingStore? recordings,
  }) : _recordings = recordings ?? RecordingStore();

  /// A fresh in-memory store (tests).
  factory DriftProgressRepository.inMemory({
    Clock clock = systemClock,
    RecordingStore? recordings,
  }) => DriftProgressRepository(
    ProgressDatabase.inMemory(),
    clock: clock,
    recordings: recordings,
  );

  /// Opens the app's store at `<application support>/progress.sqlite` (or
  /// [file]). Pass [recordingsDir] so [deleteAll] also empties the recordings folder.
  static Future<DriftProgressRepository> open({
    File? file,
    Directory? recordingsDir,
    Clock clock = systemClock,
  }) async {
    final dbFile =
        file ??
        File(p.join((await getApplicationSupportDirectory()).path, fileName));
    await dbFile.parent.create(recursive: true);
    return DriftProgressRepository(
      ProgressDatabase.file(dbFile),
      clock: clock,
      recordings: RecordingStore(directory: recordingsDir),
    );
  }

  /// Database file name used by [open].
  static const String fileName = 'progress.sqlite';

  /// Id of the single profile row.
  static const int _profileId = 1;

  final ProgressDatabase _db;

  /// Set when [close] starts. A read that fails after this point failed because the
  /// connection went away under it, which is a normal shutdown, not a fault.
  bool _closing = false;
  final Clock _clock;
  final RecordingStore _recordings;
  final _changes = StreamController<void>.broadcast();

  /// The underlying database (tests and migrations).
  ProgressDatabase get database => _db;

  void _changed() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  /// Closes the database and the [changes] stream.
  Future<void> close() async {
    _closing = true;
    await _changes.close();
    await _db.close();
  }

  // ---------------------------------------------------------------- attempts

  @override
  Future<void> saveAttempt(AttemptResult attempt) async {
    final toDelete = <String>{};
    await _db.transaction(() async {
      final profile = await _profile();
      var a = attempt;
      if (!profile.keepRecordings && a.audioPath != null) {
        toDelete.add(a.audioPath!);
        a = a.copyWith(audioPath: null);
      }
      final old = await (_db.select(
        _db.attempts,
      )..where((t) => t.id.equals(a.id))).getSingleOrNull();
      if (old?.audioPath != null && old!.audioPath != a.audioPath) {
        toDelete.add(old.audioPath!);
      }
      await _writeAttempt(a);
      await _foldPhonemes(a.words, a.at);
    });
    for (final path in toDelete) {
      await _recordings.delete(path);
    }
    _changed();
  }

  Future<void> _writeAttempt(AttemptResult a) async {
    await _db
        .into(_db.attempts)
        .insertOnConflictUpdate(
          AttemptsCompanion.insert(
            id: a.id,
            passageId: a.passageId,
            at: a.at,
            overall: a.overall,
            accuracy: a.accuracy,
            fluency: a.fluency,
            audioPath: Value(a.audioPath),
            tier: a.tier,
          ),
        );
    await _writeWords(a.id, a.words);
  }

  Future<void> _writeWords(String attemptId, List<WordResult> words) => _db
      .into(_db.wordResults)
      .insertOnConflictUpdate(
        WordResultsCompanion.insert(attemptId: attemptId, words: words),
      );

  /// Folds scored phonemes into sound stats with [SoundStat.update]. Words that were
  /// not scored are skipped (missed words have no phonemes).
  Future<void> _foldPhonemes(Iterable<WordResult> words, DateTime at) async {
    final scores = <String, List<int>>{};
    for (final w in words) {
      if (w.status == WordStatus.notScored) continue;
      for (final ph in w.phonemes) {
        (scores[ph.expected] ??= []).add(ph.score);
      }
    }
    if (scores.isEmpty) return;
    final existing = {
      for (final r in await (_db.select(
        _db.soundStats,
      )..where((t) => t.ipa.isIn(scores.keys))).get())
        r.ipa: _soundStat(r),
    };
    final updated = <SoundStat>[];
    scores.forEach((ipa, list) {
      SoundStat? s = existing[ipa];
      for (final score in list) {
        s = s == null ? SoundStat.first(ipa, score, at) : s.update(score, at);
      }
      updated.add(s!);
    });
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(_db.soundStats, [
        for (final s in updated) _soundStatCompanion(s),
      ]);
    });
  }

  SoundStatsCompanion _soundStatCompanion(SoundStat s) =>
      SoundStatsCompanion.insert(
        ipa: s.ipa,
        accuracy: s.accuracy,
        attempts: s.attempts,
        lastPractised: s.lastPractised,
      );

  SoundStat _soundStat(SoundStatRow r) => SoundStat(
    ipa: r.ipa,
    accuracy: r.accuracy,
    attempts: r.attempts,
    lastPractised: r.lastPractised,
  );

  @override
  Future<AttemptResult?> attempt(String id) async {
    final list = await _loadAttempts('a.id = ?', [Variable.withString(id)]);
    return list.isEmpty ? null : list.single;
  }

  @override
  Future<List<AttemptResult>> attempts({
    String? passageId,
    DateTime? since,
    int? limit,
  }) {
    final where = <String>[];
    final vars = <Variable<Object>>[];
    if (passageId != null) {
      where.add('a.passage_id = ?');
      vars.add(Variable.withString(passageId));
    }
    if (since != null) {
      where.add('a.at >= ?');
      vars.add(Variable.withInt(DateTimeCodec.lowerBound(since)));
    }
    return _loadAttempts(
      where.isEmpty ? null : where.join(' AND '),
      vars,
      limit: limit,
    );
  }

  /// Loads attempts with their words in one query (one row per attempt), mapping
  /// rows by hand: this is the hot path for "1,000 attempts in < 200 ms".
  Future<List<AttemptResult>> _loadAttempts(
    String? where,
    List<Variable<Object>> vars, {
    int? limit,
  }) async {
    final sql = StringBuffer(
      'SELECT a.id, a.passage_id, a.at, a.overall, a.accuracy, a.fluency, '
      'a.audio_path, a.tier, w.words FROM attempts a '
      'LEFT JOIN word_results w ON w.attempt_id = a.id',
    );
    if (where != null) sql.write(' WHERE $where');
    sql.write(' ORDER BY a.at DESC, a.id DESC');
    if (limit != null) {
      sql.write(' LIMIT ?');
      vars.add(Variable.withInt(limit < 0 ? 0 : limit));
    }
    final rows = await _db
        .customSelect(
          sql.toString(),
          variables: vars,
          readsFrom: {_db.attempts, _db.wordResults},
        )
        .get();
    const words = WordResultsCodec();
    final tiers = {for (final t in ModelTier.values) t.name: t};
    return [
      for (final r in rows)
        AttemptResult(
          id: r.read<String>('id'),
          passageId: r.read<String>('passage_id'),
          at: DateTimeCodec.decode(r.read<int>('at')),
          overall: r.read<int>('overall'),
          accuracy: r.read<int>('accuracy'),
          fluency: r.read<int>('fluency'),
          words: switch (r.readNullable<Uint8List>('words')) {
            null => const [],
            final blob => words.fromSql(blob),
          },
          audioPath: r.readNullable<String>('audio_path'),
          tier: tiers[r.read<String>('tier')] ?? ModelTier.full,
        ),
    ];
  }

  @override
  Future<AttemptResult> updateWordResult(
    String attemptId,
    WordResult word,
  ) async {
    final updated = await _db.transaction(() async {
      final a = await attempt(attemptId);
      if (a == null) throw AttemptNotFoundException(attemptId);
      final pos = a.words.indexWhere((w) => w.index == word.index);
      if (pos < 0) {
        throw RangeError.value(
          word.index,
          'word.index',
          'No word with this index in attempt $attemptId',
        );
      }
      final updated = a.copyWith(words: [...a.words]..[pos] = word);
      await _writeWords(attemptId, updated.words);
      final now = _clock();
      await _foldPhonemes([word], now);
      await _rescheduleReview(word, a.passageId, now);
      return updated;
    });
    _changed();
    return updated;
  }

  Future<void> _rescheduleReview(
    WordResult word,
    String passageId,
    DateTime now,
  ) async {
    final key = word.text.toLowerCase();
    final row = await (_db.select(
      _db.reviewQueue,
    )..where((t) => t.wordKey.equals(key))).getSingleOrNull();
    if (row != null) {
      final next = _reviewItem(row).afterScore(word.score, now);
      if (next == null) {
        await _deleteReview(key);
      } else {
        await _writeReview(next);
      }
    } else if (word.status.isRed) {
      await _writeReview(
        ReviewItem.enqueue(
          word: word.text,
          now: now,
          score: word.score,
          passageId: passageId,
        ),
      );
    }
  }

  // ------------------------------------------------------------- sound stats

  @override
  Future<List<SoundStat>> soundStats() async {
    final rows =
        await (_db.select(_db.soundStats)..orderBy([
              (t) => OrderingTerm.asc(t.accuracy),
              (t) => OrderingTerm.asc(t.ipa),
            ]))
            .get();
    final stats = rows.map(_soundStat).toList();
    // SQLite compares text by bytes; match Dart's String.compareTo for ties.
    stats.sort((a, b) {
      final c = a.accuracy.compareTo(b.accuracy);
      return c != 0 ? c : a.ipa.compareTo(b.ipa);
    });
    return stats;
  }

  // ----------------------------------------------------------------- profile

  @override
  Future<UserProfile> profile() async {
    try {
      return await _profile();
    } on Object catch (e) {
      // Start-up readers (router, reminders, settings) may still be waiting when the
      // app shuts down and the connection closes under them. Answer them with the
      // default profile instead of an error nobody is left to handle; a failure
      // while the store is open still propagates.
      //
      // close() is not always what ends the connection: disposing the provider
      // scope tears the drift channel down directly, so _closing can still be
      // false. A closed channel means the database is gone either way.
      if (_closing || _isConnectionGone(e)) return const UserProfile();
      rethrow;
    }
  }

  /// Whether [e] means the drift connection is gone rather than a query failing.
  ///
  /// Matched by name because drift exports only `DriftRemoteException` from
  /// `remote.dart`; `ConnectionClosedException` is internal.
  static bool _isConnectionGone(Object e) =>
      e.runtimeType.toString() == 'ConnectionClosedException' ||
      e.toString().contains('Channel was closed');

  Future<UserProfile> _profile() async {
    final r = await (_db.select(
      _db.userProfileTable,
    )..where((t) => t.id.equals(_profileId))).getSingleOrNull();
    if (r == null) return const UserProfile();
    return UserProfile(
      level: r.level,
      dailyGoalMinutes: r.dailyGoalMinutes,
      streak: r.streak,
      lastPractice: r.lastPractice,
      keepRecordings: r.keepRecordings,
      placementDone: r.placementDone,
      placementLevel: r.placementLevel,
      reminderMinutes: r.reminderMinutes,
      textScale: r.textScale,
      tierOverride: r.tierOverride,
      onboardingDone: r.onboardingDone,
    );
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _writeProfile(profile);
    _changed();
  }

  Future<void> _writeProfile(UserProfile p) => _db
      .into(_db.userProfileTable)
      .insertOnConflictUpdate(
        UserProfileTableCompanion.insert(
          id: const Value(_profileId),
          level: p.level,
          dailyGoalMinutes: p.dailyGoalMinutes,
          streak: p.streak,
          lastPractice: Value(p.lastPractice),
          keepRecordings: p.keepRecordings,
          placementDone: p.placementDone,
          placementLevel: Value(p.placementLevel),
          reminderMinutes: Value(p.reminderMinutes),
          textScale: p.textScale,
          tierOverride: Value(p.tierOverride),
          onboardingDone: p.onboardingDone,
        ),
      );

  // ------------------------------------------------------------ review queue

  ReviewItem _reviewItem(ReviewRow r) => ReviewItem(
    word: r.word,
    phonemes: r.phonemes,
    due: r.due,
    intervalDays: r.intervalDays,
    ease: r.ease,
    stage: r.stage,
    lastScore: r.lastScore,
    passageId: r.passageId,
  );

  Future<void> _writeReview(ReviewItem item) => _db
      .into(_db.reviewQueue)
      .insertOnConflictUpdate(
        ReviewQueueCompanion.insert(
          wordKey: item.key,
          word: item.word,
          phonemes: item.phonemes,
          due: item.due,
          intervalDays: item.intervalDays,
          ease: item.ease,
          stage: item.stage,
          lastScore: Value(item.lastScore),
          passageId: Value(item.passageId),
        ),
      );

  Future<int> _deleteReview(String key) =>
      (_db.delete(_db.reviewQueue)..where((t) => t.wordKey.equals(key))).go();

  Future<List<ReviewItem>> _reviews({DateTime? dueBy}) async {
    final q = _db.select(_db.reviewQueue);
    if (dueBy != null) {
      q.where(
        (t) => t.due.isSmallerOrEqualValue(DateTimeCodec.upperBound(dueBy)),
      );
    }
    q.orderBy([
      (t) => OrderingTerm.asc(t.due),
      (t) => OrderingTerm.asc(t.wordKey),
    ]);
    return (await q.get()).map(_reviewItem).toList();
  }

  @override
  Future<List<ReviewItem>> reviewQueue() => _reviews();

  @override
  Future<List<ReviewItem>> dueReviews(DateTime now) => _reviews(dueBy: now);

  @override
  Future<void> upsertReview(ReviewItem item) async {
    await _writeReview(item);
    _changed();
  }

  @override
  Future<void> removeReview(String word) async {
    if (await _deleteReview(word.toLowerCase()) > 0) _changed();
  }

  // ------------------------------------------------ level history, practice

  @override
  Future<void> saveLevelChange(LevelChange change) async {
    await _writeLevelChange(change);
    _changed();
  }

  Future<void> _writeLevelChange(LevelChange c) => _db
      .into(_db.levelChanges)
      .insert(
        LevelChangesCompanion.insert(
          fromLevel: c.from,
          toLevel: c.to,
          reason: c.reason,
          at: c.at,
        ),
      );

  @override
  Future<List<LevelChange>> levelHistory() async {
    final rows =
        await (_db.select(_db.levelChanges)..orderBy([
              (t) => OrderingTerm.asc(t.at),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    return [
      for (final r in rows)
        LevelChange(
          from: r.fromLevel,
          to: r.toLevel,
          reason: r.reason,
          at: r.at,
        ),
    ];
  }

  @override
  Future<void> logPractice(PracticeSession session) async {
    await _writeSession(session);
    _changed();
  }

  Future<void> _writeSession(PracticeSession s) => _db
      .into(_db.practiceSessions)
      .insert(
        PracticeSessionsCompanion.insert(
          start: s.start,
          durationUs: s.duration.inMicroseconds,
        ),
      );

  @override
  Future<List<PracticeSession>> practiceSessions({DateTime? since}) async {
    final q = _db.select(_db.practiceSessions);
    if (since != null) {
      q.where(
        (t) => t.start.isBiggerOrEqualValue(DateTimeCodec.lowerBound(since)),
      );
    }
    q.orderBy([
      (t) => OrderingTerm.asc(t.start),
      (t) => OrderingTerm.asc(t.id),
    ]);
    return [
      for (final r in await q.get())
        PracticeSession(
          start: r.start,
          duration: Duration(microseconds: r.durationUs),
        ),
    ];
  }

  // ---------------------------------------------------------- export, import

  @override
  Future<String> exportJson() async {
    final backup = await _db.transaction(
      () async => ProgressBackup(
        exportedAt: _clock(),
        profile: await _profile(),
        attempts: await attempts(),
        soundStats: await soundStats(),
        reviewQueue: await reviewQueue(),
        levelHistory: await levelHistory(),
        practiceSessions: await practiceSessions(),
      ),
    );
    return jsonEncode(backup.toJson());
  }

  /// Parses and validates a backup without touching the database.
  static ProgressBackup parseBackup(String json) {
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup must be a JSON object');
    }
    final ProgressBackup backup;
    try {
      backup = ProgressBackup.fromJson(decoded);
    } catch (e) {
      throw FormatException('Invalid backup: $e');
    }
    if (backup.schemaVersion > ProgressBackup.currentSchemaVersion) {
      throw FormatException(
        'Backup schema ${backup.schemaVersion} is newer than supported '
        '${ProgressBackup.currentSchemaVersion}',
      );
    }
    if (backup.schemaVersion < 1) {
      throw FormatException('Invalid backup schema ${backup.schemaVersion}');
    }
    return backup;
  }

  @override
  Future<void> importJson(String json) async {
    final backup = parseBackup(json);
    await _db.transaction(() async {
      await _wipe();
      await _writeProfile(backup.profile);
      for (final a in backup.attempts) {
        await _writeAttempt(a);
      }
      await _db.batch((b) {
        b.insertAllOnConflictUpdate(_db.soundStats, [
          for (final s in backup.soundStats) _soundStatCompanion(s),
        ]);
      });
      for (final r in backup.reviewQueue) {
        await _writeReview(r);
      }
      for (final c in backup.levelHistory) {
        await _writeLevelChange(c);
      }
      for (final s in backup.practiceSessions) {
        await _writeSession(s);
      }
    });
    _changed();
  }

  // -------------------------------------------------------------- delete all

  Future<void> _wipe() async {
    for (final table in _db.allTables.toList().reversed) {
      await _db.delete(table).go();
    }
  }

  @override
  Future<void> deleteAll() async {
    final paths = await _db.transaction(() async {
      final rows = await (_db.selectOnly(
        _db.attempts,
      )..addColumns([_db.attempts.audioPath])).get();
      await _wipe();
      return [for (final r in rows) r.read(_db.attempts.audioPath)];
    });
    await _recordings.deleteAll(paths);
    _changed();
  }
}
