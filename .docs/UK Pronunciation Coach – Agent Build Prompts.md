# UK Pronunciation Coach – Agent Build Prompts

Oct 18, 2026 · @Dawud Ismail

The spec splits into 1 setup prompt, 12 parallel prompts, 2 integration prompts and 1 release prompt; each agent works in its own git worktree and owns its own folders, so they never edit the same files.

## How to run the build

Run Wave 0 alone and merge it to `main`. Then start all Wave 1 agents at once, each in its own worktree branched from that commit. Run Wave 2 once Wave 1 is merged.

**Worktree setup (one per agent):**

```bash
git worktree add ../coach-a1-audio -b feat/a1-audio main
git worktree add ../coach-a2-runtime -b feat/a2-runtime main
# ...one line per Wave 1 agent, using the IDs below
```

**Paste this preamble at the top of every Wave 1 and Wave 2 prompt:**

```text
You are one of several agents building "UK Pronunciation Coach", an offline Flutter app
(iOS + Android) that scores how closely a user's reading matches Standard Southern British
English. The full spec is in docs/SPEC.md. Shared types and interfaces are in
lib/core/contracts/ and lib/core/models/ - treat them as frozen.

Rules:
1. Only create or edit files inside the folders listed under "You own". If a contract must
   change, do not edit it: write the proposed change in docs/contract-requests/<your-id>.md.
2. No paid or cloud APIs. No network calls at runtime. Only Apache-2.0, MIT, BSD or similar
   licences in anything shipped. Never ship GPL code (eSpeak NG is allowed only in tools/).
   No analytics, tracking or crash-reporting SDKs: no user data leaves the phone.
3. Code against the interfaces, never against another agent's implementation. Use the fakes
   in lib/core/fakes/ for anything you depend on.
4. Testing is part of done (see docs/testing.md):
   - Unit tests for all logic; widget and golden tests for every screen; pytest for any
     Python in tools/. Tests live in test/ mirroring your lib/ path.
   - If you implement a contract, run its shared suite from test/contracts/ against your
     implementation and make it pass.
   - If your code uses a native plug-in (audio, ONNX, SQLite, TTS), add on-device tests in
     integration_test/<your-id>/ using fixture files, never a real microphone or network.
   - Keep coverage at or above the gate for your folders. Run scripts/check.sh before every
     push; your pull request must pass every GitHub Actions check. Never skip or delete a
     failing test to get green: fix it or record why in your handoff note.
5. Keep commits small with clear messages. Finish with a short summary in
   docs/handoff/<your-id>.md: what you built, how to use it, known gaps.
```

**Merge order for Wave 1:** any order, since folders do not overlap. Merge contract-request changes in a single small PR before Wave 2.

**Recommended: run an engine spike first.** The spec puts a 2-week go/no-go test before the MVP. Run A2, A3 and A4 plus a cut-down I2 on 50 sentences from 5 speakers. Start the other nine agents only if word agreement reaches 80%; otherwise the screens get built around scores nobody trusts.

## Build waves

&#91;embedded content: build waves · 1 setup agent, 12 parallel agents, 2 integration agents\]

The only link inside Wave 1 is the dashed one: A4's model files replace the development model A2 starts with. Every other agent depends only on Wave 0's contracts and fakes.

## Testing and CI

Every pull request must pass the same GitHub Actions checks before it merges, so 12 agents can't break each other's work. Wave 0 sets up the workflows; each agent adds tests in its own folders, and CI picks them up automatically.

**Contract test suites are the key to parallel work.** Wave 0 writes one shared test suite per contract (for example `runPhonemeRecognizerContract(factory)`). The fakes must pass it, and every real implementation must pass the same suite, so parts built separately fit together in Wave 2.

