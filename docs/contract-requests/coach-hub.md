# Contract requests: Coach hub (feat/coach-hub)

Owner: the Coach hub foundation on `feat/coach-hub`. Nothing here blocks the hub, which
works today with `coachPath` and a local `CoachStore`. These proposals are for the
frozen contracts in `lib/core/`, to be merged in one small PR before the Coach
sections need them.

## 1. `AppRoutes.coach` and its sub-routes

**What.** In `lib/core/contracts/navigation.dart`, add to `AppRoutes`:

```dart
/// Coach tab hub: one card per section.
static const coach = '/coach';

/// Coach section: weakest sounds, minimal pairs and the exercise library.
static const coachSounds = '/coach/sounds';

/// Coach section: my confusions and the daily session.
static const coachConfusions = '/coach/confusions';

/// Coach section: the lost-word bank.
static const coachWords = '/coach/words';

/// Coach section: record and compare.
static const coachRecord = '/coach/record';

/// Coach section: describe it and phrases.
static const coachDescribe = '/coach/describe';
```

**Why.** `lib/ui/coach/coach_routes.dart` holds these paths as local constants. The
section registry (`lib/ui/coach/coach_sections.dart`) requires each `subPath` to equal
`/coach/<id>`, so the contract constants would make that rule checkable by the
compiler and by `test/contracts/`.

**Affects.** `lib/ui/shell/app_router.dart` (`coachPath` becomes `AppRoutes.coach`;
the `/coach` branch keeps its nested routes built from `coachSections`), and
`lib/ui/coach/coach_routes.dart` can then be deleted. No fake or model change.

## 2. Include `CoachStore` in `deleteAll` and `exportJson`

**What.** The Coach features keep their state in one JSON file
(`coach_store.json`, see `lib/data/coach/coach_store.dart`), outside the drift database.
Two additions:

- `ProgressRepository.deleteAll()` (or the Settings "delete all my data" action) also
  calls `CoachStore.clear()`.
- `ProgressRepository.exportJson()` (the `ProgressBackup` format) includes the Coach
  keys under a new optional `coach` object, so a backup restores the Coach sections
  too. `importJson` should accept a backup without it.

**Why.** Without this, "delete all my data" leaves confusions and lost words behind,
and a backup silently drops them. `CoachStore` is an abstract interface, so the
contract can depend on it directly or the Settings screen can call it alongside
`deleteAll`; either works.

**Affects.** `lib/core/contracts/progress_repository.dart` (or a new
`lib/core/contracts/coach_store.dart` re-exporting the interface), `ProgressBackup` in
`lib/core/models/`, and the fakes. Settings (`lib/ui/settings/`) wires the clear.

## 3. An `AudioPlayer` contract for the user's recorded WAV

**What.** The Record & compare section plays the user's own recording back, and
Results already has play buttons for the model voice only. Proposed:

```dart
/// Plays a recorded clip stored on this device.
abstract interface class AudioPlayer {
  /// Plays the WAV file at [path] from the start; completes when it ends or is stopped.
  Future<void> play(String path);

  /// Stops playback. Safe to call when nothing plays.
  Future<void> stop();

  /// True while a clip plays.
  ValueListenable<bool> get playing;
}
```

**Why.** `VoiceService` only speaks text. The recordings are written by
`lib/engine/audio/` (A1) to app storage, and `RecordingStore` (C2) deletes them.
A small player contract lets the Record section and Results share one implementation
without importing the audio engine. A `FakeAudioPlayer` belongs in `lib/core/fakes/`.

**Affects.** New contract in `lib/core/contracts/`, a fake in `lib/core/fakes/`, and
the implementation in `lib/engine/audio/` (A1) or a new `lib/voice/` player (C4).

## 4. Optional "save lost word" hook for Results and Read

**What.** When a user taps a word on Results (or Read) that they missed, the app can
add it to the Coach lost-word bank. Proposed as an optional callback on
`ResultsArgs` (or a provider the Results screen reads):

```dart
/// Called when the user saves a missed word to the Coach lost-word bank.
typedef SaveLostWord = Future<void> Function(LostWord word);
```

with `LostWord` holding the word, its IPA and the passage id. The Words section reads
the bank from `CoachStore` under the `lostWords` key.

**Why.** Results is owned by U3 and the Words section by a later agent. A hook avoids
either screen importing the other. Leaving the argument null keeps Results unchanged.

**Affects.** `ResultsArgs` in `lib/core/contracts/navigation.dart`, `lib/ui/results/`
(U3), and the new `LostWord` model in `lib/core/models/` (only if the Words section
needs it as a typed model rather than a map).

## Not requested

- No change to `ProgressRepository` queries, `PracticeEngine` or `VoiceService`.
- No change to the `coach` store file format beyond the top-level `version: 1` already
  in `coach_store.json`.
