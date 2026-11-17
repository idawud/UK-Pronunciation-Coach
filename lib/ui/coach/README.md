# lib/ui/coach (Coach tab, branch feat/coach-tab)

A simple speech-therapy coach: a fifth bottom-nav tab between Progress and Settings.
Nothing is scored; the coach speaks a model line and the user copies it.

- `coach_routes.dart`: `coachPath` (`/coach`). Replace with `AppRoutes.coach` once the
  contract change in `docs/contract-requests/u1-coach.md` is merged.
- `coach_exercises.dart`: `CoachCategory`, `CoachExercise` and the fixed `coachLibrary`
  (warm-ups, tongue twisters, pace and breathing).
- `coach_data.dart`: `GuidedExercise`, the pure `buildGuidedExercises` (weakest sounds
  with attempts > 0, up to 3 minimal pairs each, first non-null tip) and
  `coachDataProvider` (autoDispose, refreshes on `progressChangesProvider`).
- `coach_speech.dart`: `CoachSpeech`, a small play and stop helper. Each play or stop
  bumps a generation token, because `VoiceService.speak` completes on finish or stop.
  `playing` tells each button whether to show play or stop.
- `coach_screen.dart`: `CoachScreen`. The guided section comes first (empty state
  included), then the library in `ExpansionTile`s. The screen captures the
  `VoiceService` in `initState` and stops speech on dispose.

Tests: `test/ui/coach/`. Theme tokens only (`ScoreColors`, `AppTypography`), and
`ReadingWidth` for layout.