| Test layer | What it covers | Tool | Location | Coverage gate |
| --- | --- | --- | --- | --- |
| Unit | Scoring maths, alignment, level rules, review intervals, storage, tips | flutter\_test, mocktail | test/ mirroring lib/ | 85% for lib/engine/, lib/practice/, lib/data/ |
| Contract | Each real implementation behaves like its interface | Shared suites in test/contracts/ | test/contracts/ | Every contract has one |
| Widget | Every screen state: loading, empty, error, permission denied | flutter\_test | test/ui/ | 70% for lib/ui/ |
| Golden | Screens match the sketches, light and dark, phone and tablet | alchemist (fonts bundled) | test/ui/goldens/ | Linux CI only |
| Python | Content build, model export, eval harness | pytest, ruff | tools/\*/tests/ | 80% for tools/ |
| Content | Passage bundle schema, 20 per level, every scorable word has phonemes | Dart test + JSON schema | test/content/ | Must pass |
| On-device | Native parts: recording from fixture audio, ONNX inference, SQLite, TTS | integration\_test | integration\_test/\<agent-id>/ | Must pass |
| End-to-end | Full user journeys with network off | integration\_test | integration\_test/e2e/ | Must pass on main |
| Accuracy | Word agreement with teacher labels | tools/eval harness | tools/eval/ | 80% or higher |

**GitHub Actions workflows**

| Workflow | Runs when | Jobs | Owner |
| --- | --- | --- | --- |
| ci.yml | Every pull request and push to main | format, analyze, unit + widget + contract tests with coverage gate, golden tests, pytest, content check, licence check, debug Android build | W0 |
| integration.yml | Push to main, nightly, or a pull request labelled run-integration | Android emulator (API 34) on-device and e2e tests; iOS simulator build and tests nightly | W0 sets up, I1 completes |
| eval.yml | Manual and weekly | Accuracy harness on the stored eval set; fails under 80% | I2 |
| release.yml | Tag v\* | Signed Android AAB and iOS IPA, attached to a GitHub Release, optional upload to beta tracks | R1 |

**Required checks on main:** every ci.yml job. integration.yml must be green before any release tag.

**Cost note:** GitHub Actions is free for public repositories, and private ones get a monthly allowance of free minutes. macOS runners use that allowance much faster, so the iOS job runs nightly rather than on every pull request.

## Wave 0: scaffold and shared contracts

One agent, on `main`, before anything else. This step decides whether the parallel agents collide, so review its output yourself before starting Wave 1.

