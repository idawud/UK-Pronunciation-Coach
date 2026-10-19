import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/models/models.dart';
import 'codecs.dart';

part 'progress_database.g.dart';

/// One scored reading (`AttemptResult` without its words).
@DataClassName('AttemptRow')
@TableIndex(name: 'attempts_at', columns: {#at})
@TableIndex(name: 'attempts_passage', columns: {#passageId, #at})
class Attempts extends Table {
  TextColumn get id => text()();
  TextColumn get passageId => text()();
  IntColumn get at => integer().map(const DateTimeCodec())();
  IntColumn get overall => integer()();
  IntColumn get accuracy => integer()();
  IntColumn get fluency => integer()();
  TextColumn get audioPath => text().nullable()();
  TextColumn get tier => textEnum<ModelTier>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The words of an attempt (scores, statuses, phonemes heard vs expected), one row per
/// attempt as a compact blob ([WordResultsCodec]) so history loads fast.
@DataClassName('WordResultsRow')
class WordResults extends Table {
  TextColumn get attemptId =>
      text().references(Attempts, #id, onDelete: KeyAction.cascade)();
  BlobColumn get words => blob().map(const WordResultsCodec())();

  @override
  Set<Column<Object>> get primaryKey => {attemptId};
}

/// Rolling accuracy per phoneme (`SoundStat`).
@DataClassName('SoundStatRow')
class SoundStats extends Table {
  TextColumn get ipa => text()();
  RealColumn get accuracy => real()();
  IntColumn get attempts => integer()();
  IntColumn get lastPractised => integer().map(const DateTimeCodec())();

  @override
  Set<Column<Object>> get primaryKey => {ipa};
}

/// Spaced-review queue (`ReviewItem`), keyed by the lower-cased word.
@DataClassName('ReviewRow')
@TableIndex(name: 'review_queue_due', columns: {#due})
class ReviewQueue extends Table {
  @override
  String get tableName => 'review_queue';

  TextColumn get wordKey => text()();
  TextColumn get word => text()();
  TextColumn get phonemes => text().map(const PhonemeSpecsCodec())();
  IntColumn get due => integer().map(const DateTimeCodec())();
  IntColumn get intervalDays => integer()();
  RealColumn get ease => real()();
  IntColumn get stage => integer()();
  IntColumn get lastScore => integer().nullable()();
  TextColumn get passageId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {wordKey};
}

/// The single user profile row (id 1).
@DataClassName('ProfileRow')
class UserProfileTable extends Table {
  @override
  String get tableName => 'user_profile';

  IntColumn get id => integer()();
  IntColumn get level => integer()();
  IntColumn get dailyGoalMinutes => integer()();
  IntColumn get streak => integer()();
  IntColumn get lastPractice =>
      integer().map(const DateTimeCodec()).nullable()();
  BoolColumn get keepRecordings => boolean()();
  BoolColumn get placementDone => boolean()();
  IntColumn get placementLevel => integer().nullable()();
  IntColumn get reminderMinutes => integer().nullable()();
  RealColumn get textScale => real()();
  TextColumn get tierOverride => textEnum<ModelTier>().nullable()();
  BoolColumn get onboardingDone => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Level history (`LevelChange`), in insertion order.
@DataClassName('LevelChangeRow')
class LevelChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fromLevel => integer()();
  IntColumn get toLevel => integer()();
  TextColumn get reason => text()();
  IntColumn get at => integer().map(const DateTimeCodec())();
}

/// Logged practice time (`PracticeSession`).
@DataClassName('PracticeSessionRow')
@TableIndex(name: 'practice_sessions_start', columns: {#start})
class PracticeSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get start => integer().map(const DateTimeCodec())();
  IntColumn get durationUs => integer()();
}

/// The progress database (SQLite through drift).
///
/// Schema history. To change the schema: bump [currentSchemaVersion], add a step to
/// [migrations], then dump and regenerate the test schemas (commands in
/// docs/handoff/C2-data.md) and add a migration test.
///
/// - v1: attempts, word_results (one blob per attempt), sound_stats, review_queue, user_profile,
///   level_changes, practice_sessions.
@DriftDatabase(
  tables: [
    Attempts,
    WordResults,
    SoundStats,
    ReviewQueue,
    UserProfileTable,
    LevelChanges,
    PracticeSessions,
  ],
)
class ProgressDatabase extends _$ProgressDatabase {
  /// Opens a database on [executor].
  ProgressDatabase(super.executor);

  /// A fresh in-memory database (tests).
  ProgressDatabase.inMemory() : super(NativeDatabase.memory());

  /// A database stored in [file], with queries run on a background isolate.
  ProgressDatabase.file(File file)
    : super(NativeDatabase.createInBackground(file));

  /// Current schema version. See the class doc for the history.
  static const int currentSchemaVersion = 1;

  /// Upgrade steps: `migrations[v]` upgrades a database from `v - 1` to `v`.
  /// Must have an entry for every version from 2 to [currentSchemaVersion].
  static final Map<int, Future<void> Function(Migrator m, ProgressDatabase db)>
  migrations = {};

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from > to) {
        throw UnsupportedError(
          'Progress database v$from is newer than this app (v$to).',
        );
      }
      for (var v = from + 1; v <= to; v++) {
        final step = migrations[v];
        if (step == null) {
          throw StateError('No migration from v${v - 1} to v$v');
        }
        await step(m, this);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
