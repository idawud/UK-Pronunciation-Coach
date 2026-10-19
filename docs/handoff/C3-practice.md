# Handoff: C3-practice

The real `PracticeEngine`: level rules, next-passage mix, spaced review, placement,
streaks and daily minutes. Pure Dart in `lib/practice/`, built only on the
`ContentRepository` / `ProgressRepository` contracts. No new dependencies.

## What was built

| File | What |
| --- | --- |
| `lib/practice/coach_practice_engine.dart` | `CoachPracticeEngine implements PracticeEngine` |
| `lib/practice/level_rules.dart` | `levelChangeFor` (up after 3 at 85+, down after 3 under 60, 1-6), `placementLevelFor` |
| `lib/practice/passage_picker.dart` | `PassagePicker`: 70 / 20 / 10 mix, weak-sound weighting, no repeat within 10 sessions, sound-tag picks |
| `lib/practice/review_updates.dart` | Review-queue changes for one attempt, using the shared `ReviewItem.enqueue` / `afterScore` |
| `lib/practice/local_days.dart` | `WallClock` (time zone), `LocalDay`, `splitByLocalDay`, `streakFor` |
| `lib/practice/practice.dart` | Barrel export |

## How to use it

```dart
final engine = CoachPracticeEngine(
  content: ref.watch(contentRepositoryProvider),
  progress: ref.watch(progressRepositoryProvider),
  // optional: clock: systemClock, random: Random(seed), wallClock: deviceWallClock
);
```

I1 should bind `practiceEngineProvider` to this in `lib/core/providers.dart`. Create one
instance per repository pair: it caches the set of known passage ids from the content
repository on first use.

## Rules as implemented

- **Recording** (`recordAttempt`): saves the attempt through `saveAttempt` (callers
  must not save it again), updates the review queue, applies the level rules, saves any
  `LevelChange` to the history, and stores `streak` and `lastPractice` on the profile.
- **Levels**: the run is the library or placement passage attempts made after the last
  level change (placement counts as a change), newest first. All levels count: reading
  a harder or easier passage still extends or breaks the run, as the spec says
  "3 passages in a row". A change's `at` is the later of the clock and the attempt's
  `at`, so the triggering attempt never counts again.
- **Custom text** (a `passageId` not in the content bundle): saved and its red words
  queued (phonemes from `ContentRepository.lookup`), but it neither joins nor breaks a
  level run.
- **Review**: each word is handled once per attempt by its lowest score. A queued word is
  rescheduled with `ReviewItem.afterScore` (removed when it graduates after 21 days),
  even before it is due, as the contract says. An unqueued red (`fix` / `missed`) word
  is enqueued with its passage phonemes. Unscored words are ignored.
- **Next passage**: rolls current (70%) / review (20%) / preview (10%).
  - Current: level L; weight 1 + 3 / 2 / 1 for a tag matching the weakest / 2nd / 3rd
    weakest sound.
  - Review: passages at level <= L+1 containing review words (due ones if any are due,
    otherwise the whole queue), weighted by how many they contain.
  - Preview: level L+1 with the same weak-sound weights (none at level 6).
  - The last 10 attempts' passages are skipped. An empty bucket falls back to the
    current level, then to levels L-1..L+1, then to the least recently read passage at
    the nearest level.
  - `soundTag`: a tagged passage at or below L+1 (any level if none), closest to L,
    random among equals, fresh first; an unknown tag gives the normal mix.
- **Placement** (passages for levels 1, 3, 5, using `overall`): a gated ladder with pass
  60 and strong 80. Level-1 pass gives 2; level-3 pass gives 3 (4 if strong); level-5
  pass as well gives 5 (6 if strong). A higher passage only counts if the one below was
  passed. Monotonic. Placement attempts are not saved.
- **Daily minutes and streaks**: time is credited by local day in the injected
  `WallClock` (default: the device zone). A session that crosses midnight is split by
  elapsed time. Attempts also mark a day as practised. The streak counts back from
  today, or from yesterday if today has no practice yet, so it breaks after a whole
  missed local day. `logPracticeTime` ignores durations of zero or less.
- **Travel**: days are recomputed from stored instants in the *current* zone, so after
  flying, past sessions move to the days they fall on in the new zone. The tests pin
  this behaviour down.

## Tests

`test/practice/` (109 tests, all passing under TZ=UTC, America/New_York, Asia/Tokyo
and Europe/London):

- The `runPracticeEngineContract` suite (device time zone; the suite stamps attempts
  with device-local DateTimes, so it is not rerun under an injected zone).
  Europe/London behaviour is tested separately with UTC instants (`test/practice/zones.dart`).
- Table-driven tests for the level rules, placement (including an exhaustive
  monotonicity check), review intervals (1/3/7/21, reset, repeat, graduate), streaks,
  splitting at midnight, both 2026 UK clock changes, the 25-hour day, and travel
  London -> New York -> Tokyo.
- A statistical check of the passage mix (seed 42, 5,000 picks: 70/20/10 within ±3
  points), weak-sound weighting, and no repeats over 500 consecutive picks.

Coverage of `lib/practice/`: 263 of 264 lines (the one line missed is unreachable).
`scripts/check.sh`: format, analyze, all 449 Dart tests, the coverage gate, ruff, the
content check and the licence check pass. The pytest step fails only at collection of
A4's `tools/models/tests` (needs `soundfile` / `torch` from `tools/models/requirements.txt`,
not installed on this shared machine). `pytest tools --ignore=tools/models` passes
(29 tests). A3's 200-word benchmark (< 100 ms) failed once under machine load and
passed on the rerun.

## Contract requests

None.

## Known gaps

- Production uses the device time zone only (`deviceWallClock`); Europe/London rules
  exist only as a test helper. No tz database dependency was added.
- `dailyProgress` loads every attempt and session each time. That is fine for the
  1,000-attempt target but could be bounded with `since` if histories grow large.
- Level runs count passages at any level (see Rules). If product wants only
  at-or-above-level passages to count towards moving up, change it in
  `CoachPracticeEngine.recordAttempt`.
- Nothing calls `logPracticeTime` yet (U2 / I1 should wire it). Placement time is not
  logged by the engine.