```text
ID: W0-scaffold
Goal: create the Flutter project skeleton and the frozen contracts every other agent codes against.

Do this:
1. Create a Flutter app "uk_pronunciation_coach" (iOS 16+, Android minSdk 29; phones and tablets, portrait and landscape), Dart null-safe,
   state management with Riverpod, routing with go_router. Add flutter_lints.
2. Copy the product spec into docs/SPEC.md.
3. Create this folder layout, each with a README naming its owner ID:
   lib/core/models/        (W0)   lib/core/contracts/   (W0)   lib/core/fakes/  (W0)
   lib/engine/audio/       (A1)   lib/engine/runtime/   (A2)   lib/engine/scoring/ (A3)
   tools/models/           (A4)   tools/content/        (C1)   assets/content/  (C1)
   lib/data/               (C2)   lib/practice/         (C3)   lib/voice/       (C4)
   lib/ui/shell/ + home/ + theme/ + practise/ + onboarding/ (U1)   lib/ui/read/ (U2)   lib/ui/results/ + lib/ui/fix/ (U3)
   lib/ui/progress/ + lib/ui/settings/ (U4)   integration_test/e2e/ (I1)   .github/ (W0)   tools/eval/ (I2)
4. In lib/core/models/ define immutable classes (freezed + json_serializable):
   - PhonemeSpec { String ipa; int stress /*0,1,2*/; }
   - WordSpec { String text; int index; List<PhonemeSpec> phonemes; bool scorable; }
   - Passage { String id; int level /*1-6*/; String title; String text; List<WordSpec> words;
               List<String> soundTags; }
   - AudioClip { String path; int sampleRate /*16000*/; Duration duration; }
   - Segment { Duration start; Duration end; }
   - PhonemePosteriors { List<String> vocab; List<Float32List> frames /*20 ms each*/; }
   - PhonemeResult { String expected; String? heard; int score /*0-100*/; Duration start, end; }
   - WordResult { int index; String text; int score; List<PhonemeResult> phonemes;
                  WordStatus status /*good>=80, close 60-79, fix<60, notScored, missed*/; }
   - AttemptResult { String id; String passageId; DateTime at; int overall; int accuracy;
                     int fluency; List<WordResult> words; String? audioPath; }
   - SoundStat { String ipa; double accuracy; int attempts; DateTime lastPractised; }
   - UserProfile { int level; int dailyGoalMinutes; int streak; DateTime? lastPractice;
                   bool keepRecordings; bool placementDone; }
5. In lib/core/contracts/ define abstract classes (doc-comment each method):
   - AudioRecorder: Future<void> start(); Future<AudioClip> stop(); Stream<double> level;
     Stream<void> silenceDetected /*2 s*/; Future<List<Segment>> speechSegments(AudioClip);
   - PhonemeRecognizer: ModelTier recommendedTier(); Future<void> load(ModelTier tier /*light, full*/);
     Future<PhonemePosteriors> recognise(AudioClip clip);
   - PronunciationScorer: AttemptResult score(Passage p, PhonemePosteriors post,
     List<Segment> speech); WordResult scoreWord(WordSpec w, PhonemePosteriors post);
   - ContentRepository: Future<List<Passage>> all(); Future<Passage> byId(String id);
     Future<List<WordSpec>> lookup(String customText);
   - ProgressRepository: save/load AttemptResult, updateWordResult (for retries), SoundStat, UserProfile, review queue,
     deleteAll(), exportJson().
   - PracticeEngine: Future<Passage> nextPassage(); Future<LevelChange?> recordAttempt(
     AttemptResult r); Future<List<String>> dueReviewWords(); placement helpers.
   - VoiceService: Future<void> speak(String text, {double rate = 1.0}); Future<bool> hasBritishVoice();
   - Tips: String? tipFor(String expected, String? heard).
6. In lib/core/fakes/ write a working fake for every contract (fixed sample data: 3 passages,
   the "A walk by the river" passage, a canned AttemptResult with Thursday/bath/castle red).
7. Wire Riverpod providers in lib/core/providers.dart that return the fakes by default, with a
   single place to swap in real implementations.
8. Testing foundations:
   - test/contracts/: one reusable suite per contract (e.g. runAudioRecorderContract(factory))
     that checks the documented behaviour; run every suite against its fake now.
   - test/fixtures/: short WAV clips (clean read, mispronounced word, silence, noise) recorded
     or generated with free tools, plus matching canned posteriors and results.
   - Golden test setup with alchemist and bundled fonts so images match on any machine.
   - docs/testing.md: the test layers, folder layout and coverage gates (85% engine,
     practice, data; 70% ui; 80% tools/).
   - scripts/check.sh: dart format check, flutter analyze --fatal-infos, flutter test
     --coverage, coverage gate, pytest tools/. tools/ci/coverage_gate.py enforces per-folder
     gates from coverage/lcov.info.
9. GitHub Actions (.github/workflows/), with dependency caching and cancel-in-progress:
   - ci.yml on pull_request and push to main: jobs lint, test (unit + widget + contract +
     coverage gate), golden (ubuntu only), python (ruff + pytest), content (bundle schema
     check), licences (fail on GPL/AGPL in pubspec.lock or tools/requirements; check
     docs/licences.md lists every model and voice), build-android (debug APK as artifact).
   - integration.yml on push to main, nightly and the run-integration label: Android
     emulator API 34 (reactivecircus/android-emulator-runner, KVM on ubuntu) running
     integration_test/; iOS job on macos-latest nightly: flutter build ios --simulator
     --no-codesign and integration tests on a simulator. Download model files from GitHub
     Release assets and cache them by SHA-256.
   - .github/dependabot.yml for pub, pip and github-actions; a pull request template with a
     test checklist; docs/ci.md listing the required checks to set in branch protection.
10. Seed each Wave 1 folder with one passing placeholder test so CI is green from day one.

Done when: the app runs and shows a placeholder home screen; all models serialise round-trip in
tests; every contract has a fake with tests; folder READMEs exist.
```

