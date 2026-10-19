# Handoff: C2-data

`ProgressRepository` on SQLite with drift. Passes the shared contract suite unchanged.

## What was built

| File | What |
| --- | --- |
| `lib/data/data.dart` | Barrel: `DriftProgressRepository`, `ProgressDatabase`, `RecordingStore` |
| `lib/data/progress/progress_database.dart` (+ `.g.dart`) | drift schema v1, migration strategy |
| `lib/data/progress/codecs.dart` | `DateTimeCodec`, `WordResultsCodec` (binary), `PhonemeSpecsCodec` |
| `lib/data/progress/drift_progress_repository.dart` | The repository |
| `lib/data/progress/recording_store.dart` | Deletes recordings; injectable folder |
| `test/data/progress/` | Contract run, unit, codec, migration and performance tests |
| `test/data/schemas/` | Dumped schema `drift_schema_v1.json`, generated helpers, `regenerate.sh` |
| `integration_test/C2-data/` | On-device: contract on a real DB file, reopen, 1,000-attempt load |

## How to use it (for I1)

```dart
final repo = await DriftProgressRepository.open(
  recordingsDir: dirWhereA1SavesClips, // so deleteAll also empties it
  clock: ref.watch(clockProvider),
);
// progressRepositoryProvider: return repo; ref.onDispose(repo.close);
```

`open()` uses `<application support>/progress.sqlite` (or `file:`), and queries run
on a background isolate (`NativeDatabase.createInBackground`). Tests use
`DriftProgressRepository.inMemory(clock: ..., recordings: RecordingStore(directory: tmp))`.

## Schema v1

| Table | Columns |
| --- | --- |
| `attempts` | id PK, passage_id, at, overall, accuracy, fluency, audio_path?, tier. Indexes on (at) and (passage_id, at) |
| `word_results` | attempt_id PK, FK to attempts ON DELETE CASCADE; `words` BLOB: all the attempt's words with score, status, phonemes expected vs heard and timings |
| `sound_stats` | ipa PK, accuracy, attempts, last_practised |
| `review_queue` | word_key PK (lower-cased), word, phonemes (JSON), due (indexed), interval_days, ease, stage, last_score?, passage_id? |
| `user_profile` | single row id = 1, one column per `UserProfile` field |
| `level_changes` | id autoincrement, from_level, to_level, reason, at |
| `practice_sessions` | id autoincrement, start (indexed), duration_us |

- **Times** are stored as one integer, `microsecondsSinceEpoch * 2 + isUtc`. The value
  sorts in time order and reads back equal (`DateTime ==` checks the UTC flag too).
- **Words are one blob per attempt** rather than one row per word. With a row per word,
  loading 1,000 attempts (60,000 rows) took over 1 s; SQLite row overhead alone was about
  550 ms. The blob is a versioned varint format with a per-attempt string table, and
  statuses are stored by name. It is documented in `WordResultsCodec`; a layout change
  needs a new format number. The table keeps the spec's `word_results` name.
- **Shared rules**: sound stats use `SoundStat.first` / `SoundStat.update` (EMA,
  alpha 0.3) and skip `notScored` words. `updateWordResult` folds at `clock()` and uses
  `ReviewItem.afterScore` / `ReviewItem.enqueue`.
- **Recordings**: when `keepRecordings` is off, `saveAttempt` stores `audioPath: null`
  and deletes the file after the transaction commits. Replacing a kept attempt deletes
  the replaced file. `deleteAll` wipes every table, deletes each attempt's file and
  empties `recordingsDir`. Deletion failures are ignored, so a later `deleteAll` retries.
- **Import** parses and validates first (`FormatException` for invalid JSON, a newer
  `schemaVersion` or a version below 1). It then replaces everything in one
  transaction: it does not re-fold stats and keeps `audioPath`s as given.
- **Migrations**: `ProgressDatabase.currentSchemaVersion` = 1. `migrations[v]` upgrades
  from v-1 to v and is run step by step. A database from a newer app is refused, and
  `PRAGMA foreign_keys = ON` is set on open. To change the schema: edit the tables, bump
  the version, add `migrations[v]`, run `dart run build_runner build`, then
  `test/data/schemas/regenerate.sh` (dumps `drift_schema_vN.json` and generates the
  `*.g.dart` helpers), and add a data-migration test with `verifier.schemaAt(v-1)`.
  `migration_test.dart` fails if a version has no dump or step. It also validates the
  fresh schema against the dump and every older dump upgraded to the current one.

## Results

- Contract suite `runProgressRepositoryContract`: **15/15 pass** (in-memory drift).
- `test/data/progress`: 45 tests pass.
- Performance: `attempts()` loads 1,000 attempts × 60 words (~160k phonemes) in
  **80 ms** with the machine lightly loaded and 153 ms under heavy load from parallel
  agents (best of 5; target < 200 ms). The query is one LEFT JOIN, mapped by hand.
- Coverage: `lib/data/` 87.4% (gate 85%). `scripts/check.sh` passes: 372 Dart tests, ruff and pytest, content and licence checks.
- `integration_test/C2-data/` has been analysed only (no emulator here).

## pubspec edits

- dependencies: `drift: ^2.35.2` (MIT)
- dev_dependencies: `drift_dev: ^2.35.1` (MIT)
- New transitive packages: `sqlite3` 3.7.1 (MIT; SQLite itself is public domain),
  `sqlparser`, `native_toolchain_c`, `recase`, `charcode`, `cli_util`, `yaml_edit` (all
  BSD/MIT). No `sqlite3_flutter_libs` / `drift_flutter`: sqlite3 3.x bundles SQLite
  through a build hook.

## Native notes

- No `android/` or `ios/` changes. sqlite3 3.x's build hook downloads a prebuilt,
  SHA-256-checked SQLite **at build time** (not at runtime) from the sqlite3 package's
  GitHub release, for Android, iOS and the Linux host used by `flutter test`. CI build
  jobs therefore need network at build time, which they already have. For a fully
  offline build, set `hooks: user_defines: sqlite3: source: ...` (see the sqlite3
  package's `doc/hook.md`).
- No licence entry was needed in `docs/licences.md` (that file lists models,
  dictionaries and voices; drift and sqlite3 are MIT packages that the licence check
  covers).

## Known gaps

- Re-saving an attempt id folds its phonemes into the sound stats again, the same as the
  fake (see docs/contract-requests/C2-data.md).
- Review items enqueued by `updateWordResult` have empty `phonemes` (same as the fake).
- There is no at-rest encryption: the database relies on the app sandbox.
- On-device tests have not been run on an emulator.
- If `drift_dev schema generate` is run without `regenerate.sh`, it writes `schema.dart`
  files that fail `strict_raw_types` analysis. Always use the script.
