# Handoff: W0-scaffold

Wave 0 scaffold on `main`: Flutter skeleton, frozen models and contracts, working fakes,
shared contract test suites, fixtures, golden setup, CI and docs. **A human should review
this before Wave 1 starts** (see "Review before Wave 1" at the end).

## What was built

| Area | Where |
| --- | --- |
| Flutter app `uk_pronunciation_coach` (Flutter 3.47.7 / Dart 3.13.5), Android minSdk 29, iOS 16.0, portrait + landscape, Riverpod 3, go_router 18, freezed 4, flutter_lints, mocktail, alchemist, integration_test | `pubspec.yaml`, `android/`, `ios/` |
| Microphone, Wi-Fi download and notification permissions; iOS microphone text ("Recordings stay on your phone") | `AndroidManifest.xml`, `Info.plist` |
| Spec working copy | `docs/SPEC.md` |
| Models (freezed + json, pure Dart) | `lib/core/models/` |
| Contracts (pure Dart, doc-commented) | `lib/core/contracts/` |
| Working fakes + sample data | `lib/core/fakes/` |
| Providers: every contract bound to its fake in one file | `lib/core/providers.dart` |
| Placeholder app: shell with 4 tabs, every route in `AppRoutes`, placeholder screens with fixed class names, theme with `ScoreColors` | `lib/app.dart`, `lib/ui/**` |
| Shared contract suites, run against the fakes | `test/contracts/` |
| Model round-trip, helper, fake, provider, router and screen tests; pure-Dart import guards | `test/core/`, `test/ui/`, `test/engine/scoring/pure_dart_test.dart` |
| One passing placeholder test per Wave 1 folder (Dart and Python) | `test/**/placeholder_test.dart`, `tools/{models,content,eval}/tests/` |
| Fixtures: 7 WAV clips + manifest, canned passages / posteriors / result JSON, fonts | `test/fixtures/` (README there) |
| Golden setup (alchemist, bundled Roboto / Material Icons / DejaVu Sans for IPA) | `test/flutter_test_config.dart`, `test/helpers/golden.dart`, `test/ui/goldens/` |
| CI scripts with pytest (98% coverage) | `tools/ci/` |
| Local check | `scripts/check.sh` |
| Workflows, dependabot, PR template | `.github/` |
| Docs | `docs/testing.md`, `docs/ci.md`, `docs/licences.md`, `docs/contract-requests/README.md` |
| Folder READMEs naming each owner | every folder in step 3 of the W0 prompt, plus `lib/data/content`, `lib/engine/scoring/config`, `assets/models`, `integration_test/W0-scaffold` |

## Contract summary

Models (`lib/core/models/models.dart`): `PhonemeSpec`, `WordSpec` (+ `offset` into the
passage text), `Passage` (+ `sentenceRange`, `slice` for sentence/word retries),
`AudioClip` (+ `quality: AudioQuality {ok, tooQuiet, tooNoisy}`, `peakDbfs`, `snrDb`),
`Segment`, `PhonemePosteriors` (`List<Float32List>` log-softmax frames, `blankIndex`,
`frameMs`, `tier`), `PhonemeResult`, `WordResult`, `WordStatus` {good, close, fix,
notScored, missed} (+ `fromScore`, `isRed`), `AttemptResult` (+ `tier`, `redWords`),
`SoundStat` (+ shared EMA `update`), `UserProfile` (+ settings: `reminderMinutes`,
`textScale`, `tierOverride`, `placementLevel`, `onboardingDone`), `LevelChange`,
`ReviewItem` (+ shared 1/3/7/21-day `afterScore`), `PracticeSession`, `DailyProgress`,
`MinimalPair`, `ModelDownloadProgress` + `DownloadState`, `ProgressBackup` (export
format), enums `ModelTier {light, full}`, `MicPermission`.

Contracts (`lib/core/contracts/contracts.dart`):