## Wave 1: scoring engine (4 agents)

A4 produces the model files; A2 can start with any small ONNX CTC model and swap in A4's output later.

### A1 – Audio capture and speech detection

```text
ID: A1-audio   Branch: feat/a1-audio   You own: lib/engine/audio/, test/engine/audio/
Implement AudioRecorder from lib/core/contracts/.
- Record 16 kHz mono 16-bit PCM WAV with the `record` package into app-private storage.
- Handle microphone permission (permission_handler) with clear denied/permanently-denied states.
- Emit an input level stream (~20 updates/s) for the waveform.
- Silero VAD (MIT, ONNX, ~2 MB) via sherpa_onnx: emit silenceDetected after 2 s of silence
  following speech; speechSegments() returns speech regions with 150 ms padding.
- Pre-check: warn if the clip is too quiet (peak < -30 dBFS) or noisy (estimated SNR < 15 dB);
  expose AudioQuality { ok, tooQuiet, tooNoisy } on the returned clip metadata.
Tests: unit tests with bundled WAV fixtures (speech, silence, noise). Start latency < 300 ms.
```

### A2 – On-device phoneme model runtime

```text
ID: A2-runtime   Branch: feat/a2-runtime   You own: lib/engine/runtime/, assets/models/ (loader only)
Implement PhonemeRecognizer.
- Run a wav2vec2-style CTC phoneme model in ONNX format on device. Prefer the sherpa_onnx
  Flutter package if it exposes raw CTC logits; otherwise use onnxruntime (Dart/FFI plug-in).
- Input: 16 kHz float waveform, zero-mean / unit-variance normalised. Output: per-frame
  log-probabilities (50 frames/s) over the model's IPA vocab (read vocab.json).
- Two tiers: light model bundled in assets; full model downloaded once over Wi-Fi to app
  storage with progress, checksum check and resume. No other network use.
- Run inference in a background isolate; never block the UI thread.
- recommendedTier(): choose light on devices with under 4 GB RAM or older than iPhone XS /
  Android 10-class hardware (time a 5 s clip on first run if unsure). Settings can override.
- Until A4 delivers, use the public ONNX export of facebook/wav2vec2-lv-60-espeak-cv-ft
  (Apache-2.0) for development on desktop/emulator.
Tests: logits shape and vocab mapping on a fixture; timing benchmark printed for a 20 s clip.
Target: 60-word passage (~25 s audio) processed in < 2.5 s on a mid-range phone with full tier.
```

### A3 – Alignment and pronunciation scoring

```text
ID: A3-scoring   Branch: feat/a3-scoring   You own: lib/engine/scoring/, test/engine/scoring/
Implement PronunciationScorer and Tips in pure Dart (no Flutter imports, so it tests fast).
- Map each expected IPA phoneme to the model vocab (handle length marks, stress, diphthongs;
  keep the mapping table in a data file with tests).
- CTC forced alignment (Viterbi) of the expected phoneme sequence to the posteriors, allowing
  optional blanks; produce start/end per phoneme and word.
- Goodness of pronunciation per phoneme: mean log-posterior of the expected phoneme over its
  frames minus the best competing phoneme; map to 0-100 with a calibration curve held in
  config (initial guess; I2 tunes it). Record the top competing phoneme as `heard`.
- Word score = weighted mean of its phonemes (stressed vowels weigh 1.5). Detect missed words
  (alignment confidence below threshold) and mark status missed.
  Detect extra (inserted) words between expected words and count them in fluency.
- Fluency 0-100 from speaking rate (target 130-170 words/min), pause count/length between
  segments, and missed or repeated words. Overall = 0.7 accuracy + 0.3 fluency.
- Tips: a table of common substitutions -> one-line advice, e.g. /θ/->/t/ "Put your tongue
  between your teeth", /ɑː/->/æ/ "Drop your jaw for a long 'ah', as in car", added /r/ after a
  vowel "In British English, don't sound the r here". At least 25 entries.
Tests: synthetic posteriors where the right answer is known (perfect read, one substituted
phoneme, one missed word, long pauses). Scoring 200 words takes < 100 ms.
```

