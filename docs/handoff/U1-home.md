# Handoff: U1-home

App shell, theme, Home, first-run flow and Practise tab, all against the fakes through
`lib/core/providers.dart`.

## What was built

| Area | Where |
| --- | --- |
| Theme: Material 3 light/dark from a navy seed, larger body text, card/button styles, bundled IPA font as fallback on every text style | `lib/ui/theme/app_theme.dart` |
| Score colours (WCAG AA checked on surface + all surface containers, both themes) | `lib/ui/theme/score_colors.dart` |
| Non-colour cues: `ScoreCue`, `ScoreIcon`, `ScoreBadge`, `ScoreLegend` | `lib/ui/theme/score_cue.dart` |
| Typography: passage style 18-22 sp, `passageTextSizeProvider`, IPA style | `lib/ui/theme/typography.dart` |
| Responsive helpers: `Breakpoints`, `WindowSize`, `context.isTablet/useTwoPane/pagePadding`, `ReadingWidth`, `TwoPane` | `lib/ui/theme/responsive.dart` |
| Barrel for all of the above | `lib/ui/theme/theme.dart` |
| Router: onboarding redirect, `?tab=` for Practise, nav bar on phones / rail from 840 dp | `lib/ui/shell/app_router.dart` |
| Shared state views: `LoadingView`, `MessageView`, `MessageView.error(onRetry:)` | `lib/ui/shell/state_views.dart` |
| Home: greeting, level + progress to next level, streak, today's minutes, "Start today's passage", weak sounds (top 3), words due | `lib/ui/home/` |
| First-run flow: welcome, microphone (granted / denied / permanently denied), British voice check (play sample / install help), placement (3 passages via the Read route, `ReadMode.placement`), starting level | `lib/ui/onboarding/onboarding_screen.dart` |
| Practise tab: Library by level (locked above level + 1), Weak sounds (opens `nextPassage(soundTag:)`), Words due (opens Fix a word) | `lib/ui/practise/` |
| IPA font: Noto Sans Regular, family `NotoSansIPA`, SIL OFL 1.1 (row added to `docs/licences.md`) | `assets/fonts/` |

Class names and constructors the router builds are unchanged. Added optional params only:
`PractiseScreen({initialTab})`, `OnboardingScreen({initialStep})` (tests/goldens).

## Guide for U2 / U3 / U4

```dart
import '../theme/theme.dart';   // ScoreColors, ScoreCue, AppTypography, ReadingWidth, TwoPane, Breakpoints
import '../shell/state_views.dart';   // LoadingView, MessageView
```

- **Colours**: `ScoreColors.of(context).forStatus(status)` (or `.forScore(score)`). Never
  hard-code; other colours come from `Theme.of(context).colorScheme`.
- **Non-colour cue** for passage words: `ScoreCue.wordStyle(context, status, base: style)`
  gives colour + underline (dashed for close, thick solid for fix/missed). After red words
  add `ScoreIcon(status)` (`ScoreCue.showsIconInText(status)`). Scores: `ScoreBadge(score: 72)`.
  Legend: `const ScoreLegend()`. Semantics label: `ScoreCue.label(status)`.
- **Passage text size**: `final size = ref.watch(passageTextSizeProvider);` then
  `AppTypography.passage(context, size: size)`. U4 Settings saves
  `profile.copyWith(textScale: AppTypography.textScaleForSize(sp))` (18-22 sp, 20 = 1.0).
- **IPA**: `Text(AppTypography.slashes(phonemes), style: AppTypography.ipa(context))`.
  Uses the bundled font, so every symbol renders on every device and in goldens
  (alchemist loads pubspec fonts).
- **Layout**: wrap reading content in `ReadingWidth(child: ...)` (caps at
  `Breakpoints.readingWidth` = 680 dp). Two panes: `TwoPane(primary:, secondary:, narrow:)`
  switches at `Breakpoints.twoPane` = 720 dp using its own constraints (so the 820 dp
  tablet golden is two-pane). U3: replace your local 720 / 680 constants with these.
  `context.isTablet`, `context.useTwoPane`, `context.windowSize`, `context.pagePadding`
  use `MediaQuery` (whole window).
- **States**: `LoadingView()`, `MessageView.error(onRetry: ...)`,
  `MessageView(icon:, title:, message:, actionLabel:, onAction:)` for empty and
  permission-denied states.
- **Placement**: onboarding pushes `/read` with `ReadArgs(passageId, mode: ReadMode.placement)`
  and expects U2 to `pop` with the `AttemptResult` (null = user backed out). The reader
  is `placementReaderProvider` (override in tests).

## Tests

- Widget/unit: `test/ui/home/`, `test/ui/practise/`, `test/ui/onboarding/`,
  `test/ui/shell/` (router, redirect, rail), `test/ui/theme/` (AA contrast for 4 tokens x
  6 backgrounds x 2 themes, cues, typography, responsive, state views). Helpers in
  `test/ui/shell/harness.dart` (seeded fakes, fixed clock, stub-route router).
- Goldens (`test/ui/goldens/`): `home` (phone/tablet x light/dark), `home_empty`,
  `practise` (3 sections + tablet dark), `onboarding` (8 steps/states incl. dark and tablet).
- States covered: loading, empty, error with retry, mic denied / permanently denied,
  no British voice, placement read failure / abandoned read.

## Edits outside my folders

- `pubspec.yaml`: `fonts:` block for `NotoSansIPA` (no new dependencies).
- `assets/fonts/NotoSans-Regular.ttf` + `NotoSans-OFL.txt` (620 KB).
- `docs/licences.md`: one row for the font.
- `test/app_test.dart` (W0): the app now opens onboarding on first run, so the
  "starts on home" test seeds `onboardingDone: true`, and a first-run test was added.

## Known gaps

- Onboarding redirect is in the router: e2e journeys (I1) must finish or skip onboarding,
  or seed `onboardingDone: true`. The redirect reads the profile on every tab navigation
  (cheap; fails open if the profile cannot be read).
- Home progress bar = latest run of passages at 85+ since the last level change (0-3),
  computed in `home_data.dart` from attempts + level history; C3 owns the real rule.
- A due word with no saved attempt containing it opens a word retry in Read
  (`ReadMode.word`) for its passage instead of Fix a word; with no passage, a snackbar.
- No `PracticeEngine.logPracticeTime` calls from U1 screens (U2 should log reading time).
- Not run on a device or emulator; goldens generated locally on Linux.