- `AudioRecorder`: `checkPermission`, `requestPermission`, `openPermissionSettings`,
  `isRecording`, `start`, `stop -> AudioClip`, `cancel`, `level` (0-1, ~20/s),
  `silenceDetected` (2 s after speech, caller decides to stop; hold-to-record ignores
  it), `speechSegments(clip)`, `dispose`.
- `PhonemeRecognizer`: `recommendedTier()` (async), `isTierAvailable`, `loadedTier`,
  `load(tier)`, `recognise(clip)`, `fullModelSizeBytes`, `downloadStatus`,
  `downloadProgress` stream, `downloadFullModel({requireWifi})`, `cancelDownload`,
  `deleteFullModel`, `dispose`.
- `PronunciationScorer`: `score(passage, posteriors, speech, {attemptId, at, audioPath})`,
  `scoreWord(word, posteriors)` (synchronous, pure Dart). `Tips.tipFor(expected, heard)`.
- `ContentRepository`: `all`, `byLevel`, `byId`, `placementPassages`, `lookup`,
  `minimalPairs`.
- `ProgressRepository`: `changes`, `saveAttempt`, `attempt`, `attempts({passageId,
  since, limit})`, `updateWordResult`, `soundStats`, `profile`, `saveProfile`,
  `reviewQueue`, `dueReviews`, `upsertReview`, `removeReview`, `saveLevelChange`,
  `levelHistory`, `logPractice`, `practiceSessions`, `exportJson`, `importJson`,
  `deleteAll`.
- `PracticeEngine`: `currentLevel`, `nextPassage({soundTag})`, `recordAttempt -> LevelChange?`
  (it saves the attempt), `dueReviewWords`, `dueReviews`, `weakestSounds`,
  `logPracticeTime`, `dailyProgress`, `placementPassages`, `placementLevel`,
  `completePlacement`.
- `VoiceService`: `speak(text, {rate})`, `stop`, `hasBritishVoice`, `voiceName`,
  `normalRate` 1.0 / `slowRate` 0.6.
- Typed errors (`MicPermissionException`, `ModelNotAvailableException`,
  `ModelDownloadException`, `PassageNotFoundException`, `AttemptNotFoundException`),
  `Clock`, and navigation: `AppRoutes` paths plus `ReadArgs` / `ReadMode {passage,
  sentence, word, placement}`, `ResultsArgs`, `FixArgs` passed as go_router `extra`.

UI seams: the router (`lib/ui/shell/app_router.dart`) already builds `HomeScreen`,
`PractiseScreen`, `OnboardingScreen`, `ReadScreen(args)`, `ResultsScreen(args)`,
`FixScreen(args)`, `ProgressScreen`, `SettingsScreen`, `LicencesScreen`. Each owner
replaces the body and keeps the class name and constructor. Colours come from
`ScoreColors.of(context)` (U1 sets the values).

## How to run checks

```bash
export PATH="$HOME/flutter/bin:$PATH"     # if Flutter is not on PATH
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements-dev.txt   # once
scripts/check.sh                          # format, analyze, tests + coverage gate,
                                          # goldens (Linux), ruff + pytest, content, licences
```

Result on this machine (Linux, WSL2): **`scripts/check.sh` passes**: 154 Dart tests
(including 2 golden variants), coverage gate passes (`lib/ui/` 100%; engine / practice /
data have no code yet and are skipped), ruff clean, 30 pytest tests at 98% coverage,
content check skipped with a notice (no bundle yet), licence check passes.
`build_runner` output was regenerated from scratch and matched the committed files.
actionlint 1.7.7 reports no problems in the workflows.

## Not verified locally

- **Android and iOS builds**: no Java / Android SDK / Xcode here. `build-android`,
  `integration.yml` (emulator and simulator) and the integration tests in
  `integration_test/` have only been analysed, not run. The Android project uses the
  Flutter 3.47 template (AGP 9.1, Gradle 9.3.1, Kotlin 2.4, JDK 17 in CI).
- **Golden images on GitHub's ubuntu runners**: generated locally on Linux with the same
  pinned Flutter version and bundled fonts; they should match, but the first CI run is
  the real test. If they differ, regenerate them on CI's image.