### A4 – Model preparation tooling

```text
ID: A4-models   Branch: feat/a4-models   You own: tools/models/ (Python), docs/models.md
Produce the two model files A2 loads, using only free tools and data.
- Full tier: export facebook/wav2vec2-lv-60-espeak-cv-ft to ONNX (opset 17), then dynamic int8
  quantisation. Verify logits stay close to the PyTorch output on 20 test clips.
- Light tier: fine-tune facebook/wav2vec2-base on phoneme labels (espeak IPA) using free
  English speech data with permissive licences (document each dataset's licence; prefer
  British speakers where available). Export to int8 ONNX, target < 100 MB.
- Report phoneme error rate for both tiers on a held-out set, plus size and CPU time.
- Output: model.onnx, vocab.json and a SHA-256 for each file, plus a script that reproduces
  everything from a clean machine. Do not commit large binaries; put them in a release folder
  and document the download URL placeholder.
- Publish model files as GitHub Release assets with a SHA-256 manifest so CI downloads and
  caches them.
- pytest: run the export end to end on a tiny randomly initialised wav2vec2; check int8
  logits stay within tolerance of fp32; verify the checksum manifest.
```

## Wave 1: content, data and practice logic (4 agents)

### C1 – Passage content pipeline

```text
ID: C1-content   Branch: feat/c1-content
You own: tools/content/, assets/content/, lib/data/content/ (ContentRepository only)
- Write 120 original passages, 20 per level, following the level table in docs/SPEC.md
  (length, topic, sound focus). Original writing or public-domain sources only; record the
  source of each in assets/content/SOURCES.md.
- Build script (Python, dev-side only): tokenise each passage, look up British IPA + stress in
  Britfone (MIT); for words Britfone lacks, use eSpeak NG en-gb in the build script only and
  flag them for human review. Tag each passage with the sounds it practises.
- Output assets/content/passages.v1.json matching the Passage model, plus a schema test.
- Implement ContentRepository: load the JSON bundle; lookup(customText) uses the bundled
  Britfone table and marks unknown words scorable=false. Never ship eSpeak.
  Do not use BEEP or any other research-only / non-commercial lexicon.
- Also produce assets/content/minimal_pairs.json (40+ pairs grouped by contrast) and a
  3-passage placement set (levels 1, 3, 5).
Tests: every passage validates; every scorable word has phonemes; levels have 20 passages each.
pytest for the build script (tokenising, Britfone lookup, unknown-word flagging). CI rebuilds
passages.v1.json and fails if it differs from the committed file (no hand edits).
```

### C2 – Local storage

```text
ID: C2-data   Branch: feat/c2-data   You own: lib/data/ (except lib/data/content/)
Implement ProgressRepository with drift (SQLite).
- Tables: attempts, word_results, sound_stats, review_queue, user_profile (see SPEC data model).
- Update sound_stats with an exponential moving average after each attempt.
- Recordings: delete the audio file after scoring unless profile.keepRecordings is true.
- deleteAll() wipes the database and recordings; exportJson() writes a backup file;
  importJson() restores it.
- updateWordResult() for retried words: also updates sound_stats and the review queue.
- Migrations with version numbers and a migration test.
Tests: in-memory database tests for every method; 1,000 attempts load in < 200 ms.
```

### C3 – Practice engine

