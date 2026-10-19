# Handoff: U2-read

The Read and record screen and its `ScoringController`, in `lib/ui/read/`. The
router's `ReadScreen(args: ReadArgs)` class name and constructor are unchanged. No
changes to `lib/core/`, `pubspec.yaml` or other agents' folders; no new packages.

## What was built

| File | What |
| --- | --- |
| `read_screen.dart` | `ReadScreen` (navigation, text size buttons, app-resume permission recheck) and `ReadBody` (renders one `ReadState`; public for goldens) |
| `read_state.dart` | `ReadState` (content, phase, `textScale`, `downloadNotice`), `ReadContent`, sealed `ReadPhase`: `ReadLoading`, `ReadLoadFailed`, `ReadIdle`, `ReadRecording(elapsed, levels)`, `ReadScoring(stage, progress)`, `ReadPermissionDenied(permanently)`, `ReadRetryNeeded(tooQuiet / tooNoisy / noSpeech)`, `ReadFailed`, `ReadDone(result, levelChange)` |
| `scoring_controller.dart` | `ScoringController` (`scoringControllerProvider(args)`, Riverpod `NotifierProvider.autoDispose.family` keyed by the route's `ReadArgs` object) and `recordingDeleterProvider` |
| `widgets/record_controls.dart` | `RecordButton` (tap or hold-to-record), `LevelWaveform`, `formatElapsed` |

### Screen

Level, passage number ("Level 3 · Passage 4 of 20", from `ContentRepository.byLevel`),
title and text. Text size: A- / A+ in the app bar, 20 sp x `UserProfile.textScale`
(0.8-1.6, steps of 0.1), saved back to the profile, so the size set in Settings (U4)
applies and vice versa. Reading column capped at 680 dp; wider padding at >= 600 dp.

States (each has widget tests at phone and tablet size):

- **loading** (spinner); **passage not found** (message + Go back);
- **idle**: big record button, "Tap and read aloud";
- **recording**: live waveform from `AudioRecorder.level`, m:ss timer (from
  `clockProvider`), stop button, "Tap to stop", "Stops by itself after 2 s of
  silence", Discard. Stops on tap, on `silenceDetected`, or after 3 minutes;
- **scoring**: "Scoring..." with the current step (checking the recording, loading
  the model, waiting for the download, listening to your sounds, comparing, saving),
  a progress bar and Cancel (hidden while saving);
- **permission denied** ("Allow microphone" re-prompts) and **permanently denied**
  ("Open settings"; rechecked when the app resumes);
- **too quiet / too noisy / no speech** (VAD found nothing): message + "Try again"
  (starts recording straight away);
- **model still downloading**: a card under the text while the wanted full tier
  downloads ("...still downloading (42%). Until then, readings use the light model:
  word scores only", or "...when you are on Wi-Fi"); while scoring waits for it,
  "Scoring starts when it finishes";
- **error** (recorder failed, model missing, scoring threw): message + Try again.

### ScoringController

Flow on stop: `AudioRecorder.stop` -> log practice time -> audio quality check ->
`speechSegments` (empty: no-speech retry) -> ensure a model tier -> `recognise` ->
`PronunciationScorer.score` / `scoreWord` -> save or return.

- **Tier choice** (the W0 gap). Wanted tier = `UserProfile.tierOverride`, else
  `recommendedTier()`. If it is on the phone it is loaded; otherwise the other tier
  is used (in practice: light while full is not downloaded). If neither is on the
  phone and a full download is running, scoring waits for it (showing its progress,
  cancellable); if not, it shows the "speech model isn't on this phone yet" error.
  `load` is only called when `loadedTier` differs, so once full finishes
  downloading, the next reading switches to it. The model is warmed up when the
  screen opens, so the first stop does not pay the load time.
- **Practice time** (the W0 gap). After every completed recording (tap, silence or
  time limit; not Discard) it calls `PracticeEngine.logPracticeTime(clip.duration)`,
  in passage, sentence and word modes, also for too-quiet / too-noisy clips (the user
  did read). Not in placement mode. Failures are swallowed.
- **Modes** (as decided in Wave 0):
  - `passage`: `score(passage, ..., audioPath: clip.path)` then
    `PracticeEngine.recordAttempt` (which saves); the screen replaces itself with
    `AppRoutes.results` + `ResultsArgs(result, levelChange)`.
  - `placement`: scores the whole passage, saves nothing, pops with the result.
  - `sentence`: scores `passage.slice(sentenceRange(wordIndex))`, maps word indices
    back to the passage, `passageId` = the passage's id, saves nothing, pops.
  - `word`: `scoreWord(passage.words[wordIndex], posteriors)`, wrapped in an
    `AttemptResult` with that one word (overall = accuracy = fluency = word score),
    saves nothing, pops.
  - Callers: `final r = await context.push<AttemptResult>(AppRoutes.read, extra:
    ReadArgs(...))` (null if the user backs out). Without go_router it pops through
    `Navigator`.
- **Cancel**: recognition cannot be interrupted (no contract support), so Cancel
  drops the run (a generation counter) and returns to idle; the model call finishes
  in its isolate and its result is ignored. Leaving the screen mid-recording cancels
  the recording.
- **Unsaved recordings are deleted** (retry states, cancel, errors, and every
  non-passage mode) through `recordingDeleterProvider` (default: `dart:io` delete,
  errors ignored). Passage-mode files belong to `ProgressRepository.saveAttempt`,
  which keeps or deletes them per `keepRecordings`.
- Progress during recognition is an estimate: 15% -> 80% over clip length x 0.5
  (`recognitionRealTimeFactor`, from A2's desktop measurements), then creeping to 90%.

### Record widget for U3

`RecordButton` supports hold-to-record: pass `onHoldStart` (call
`AudioRecorder.start`) and `onHoldEnd` (call `stop`; also fires on pointer cancel)
instead of `onTap`. `LevelWaveform(levels: ...)` draws recent `AudioRecorder.level`
values. Both use only theme colours. U3 built its own control in Wave 1; contract
request 1 proposes moving these to a shared folder.

## Tests

- `test/ui/read/scoring_controller_test.dart`: 47 unit tests (loading, tier choice
  incl. override / fallback / switch after download / waiting for download / failed
  download / no model, download notice, practice time per mode, every mode's result
  and saving behaviour, level change, recording / waveform / timer / silence / time
  limit / discard, audio checks, permission paths, cancel, errors, text size).
- `test/ui/read/read_screen_test.dart`: 40 widget tests (18 states and flows x phone
  390x844 and tablet 820x1180, plus Navigator pop and `RecordButton` hold/disabled).
- `test/ui/read/read_test_helpers.dart`: `ReadHarness` (all providers overridden with
  fakes, injectable clock, recorded deletions), `TestRecognizer`, `SpyPracticeEngine`.
- Goldens `test/ui/goldens/read_screen_golden_test.dart`: `read_screen_phone` (idle,
  recording, scoring, permission denied, too noisy, model downloading; light + dark)
  and `read_screen_tablet` (idle, recording, scoring; light + dark).
- Coverage of `lib/ui/read/`: see the final check below.

Test notes: the fake progress repository checks the audio file with real I/O, so
passage-mode widget tests let it finish with `tester.runAsync`. Stream-subscription
cancels in the controller are deliberately not awaited (under the widget test's fake
clock that future never completed).

## Switch-over to U1 (after merge)

U1's branch adds `Breakpoints` (readingWidth 680, twoPane 720),
`AppTypography.passage` (18-22 sp from `textScale`) and `LoadingView` / `MessageView`.
I kept small local equivalents: `maxReadingWidth = 680`, `basePassageFontSize = 20`
x textScale (clamped 0.8-1.6, so 16-32 sp; U1's passage style is 18-22 sp), a private
`_Message` widget and a plain spinner. After merge, I1 or U2 can swap to U1's helpers
(three small edits in `read_screen.dart`) and agree one text-size range with U1/U4.

## Known gaps

- Only fakes: no real recorder / model run here (no emulator). Recording start time
  (< 300 ms) and real scoring latency are untested.
- Progress during recognition is an estimate, and Cancel can't stop the model call
  (contract request 3).
- Unsaved clips are deleted with `dart:io` from the UI layer (contract request 2).
- No "score anyway" option for too-noisy clips.
- The text size range differs from U1's 18-22 sp (see above).
- In sentence mode the shown sentence ends at its last word (no final full stop),
  because `Passage.slice` cuts the text at word boundaries.
