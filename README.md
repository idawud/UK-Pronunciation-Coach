# UK Pronunciation Coach

A mobile-first Flutter app for improving Standard Southern British pronunciation through short, daily reading practice.

The app listens to the user read a passage aloud, scores pronunciation against a British reference model, highlights problem words, and turns each mistake into a focused practice loop. Everything runs on-device, with no paid speech APIs and no recordings leaving the device.

## Current accuracy (beta)

The beta ships on the current speech models. They reliably flag clear mispronunciations (for
example "think" said as "tink") but catch only roughly 3 in 10 of the subtler mistakes in our
test set; vowel errors, z/s, dropped h and word stress are the weak spots. Because the model
was trained mainly on American English labels, a few American pronunciations (the "hot"
vowel, the r in "car") are accepted. About 2% of correct words from native British speakers
are wrongly marked in our measurement with the full model (about 6% with the smaller bundled
one). A British fine-tune is the planned fix. Figures and method: `docs/eval-report.md`.
Testers: the most useful reports are words you said wrongly that came out green, and words
you said correctly that came out red.

## Why this app exists

UK Pronunciation Coach is designed for adult English speakers, often non-native, who want a clearer, more British accent for work, study, interviews and everyday life.

The app focuses on a simple habit loop:

- Read a short passage aloud
- Get a rapid pronunciation score
- Fix the red words that need attention
- Repeat until the score improves
- Move to a harder passage when ready

## Product goals

- Score word- and sound-level pronunciation within about 3 seconds after a reading finishes
- Turn mistakes into short, targeted practice steps
- Raise difficulty automatically as the user improves
- Encourage a 5–10 minute daily practice habit

## Product constraints

- No paid speech, AI or cloud APIs
- No user accounts or server backend
- No general conversation or grammar correction; reading aloud only
- Southern British English only for version 1
- Everything stored on the device

## Platform approach

The product is a mobile-first app for iOS and Android built with Flutter. Tablets are supported, and desktop or web can follow later from the same codebase.

Why Flutter:

- Single codebase for iOS, Android and tablets
- Mature audio recording plugins
- Good fit for on-device models via ONNX Runtime or sherpa-onnx
- Strong cross-platform delivery without duplicating logic

Minimum supported devices:

- iPhone XS / iOS 16+
- Android 10 with 4 GB RAM or more
- Older devices can fall back to a lighter model with word-level analysis only

## Core user loop

Version 1 ships four features that form the practising loop.

### F1: Read and record

- Show a passage in large, adjustable text
- Start recording after a tap at 16 kHz mono
- Stop automatically on silence or after a tap
- Aim for recording start within 300 ms of the tap

### F2: Pronunciation scoring

- Score every word from 0–100
- Score each sound within a word against the British reference
- Give passage-level and fluency scores (pace and pauses)
- Deliver results within about 3 seconds for a 60-word passage on a mid-range phone

### F3: Highlight and retry

- Colour each word green (80+), amber (60–79) or red (<60)
- Tap a word to see the expected sounds, hear the British model, and retry that word alone
- Repeated attempts update the score instantly

### F4: Adaptive difficulty

- Six passage levels
- Move up after 3 passages in a row at 85+
- Drop back after 3 passages under 60
- Choose the next passage based on weak sounds the user struggles with

## Retry flow for a red word

1. Hear the British model at normal speed, then slowed.
2. See the sounds, with the incorrect one highlighted, for example /θ/ in “think” mistaken as /t/.
3. Say the word again and retry until it scores 80+ or the user skips.
4. Say the whole sentence again with the corrected word included.

## Offline AI evaluation engine

This app does not depend on cloud speech recognition. The scoring engine runs fully offline on the phone using small free open-source models.

The core pipeline is:

1. Look up each word's British pronunciation and stress from a bundled dictionary
2. Trim silence and split speech into segments with a voice activity detector
3. Run a phoneme recognition model that outputs probabilities for IPA sounds every 20 ms
4. Align the expected sounds to the spoken audio
5. Score each expected sound, then aggregate word, sentence and passage scores
6. Explain common substitutions and pronunciation tips

### Recommended technical stack

| Component | Free option | Licence | Notes |
| --- | --- | --- | --- |
| Phoneme recognition | wav2vec2-lv-60-espeak-cv-ft | Apache-2.0 | Outputs IPA phonemes; ONNX export exists |
| Lighter phoneme model | wav2vec2-base fine-tuned on phonemes | Apache-2.0 | Better for older phones |
| Speech detection | Silero VAD | MIT | Light and bundled |
| Runtime | sherpa-onnx / ONNX Runtime | Apache-2.0 / MIT | Runs on Android, iOS and desktop |
| British dictionary | Britfone | MIT | Standard Southern British IPA with stress |
| British model voice | Device built-in en-GB voice | Free with OS | Offline after download |
| Better optional voice | Piper en_GB voices | MIT engine; voice licences vary | Optional extra |

