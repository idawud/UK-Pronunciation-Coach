# lib/ui/coach (Coach tab, branch feat/coach-hub)

The Coach tab is a hub of section cards. Each card opens a sub-route under `/coach`.
Nothing here is scored; the coach speaks model lines and the user copies them.

## Layout

- `coach_hub_screen.dart`: `CoachScreen`, the tab's root. AppBar "Coach", one `Card` per
  entry in `coachSections`, and a "Reset Coach data" action (confirm dialog, then
  `coachStoreProvider.clear()`). Layout uses `ReadingWidth`.
- `coach_sections.dart`: `CoachSection` and the `coachSections` registry. The router
  nests one `GoRoute` per entry under `/coach`. Entries hold only metadata and a
  builder; no logic.
- `coach_routes.dart`: `coachPath` (`/coach`) and one `coach<Section>Path` per
  section (`/coach/sounds`, `/coach/confusions`, `/coach/words`, `/coach/record`,
  `/coach/describe`, `/coach/ipa`).
- `sounds/`: the Sounds section (weakest sounds and the exercise library), moved from
  the original Coach screen.
  - `sounds_screen.dart`: `SoundsScreen`. Guided section first (empty state included),
    then the library in `ExpansionTile`s. Captures `VoiceService` in `initState` and
    stops speech on dispose.
  - `coach_data.dart`: `GuidedExercise`, the pure `buildGuidedExercises` and
    `coachDataProvider` (autoDispose, refreshes on `progressChangesProvider`).
  - `coach_exercises.dart`: `CoachCategory`, `CoachExercise` and the fixed `coachLibrary`.
  - `coach_speech.dart`: `CoachSpeech`, a play and stop helper with a generation token.
- `ipa/`: the IPA lessons section (its hub card is the sixth entry in `coachSections`).
  - `ipa_content.dart`: the 44 sounds (12 vowels, 8 diphthongs, 24 consonants) as
    const `IpaSound`s, the intro lesson and the group and manner enums. Symbols match the
    scorer's phoneme inventory (`lib/engine/scoring/data/phoneme_map.dart`).
  - `ipa_quiz.dart`: pure `buildIpaQuizQuestion` for the Quick check (injectable `Random`).
  - `ipa_providers.dart`: `IpaRepository` (learned symbols under the `ipa` store key,
    `{learned: [...]}`), `ipaLearnedProvider` and `ipaRandomProvider`.
  - `ipa_screen.dart`: `IpaScreen` (hub), the intro, the grid (`IpaGridScreen`, one group
    or the full chart) and `IpaSymbolChip`. Sub-pages use the navigator.
  - `ipa_sound_screen.dart`: `IpaSoundScreen`. Play buttons speak whole example words
    (normal and slow), because the voice cannot say one sound on its own.
- `confusions/`, `words/`, `record/`, `describe/`: stub screens (`ConfusionsScreen`,
  `WordsScreen`, `RecordCompareScreen`, `DescribeScreen`). Each shows "Coming soon".
  **To build a section, overwrite only its stub file.** Keep the class name and
  constructor; the registry and router already point at it.

## Storage

`lib/data/coach/coach_store.dart`: `CoachStore` (read, write, clear by key),
`JsonFileCoachStore` (one `coach_store.json` in the documents directory, atomic write,
`version: 1`, feature data under `data`), `InMemoryCoachStore` for tests, and
`coachStoreProvider` (defaults to the JSON file store; tests override it). Feature keys:
`confusions`, `lostWords`, `chunks`, `circ`, `shadow`.

## Rules

- Routing: the hub is a tab branch, so the tab bar stays on Coach for every sub-route.
  Sub-routes are gated by onboarding like the tab (`onboardingRedirect` in
  `lib/ui/shell/app_router.dart`).
- Theme tokens only (`Theme.of(context)`, `ScoreColors`, `AppTypography`).
- Contract changes that would make this cleaner (`AppRoutes.coach*`, `CoachStore` in
  backup and delete-all, an audio player, a lost-word hook) are in
  `docs/contract-requests/coach-hub.md`.

Tests: `test/ui/coach/` (hub, sections, sounds), `test/ui/coach/sounds/` (Sounds
screen and its helpers), `test/ui/coach/ipa/` (IPA content, quiz, progress and screens),
and `test/data/coach/` (store).
