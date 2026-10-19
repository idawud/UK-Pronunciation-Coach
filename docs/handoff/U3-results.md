# Handoff: U3-results

Results (`lib/ui/results/`) and Fix a word (`lib/ui/fix/`), built against the contracts
and fakes only. Class names and constructors of `ResultsScreen(args: ResultsArgs)` and
`FixScreen(args: FixArgs)` are unchanged, so the router builds them as before. No edits
outside my folders except this note, `docs/contract-requests/U3-results.md` and tests.
No new dependencies.

## What was built

| File | What |
| --- | --- |
| `results/results_screen.dart` | Overall ring, accuracy / fluency bars, `LevelChange` card (up / down), passage title and coloured text, legend, "Tap any word to hear it and try again", sticky "Fix N red words" + "Next passage". Two panes at >= 720 dp (scores left, passage right, reading width capped at 680). Passage text size follows `UserProfile.textScale` (20 sp x scale). |
| `results/passage_text.dart` | `PassageText`: `Text.rich` with one `TextSpan` per word (keeps the original punctuation via `WordSpec.offset`, falls back to words joined by spaces), tap recognisers, semantics labels ("Thursday, 58, Fix"); optional `start`/`end` to show one sentence. |
| `results/word_status_style.dart` | Colour from `ScoreColors.of(context)` plus the non-colour cue: close = dotted underline, fix / missed = bold solid underline + error icon after the word, not scored = grey italic. `ScoreBadge` pill ("58 Fix" with icon). |
| `results/score_summary.dart` | `ScoreSummary`, `ScoreLegend`, `LevelChangeCard`. |
| `results/word_sheet.dart` | Bottom sheet for a tapped word (see "Retry" below). |
| `fix/fix_screen.dart` | Fix a word flow (below). |
| `fix/word_practice.dart` | Shared word panel: word + score badge, British IPA (with stress), "You said" IPA, sound chips, tip from `Tips.tipFor`, Play British / Play slowly (`VoiceService.slowRate` 0.6), hold-to-record. Light tier: word score only (no heard IPA, chips or tip; British IPA still shown). Missed and not-scored words explain themselves; not-scored words have no record button. |
| `fix/sound_chips.dart`, `fix/sound_marks.dart` | One chip per expected sound; wrong sounds get the fix colour, a thick border, an icon and a note: `heard /t/` (substitution), `missing` + strikethrough (`heard == ''`, dropped), `added r` (`heard == vowel + ɹ/r`). IPA helpers `expectedIpa`, `heardIpa`, `worstSound`. |
| `fix/hold_to_record.dart` | `HoldToRecordButton`: `AudioRecorder.start` on pointer down, `stop` on up (ignores `silenceDetected`), level ring while recording, then `PhonemeRecognizer.recognise` + `PronunciationScorer.scoreWord`. Loads the attempt's tier if nothing is loaded, falling back to light on `ModelNotAvailableException`. States: permission denied ("Allow microphone" -> `requestPermission`), permanently denied ("Open settings"), start failure, clip < 300 ms ("Hold the button down..."), too quiet, too noisy, scoring failure. Cancels a recording when disposed. |

### Retry on Results

Tap a word -> sheet with expected vs heard IPA, score, chips, tip, play buttons and
hold-to-record. Each scored retry replaces the word in the sheet **and** on the Results
screen at once (colour, red-word count), and is saved with
`ProgressRepository.updateWordResult(attemptId, word)`; the attempt's overall /
accuracy / fluency stay unchanged, matching the contract. A failed save shows a snack
bar but keeps the local update. If the passage cannot be loaded, the words are shown
plain-joined with a note and retries are off (no `WordSpec`).

### Fix a word

- Words: `FixArgs.wordIndexes ?? result.redWords`. Shows "Word i of N", progress bar,
  the word panel, "Reading score / Last score <badge> Target 80".
- Repeat until 80+ (then "Next") or "Skip". When the user moves on, the word's **last
  try** is saved with `updateWordResult` (nothing is saved for a word with no tries).
- Sentence step: after the last word of a sentence (`Passage.sentenceRange`) in which at
  least one word reached 80+, the user is asked once to say the whole sentence:
  `context.push<AttemptResult>(AppRoutes.read, extra: ReadArgs(mode: ReadMode.sentence,
  wordIndex: <fixed word>))`. The returned sentence result is shown coloured with its
  overall score; it is **not saved** (read route "saves nothing; the caller decides" —
  I chose not to overwrite single-word scores). Null result or "Skip" moves on. Several
  red words in one sentence share one sentence step.
- Done: "Fixed X of N words" with old -> new scores, "Back to results".
- Fix pops with the updated `AttemptResult` (close button, done button or system back
  via `PopScope`); Results awaits it and refreshes. States: loading, empty ("No red
  words to fix"), error (unknown passage or invalid index).

## Tests

- `test/ui/results/results_screen_test.dart` (15), `test/ui/fix/fix_screen_test.dart`
  (13), `test/ui/fix/hold_to_record_test.dart` (11), `test/ui/fix/sound_marks_test.dart`
  (4). Shared harness `test/ui/results/harness.dart` (GoRouter with a stub Read route
  that pops a configurable result; `tapWord`, `wordStyle`, `holdAndSay`).
- Covered: retry loop on both screens (fake scorer 45 -> 72 -> 88), saving, light tier,
  skip, sentence step (read / skip / back without result / shared sentence), level
  up/down, missed / not-scored words, empty attempt, passage load error, save error,
  next-passage error, permission denied / permanently denied, too quiet / noisy / short,
  scoring failure, cancel on dispose, phone and tablet.
- Goldens `test/ui/goldens/results_golden_test.dart`: Results, word sheet and Fix a word,
  light + dark, phone + tablet, plus Results light tier: 7 golden files (14 variants
  with the CI obscured-text copies).
- Coverage: `lib/ui/results` + `lib/ui/fix` 816/823 lines (99%); `lib/ui/` 99.3%.
  `scripts/check.sh` passes.

## Known gaps / notes for others

- **Goldens use the W0 placeholder theme.** U1 is changing `AppTheme` in parallel; after
  merging U1, regenerate on Linux: `flutter test --update-goldens --tags golden
  test/ui/goldens/results_golden_test.dart`.
- **Two-pane breakpoint and width cap are local constants** (720 / 680 dp). Switch to
  U1's responsive helper once merged.
- **Hold-to-record is my own control**, not U2's record widget (U2 builds tap-to-record in
  `lib/ui/read/` in parallel; I did not import it). They could be merged into one shared
  widget later. Screen-reader users get a labelled button, but a hold gesture is hard
  with TalkBack / VoiceOver; a tap-to-start / tap-to-stop alternative should be added
  (I1 or a follow-up).
- **No "play my recording"**: no contract for it; proposed in
  `docs/contract-requests/U3-results.md`, along with deleting retry clips (each try leaves
  a WAV in app-private storage unless A1 cleans up).
- Retries use the attempt's tier for display (`AttemptResult.tier`); if the loaded model
  is a different tier the retry score still comes from whatever is loaded.
- `PracticeEngine.logPracticeTime` is not called for time spent fixing words; I1 should
  decide where practice time is logged.
- "Next passage" uses `context.pushReplacement(AppRoutes.read, ...)` with the passage
  from `PracticeEngine.nextPassage()`.