```text
ID: C3-practice   Branch: feat/c3-practice   You own: lib/practice/
Implement PracticeEngine using ContentRepository and ProgressRepository (fakes for now).
- Levels 1-6. Move up after 3 passages in a row at 85+; drop after 3 in a row under 60.
  Return a LevelChange with a one-line reason.
- Next passage: 70% current level weighted to the user's 3 weakest sounds (by soundTags),
  20% review of previously missed words, 10% preview of the next level. Avoid repeating a
  passage within the last 10 sessions. Seedable random for tests.
- Spaced review: missed words (status fix) enter the queue at intervals 1, 3, 7, 21 days;
  a later score of 80+ advances them, under 60 resets them.
- Placement: score 3 placement passages and choose the start level.
- Streaks and daily goal: count minutes practised per local day (Europe/London default, use
  device time zone); streak breaks after a missed day.
Tests: table-driven tests for level rules, review intervals, streak edge cases (midnight,
clock changes).
```

### C4 – British model voice

```text
ID: C4-voice   Branch: feat/c4-voice   You own: lib/voice/
Implement VoiceService.
- Default: the phone's built-in en-GB voice via flutter_tts, fully offline. Pick the best
  installed en-GB voice; if none, report hasBritishVoice() = false so the UI can show how to
  download one in system settings.
- Normal and slow rates (1.0 and 0.6); speak a single word or a sentence.
- Optional (feature flag, off by default): Piper en_GB voice through sherpa_onnx TTS. Only
  include a voice whose licence allows commercial redistribution; record it in
  docs/licences.md.
Tests: fake TTS engine tests for voice selection and rate.
```

## Wave 1: screens (4 agents)

All screen agents build against the fakes, so they can show realistic data from day one. U1 owns the theme; the others use its tokens through `Theme.of(context)` and must not define their own colours.

### U1 – App shell, theme and Home

```text
ID: U1-home   Branch: feat/u1-home   You own: lib/ui/shell/, lib/ui/home/, lib/ui/theme/
- Material 3 theme, light and dark, large readable type (passage text 18-22 sp, adjustable).
  Define score colours: good (80+), close (60-79), fix (<60) with WCAG AA contrast, plus a
  non-colour cue (underline + icon) for colour-blind users.
- Bottom navigation: Home, Practise, Progress, Settings (go_router shell route).
- Home screen per the spec sketch: greeting, level and progress bar, streak and today's
  minutes, "Start today's passage" button, weak-sounds card (top 3), "N words due for
  review" card. Data from PracticeEngine and ProgressRepository providers.
- First-run flow (lib/ui/onboarding/): welcome -> microphone permission -> British voice
  check -> placement test: read 3 passages (levels 1, 3, 5) through U2's read route, then a
  result screen showing the starting level from PracticeEngine. Target: about 2 minutes.
- Practise tab (lib/ui/practise/): passage library by level (locked above current level + 1),
  weak-sounds list (each sound opens a passage tagged with it), and words-due list (each
  word opens Fix a word). The Home weak-sounds and review cards link here.
- Responsive layout helper used by every screen: phones and tablets, portrait and
  landscape, reading width capped at ~680 dp, two-pane Results on tablets.
Tests: golden tests for Home in light and dark; widget test for navigation.
```

### U2 – Read and record screen

```text
ID: U2-read   Branch: feat/u2-read   You own: lib/ui/read/
- Shows level, passage number, title and text with text-size control.
- Big record button; while recording show a live waveform from AudioRecorder.level, a timer,
  and "Stops by itself after 2 s of silence"; tap to stop.
- On stop: show a short "Scoring..." state, call PhonemeRecognizer then PronunciationScorer
  through a single ScoringController (put it in lib/ui/read/), then navigate to Results with
  the AttemptResult.
- Handle: permission denied, too quiet / too noisy (offer retry), model still downloading.
- Also used for word and sentence retries (mode parameter: passage, sentence, word).
Tests: widget tests for every state using fakes, at phone and tablet sizes.
```

### U3 – Results and Fix a word screens