The app should ship the lighter model (under 150 MB) in the app itself, with the full model available as an optional Wi‑Fi download.

Important policy note: eSpeak NG is useful for developer-side text preparation, but its GPL-3.0 licence makes it unsuitable for shipping in the app. Version 1 therefore uses it only for content generation tooling and leaves unknown words unscored until a permissively licensed grapheme-to-phoneme solution is ready.

## User experience and content progression

The app includes a set of reading passages and levels for progression.

### Passage ladder

| Level | Passage length | Content | Sound focus |
| --- | --- | --- | --- |
| 1 | 1 sentence, 8–12 words | Everyday phrases | Short vowels, clear consonants |
| 2 | 2–3 sentences, ~30 words | Daily routines | /θ/ and /ð/; word endings |
| 3 | ~60 words | Short stories, emails | Long vowels; no /r/ after vowels |
| 4 | ~100 words | News and workplace text | Word stress, weak forms |
| 5 | ~150 words | Opinions, explanations | Connected speech and rhythm |
| 6 | longer sustained text | Extended practice | Mixed real-world British patterns |

The initial app ships with 120 passages, 20 per level, written in-house or sourced from public-domain material. Each passage is tagged with the British sounds it practices.

## Quality bar

The product aims for:

- At least 80% agreement with a trained British-English teacher on words marked right or wrong
- Reliable scoring even when the phone is in airplane mode
- No paid cloud dependency at runtime

## Main screens

The app is organised around a small set of key screens:

- Home / practice entry
- Read screen with large passage text and recording controls
- Results screen with word-by-word colour coding
- Fix screen for red words, sound explanations and retries
- Progress screen with weak-sound charts and historical trends
- Settings screen for audio and difficulty preferences

A “Results” screen colours each word by score and offers a guided “Fix 3 red words” flow, followed by a re-read of the sentence with the corrected word included.

## Build plan and project structure

The build prompt splits the project into Wave 0, Wave 1 and Wave 2 phases. Wave 0 creates the Flutter scaffold and frozen shared contracts. Wave 1 builds the parallel engineering workstreams in separate git worktrees, and Wave 2 integrates them once the contract-prior work is merged.

### Project layout

```text
lib/
  core/
    contracts/
    fakes/
    models/
  engine/
    audio/
    runtime/
    scoring/
  data/
  practice/
  ui/
    shell/
    home/
    theme/
    practise/
    onboarding/
    read/
    results/
    fix/
    progress/
    settings/
  voice/
tools/
  models/
  content/
  eval/
assets/
  content/
.github/
integration_test/
```

### Core technical setup

Wave 0 defines:

- Flutter app named `uk_pronunciation_coach`
- iOS 16+ and Android minSdk 29 support
- Riverpod state management
- go_router for routing
- flutter_lints for code quality
- immutable core models with Freezed and json_serializable
- contract-first architecture with shared test suites

## Testing and CI

The app uses a layered quality model to keep parallel work safe and reliable.

### Required test layers

| Layer | Coverage target | Purpose |
| --- | --- | --- |
| Unit | 85% on engine/practice/data logic | Scoring, alignment, level rules, storage |
| Contract | Every contract passes its shared suite | Cross-agent compatibility |
| Widget | 70% on ui logic | Loading, empty, error and permission states |
| Golden | Linux CI | Visual matching to design sketches |
| Python | 80% on tools/ | Content build, eval harness and model export |
| Content | Must pass | Passage bundle schema and phoneme coverage |
| On-device | Must pass | Recording, ONNX, SQLite and TTS fixtures |
| End-to-end | Must pass on main | Full user journeys with network off |
| Accuracy | 80% or higher | Word agreement with teacher labels |

### CI workflows

- `ci.yml`: every PR and push to `main`
- `integration.yml`: main pushes, nightly or PRs labelled for integration testing
- `eval.yml`: manual and weekly accuracy checks
- `release.yml`: tag-based builds for signed Android and iOS releases

The build rules explicitly require all CI checks to pass before merge and require `integration.yml` to be green before any release tag is cut.

## Repository notes

This workspace includes the product specification and build prompt documents in `.docs/` for reference:

- `.docs/UK Pronunciation Coach – Product Spec.md`
- `.docs/UK Pronunciation Coach – Agent Build Prompts.md`

They form the product baseline and the engineering execution plan for the app.

## Licence and constraints

This product intentionally avoids proprietary or cloud-first dependencies. The build plan requires only permissive licences for anything shipped, and it forbids analytics, tracking and crash-reporting SDKs that send user data off-device.

## Summary

UK Pronunciation Coach is a privacy-first, on-device pronunciation trainer that helps users read British English more clearly by combining practical feedback, adaptive difficulty and focused sound-level correction. It is built to be small, fast, offline and habit-forming for daily practice.