- **GitHub Actions versions** (`actions/checkout@v5`, `setup-python@v6`,
  `setup-java@v5`, `upload-artifact@v4`, `cache@v4`, `subosito/flutter-action@v2`,
  `reactivecircus/android-emulator-runner@v2`) were chosen from memory; dependabot will
  bump them.
- Branch protection is not configured (docs/ci.md lists the required checks).

## Tooling notes

- Flutter was installed by cloning the stable channel to `~/flutter`; `unzip` (and
  eSpeak NG, used only to generate fixture speech) were extracted from Ubuntu .debs into
  `~/.local/root` because there is no sudo. Python tools live in `.venv/` (git-ignored).
- `dart run build_runner build --delete-conflicting-outputs` (as written in CLAUDE.md)
  still works but the new build_runner ignores that flag with a warning; plain
  `dart run build_runner build` is enough.

## Known gaps and decisions

- **Native plug-ins are not in `pubspec.yaml`** (record, permission_handler,
  sherpa_onnx/onnxruntime, drift, flutter_tts, fl_chart, flutter_local_notifications,
  connectivity). Each owning agent adds its own, so `pubspec.yaml` / `pubspec.lock`
  will need trivial merge resolution as Wave 1 merges. I did not pre-add them because I
  could not verify the Android build locally. Permissions are already in the manifests.
  If a plug-in needs `android/` or `ios/` config (e.g. Podfile macros for
  permission_handler, core library desugaring for flutter_local_notifications), that
  agent must make a minimal change and list it in its handoff, since R1 owns those
  folders only for signing.
- Fixture speech is eSpeak NG (robotic). Good for recorder / VAD / quality tests, not for
  accuracy. Canned posteriors are synthetic, not model output for the WAVs.
- Nothing calls `PracticeEngine.logPracticeTime` yet: U2 (or the shell) should log time
  spent reading; I1 should check it is wired.
- Nothing decides which tier to `load()` at start-up: U2's `ScoringController` (or I1)
  should load `profile.tierOverride ?? recommendedTier()`, falling back to light when
  the full tier is not available.
- No contract for playing back the user's own recording (Results "play" is the British
  voice); record-and-compare is v1.1 (F4).
- Fixture-audio injection into the real recorder for e2e is A1 / I1's design (not in the
  contract).
- On-device IPA rendering relies on system font fallback; goldens use DejaVu Sans via
  `withTestFonts`. U1 may want to bundle an IPA-capable font.
- `content` CI job only checks the bundle if present; C1 must add the rebuild-and-diff
  step to ci.yml (noted in the workflow). That edit is outside C1's folders: allow it or
  have I1 do it.

## Review before Wave 1

1. Contract shapes in `lib/core/contracts/` and the extra model fields beyond the W0
   prompt (`WordSpec.offset`, `AudioClip.quality/peakDbfs/snrDb`, `PhonemePosteriors.
   blankIndex/frameMs/tier`, `AttemptResult.tier`, `UserProfile` settings fields,
   `ReviewItem`, `PracticeSession`, `DailyProgress`, `MinimalPair`,
   `ModelDownloadProgress`, `ProgressBackup`). They are frozen once Wave 1 starts.
2. Shared rules placed in models so C2 and C3 agree: review intervals and reset rule
   (`ReviewItem.afterScore`: 80+ advances, under 60 resets, 60-79 repeats; graduates
   after 21 days), EMA alpha 0.3, sentence splitting.
3. Who saves what: `PracticeEngine.recordAttempt` saves passage attempts;
   `ProgressRepository.updateWordResult` keeps the attempt's totals unchanged and
   updates sound stats + review queue; placement attempts are not saved.
4. The navigation contract (`ReadMode` semantics: passage mode records and goes to
   Results; sentence / word / placement modes pop with the result and save nothing).
5. The decision to leave native plug-ins out of `pubspec.yaml` (above).
6. `PronunciationScorer` contract semantic checks (perfect read >= 80 accuracy with no
   red words; substituted phoneme scores lower and reports `heard`; missed word marked
   `missed`) are the bar A3 must meet.