```text
ID: U3-results   Branch: feat/u3-results   You own: lib/ui/results/, lib/ui/fix/
Results:
- Overall score, accuracy and fluency. Passage text with each word coloured by status
  (RichText spans, plus underline for close/fix), legend, "Tap any word to hear it and try
  again". Tapping a word opens a bottom sheet: expected IPA, heard IPA, score, play buttons,
  retry.
- A retried word updates its colour and score here straight away and is saved through
  ProgressRepository.updateWordResult.
- If the light model tier is active, show word scores only and hide per-sound detail.
- Buttons: "Fix N red words" and "Next passage". Show LevelChange message if any.
Fix a word:
- Steps through red words: word, expected vs heard IPA, sound chips with the wrong one
  highlighted, tip text from Tips, "Play British" and "Play slowly" (VoiceService), hold-to-
  record (reuse U2's recorder widget through the contract, not its files), last score vs
  target 80. Repeat until 80+ or skip; then ask for the whole sentence once.
Tests: golden tests matching the spec sketches at phone and tablet sizes; widget tests for the retry loop.
```

### U4 – Progress and Settings screens

```text
ID: U4-progress   Branch: feat/u4-progress   You own: lib/ui/progress/, lib/ui/settings/
Progress:
- Score trend over time (fl_chart), current level and history of level changes, sound
  accuracy list sorted weakest first, streak calendar.
Settings:
- Daily goal, reminder time (flutter_local_notifications, local only), text size, keep
  recordings toggle, model tier (light / download full with size and progress), British voice
  check, export and import progress, delete all data (with confirmation), licences page
  listing every model, dictionary and voice.
Tests: widget tests with fake data; golden tests for both screens at phone and tablet sizes.
```

## Wave 2: integration and accuracy (2 agents)

Start both after all 12 Wave 1 branches are merged. I1 and I2 can run in parallel; I2 sends calibration changes to A3's config file only.

### I1 – Integration and end-to-end tests

```text
ID: I1-integration   Branch: feat/i1-integration
You own: lib/core/providers.dart, integration_test/e2e/, docs/handoff/integration.md
You may make small fixes anywhere, but list every file you touch outside your folders in
the handoff note and keep each fix minimal.
- Swap every fake provider for the real implementation. Keep fakes available behind a
  --dart-define=USE_FAKES=true flag for UI development.
- Apply approved docs/contract-requests/ changes, update fakes and callers.
- Integration tests on emulator/simulator with fixture audio injected into the recorder:
  first run -> placement -> Home -> Read -> Results -> Fix a word -> level up after 3 high
  scores -> Progress shows history -> delete all data.
- Run with network disabled (aeroplane mode) and confirm nothing changes.
- Make the e2e suite run in .github/workflows/integration.yml on the Android emulator (every
  push to main) and iOS simulator (nightly), and make it a required check before release.
- Run every contract suite against the real implementations together.
- Fix flaky tests rather than adding retries; quarantine only with a tracked issue.
- Measure on one real mid-range Android and one iPhone: app size, cold start, scoring time
  for a 60-word passage. Record numbers in the handoff note against the SPEC targets.
```

### I2 – Scoring accuracy check and calibration

```text
ID: I2-eval   Branch: feat/i2-eval   You own: tools/eval/, lib/engine/scoring/config/
- Build a command-line harness that runs the real engine (desktop build) on a folder of
  WAV files plus passage IDs and writes word scores to CSV.
- Assemble an evaluation set: freely licensed recordings of British speakers reading text,
  plus recordings of learners if the owner supplies them; each word labelled right/wrong by
  a British-English teacher (leave a labelling CSV template if labels are not yet available).
- Tune the GOP-to-score calibration curve and the good/close/fix thresholds to maximise
  agreement with the teacher labels; report agreement, false "fix" rate on native
  speakers (target < 5%), and per-phoneme weak spots.
- Go/no-go: agreement must be >= 80% on words before release. Write the report to
  docs/eval-report.md.
- pytest for the harness and calibration code. Add .github/workflows/eval.yml (manual and
  weekly) that runs the harness on the stored eval set and fails below 80% agreement.
```

