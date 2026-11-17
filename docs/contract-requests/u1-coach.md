# Contract requests: U1 (Coach tab)

Owner: the Coach tab work on `feat/coach-tab`. Nothing here blocks the tab, which uses
a local constant until the change is merged.

## 1. Add `AppRoutes.coach` (optional, small)

**What.** In `lib/core/contracts/navigation.dart`, add to `AppRoutes`:

```dart
/// Coach tab: guided exercises and the exercise library.
static const coach = '/coach';
```

**Why.** The Coach route path is currently `coachPath` in
`lib/ui/coach/coach_routes.dart`, because the contracts are frozen after Wave 0.
Every other tab path lives in `AppRoutes`.

**Affects.** `lib/ui/shell/app_router.dart` (replace `coachPath` with `AppRoutes.coach`
in the branch, `_gatedPaths` and the test imports), and delete
`lib/ui/coach/coach_routes.dart`. No fake or model changes. `test/contracts/` does not
need a new case.

## 2. No other contract changes

The Coach tab uses only existing contracts: `ProgressRepository.soundStats()`,
`ProgressRepository.changes`, `ContentRepository.minimalPairs()`, `Tips.tipFor`,
`PracticeEngine.nextPassage(soundTag:)` and `VoiceService.speak/stop`.