## Wave 3: release and beta (1 agent)

Start after I1 passes and I2 gives a go. This covers the spec's beta phase and the success metrics, which no other prompt delivered.

```text
ID: R1-release   Branch: feat/r1-release
You own: android/ and ios/ (signing and store config only), store/, docs/release.md
- App name, icon, splash screen, version 1.0.0; signed release builds (Android AAB, iOS).
- Check download size is under 150 MB with the light model bundled; the full model stays a
  separate optional download.
- Privacy: App Store label "Data Not Collected"; Google Play data-safety form with nothing
  collected or shared; microphone permission text saying recordings stay on the phone.
- Licences page complete for every model, dictionary, voice and package (check against
  docs/licences.md).
- Beta: TestFlight and Google Play internal testing for 30-50 learners. Add "Send feedback":
  it opens an email draft, and the user may attach their exported progress file by choice
  (no automatic upload). Write a script in tools/beta/ that reads those files and reports
  practice days per week and score gains against the SPEC targets.
- Store listing text and screenshots of the four main screens.
- .github/workflows/release.yml on tag v*: run the full ci.yml checks, require a green
  integration.yml run on that commit, build signed AAB and IPA with signing keys from GitHub
  secrets, attach them to a GitHub Release, and optionally upload to TestFlight and the Play
  internal track with fastlane. Document the secrets needed in docs/release.md.
```

## Later waves: v1.1 to v1.3

Each row is a self-contained prompt: paste the preamble, then "Build \<feature>. You own \<folders>." followed by the brief. Agents in the same release run in parallel.

| ID | Release | Feature | You own | Brief for the agent |
| --- | --- | --- | --- | --- |
| F1 | v1.1 | Weak-sounds profile | lib/ui/progress/sounds/ | Top 5 weakest sounds with 30-day trend lines and a "Practise this sound" button that asks PracticeEngine for a passage tagged with it |
| F2 | v1.1 | Minimal pairs | lib/features/pairs/ | Drill from minimal\_pairs.json: hear one of a pair, pick which; then say both and score each with scoreWord; adapt to the user's confused pairs |
| F3 | v1.1 | Spaced review session | lib/features/review/ | A 2-minute session of due words from the review queue: hear, say, score, update intervals |
| F4 | v1.1 | Record and compare | lib/features/compare/ | On any word or sentence, play the British model then the user's recording back to back, with waveforms aligned |
| F5 | v1.1 | Streaks and reminders | lib/features/habit/ | Daily goal ring, streak freeze (1 per week), local notification at the chosen time; no server |
| F6 | v1.2 | Before and after | lib/features/journey/ | When keepRecordings is on, replay the first and latest attempt of a passage side by side with both scores |
| F7 | v1.2 | Stress and intonation | lib/engine/prosody/, lib/ui/prosody/ | Extract pitch (YIN, pure Dart) and syllable energy; mark stressed syllables vs expected stress; draw the user's pitch line over the model voice's |
| F8 | v1.2 | Custom text | lib/features/custom/ | Paste text or photograph it (google\_mlkit\_text\_recognition, on-device); score only dictionary words and grey out unknown ones |
| F9 | v1.2 | Topic packs | assets/content/packs/, tools/content/packs/ | 4 packs of 20 passages: interviews, workplace, travel, IELTS-style reading, using the C1 pipeline |
| F10 | v1.3 | Mouth guides | lib/features/mouth/, assets/mouth/ | Original simple SVG drawings of tongue, lip and jaw position for the 20 hardest sounds, shown on Fix a word |
| F11 | v1.3 | Generated passages | lib/features/generate/ | Spike first: test a small open-licence on-device language model (under 1 GB) writing level-appropriate passages full of the user's weak sounds; ship only if 9 of 10 samples pass a human check |
| F12 | Later | Other accents | lib/accents/, assets/content/accents/ | Make the target accent a setting; add a second pronunciation table and calibration (Northern English first) |
