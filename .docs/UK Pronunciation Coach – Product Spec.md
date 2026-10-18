# UK Pronunciation Coach – Product Spec

Oct 18, 2026 · @Dawud Ismail

## Overview

UK Pronunciation Coach is a mobile app that listens to you read a passage aloud, scores your pronunciation against standard Southern British English, and drills the words you got wrong. All speech scoring runs on the phone with small, free, open-source models, so there are no paid APIs and no recordings leave the device.

**Target user:** adult English speakers (often non-native) who want a clearer, more British accent for work, study, interviews or everyday life.

**Goals**

- Give accurate word- and sound-level feedback on a read-aloud passage within about 3 seconds of finishing.
- Turn every mistake into a short, targeted practice step.
- Raise difficulty automatically as the user improves.
- Build a daily practice habit (5–10 minute sessions).

**Non-goals for version 1**

- No paid speech, AI or cloud APIs.
- No free conversation or grammar correction; reading aloud only.
- No accents other than Southern British (others may come later).
- No user accounts or server backend; everything is stored on the device.

## Platform decision

**Decision: a mobile-first app for iOS and Android, built with Flutter.** Tablets are supported, and desktop or web can follow from the same code.

| Factor | Mobile | Desktop |
| --- | --- | --- |
| Daily habit | Short sessions anywhere; push reminders | Needs the user at a desk |
| Microphone | Built-in mic held close; consistent quality | Varies widely; laptop mics pick up room noise |
| Privacy for speaking aloud | Practise somewhere private | Often shared spaces |
| Running an on-device model | Modern phones run 100–400 MB models well | Easier, but not needed |
| Reading space | Fine on phones, ideal on tablets | Best |

**Why Flutter:** one codebase for iOS, Android, tablet and later desktop. It has mature audio-recording plugins, and on-device models can run through ONNX Runtime or the sherpa-onnx Flutter package. React Native is a reasonable alternative if the team already knows JavaScript.

**Minimum devices:** iPhone XS / iOS 16 or newer; Android 10 with 4 GB RAM or more. Older devices get a lighter model with word-level feedback only.

## Core features and requirements

Version 1 ships four features that form one practice loop: read, score, fix, level up.

| ID | Feature | Requirement | Acceptance check |
| --- | --- | --- | --- |
| F1 | Read and record | Show a passage in large, adjustable text. Record at 16 kHz mono after a tap. Stop on tap or after 2 seconds of silence. | Recording starts within 300 ms of the tap; silence detection stops it automatically |
| F2 | Pronunciation scoring | Score every word (0–100) and every sound in it against the British reference. Also score the passage overall, plus fluency (pace and pauses). | Results show within 3 s for a 60-word passage on a mid-range phone |
| F3 | Highlight and retry | Colour each word green (80+), amber (60–79) or red (under 60). Tapping a word shows the expected sounds, plays the British model and lets the user retry that word alone. | A retried word updates its colour and score straight away |
| F4 | Adaptive difficulty | Passages sit in 6 levels. The user moves up after 3 passages in a row at 85+ and drops back after 3 under 60. Weak sounds pick the next passage. | Level changes are shown with a short explanation |

**Retry flow for a red word:**

1. Hear the British model at normal speed, then slowed.
2. See the sounds, with the wrong one marked (for example, *th* in "think" heard as /t/).
3. Say the word; repeat until it scores 80+ or the user skips.
4. Say the whole sentence again with the fixed word in it.

**Quality targets:** scores agree with a trained British-English teacher on at least 80% of words marked right or wrong. Turning the phone to aeroplane mode does not change any feature.

## Offline AI evaluation engine

**Yes, scoring can run fully offline with free models.** The engine compares the sounds the user actually made with the British sounds expected for the passage. It uses a small phoneme-recognition model, not a general speech-to-text model, because speech-to-text guesses the intended word and hides mistakes.

**Pipeline (all on the phone):**

1. **Expected sounds.** Look up each word's British pronunciation and stress in the bundled dictionary. Library passages ship with this already worked out.
2. **Clean the audio.** Trim silence and split into speech segments with a voice-activity detector.
3. **Recognise sounds.** Run the phoneme model, which outputs a probability for each IPA sound every 20 ms.
4. **Align.** Force-align the expected sounds to the audio, giving each word and sound a start and end time.
5. **Score.** For each expected sound, compare its probability with the best competing sound (a "goodness of pronunciation" score). Combine into word, sentence and passage scores. Pace, pauses and missed or extra words give the fluency score.
6. **Explain.** Map common substitutions to tips, for example /θ/ → /t/ becomes "put your tongue between your teeth".

| Component | Free option | Licence | Size on device | Notes |
| --- | --- | --- | --- | --- |
| Phoneme recognition | [wav2vec2-lv-60-espeak-cv-ft](https://huggingface.co/facebook/wav2vec2-lv-60-espeak-cv-ft) (Meta) | Apache-2.0 | \~600 MB fp16, \~320 MB int8 (approx.) | Outputs IPA phonemes; a ready [ONNX export](https://huggingface.co/sadda-speech/wav2vec2-espeak-ctc) exists |
| Lighter phoneme model | wav2vec2-base fine-tuned on phonemes (built in-house) | Apache-2.0 | \~95 MB int8 (approx.) | For older phones; needs a training run on free data |
| Speech detection | Silero VAD | MIT | \~2 MB | Bundled in sherpa-onnx examples |
| On-device runtime | [sherpa-onnx](https://pub.dev/packages/asr_lib/changelog) / ONNX Runtime | Apache-2.0 / MIT | \~10–20 MB | Flutter package runs on Android, iOS, macOS, Windows, Linux |
| British dictionary | [Britfone](https://www.npmjs.com/package/britfone) | MIT | < 1 MB | Standard Southern British IPA with stress; about 12,000+ common words |
| British model voice | Phone's built-in en-GB voice (via flutter\_tts) | Free with OS | 0 MB | Offline on iOS and Android once the voice is downloaded |
| Better model voice (optional) | [Piper](https://github.com/agisota/piper-TTS) en\_GB voices | MIT engine; voice licences vary | \~60 MB per voice | Check each voice's licence before shipping |

**Words not in the dictionary:** for user-pasted text, unknown words go through a grapheme-to-phoneme step. eSpeak NG's en-gb rules work well but are GPL-3.0, which can clash with app-store terms. So version 1 uses eSpeak NG only on the developer side to prepare library passages, and marks unknown words in custom text as "not scored" until a permissively licensed G2P model is added.

**Model delivery:** ship the light model in the app (under 150 MB download). Offer the full model as a one-time optional download over Wi-Fi; after that nothing needs the internet.

**Licence to avoid:** the BEEP British dictionary is for research use only and [cannot be used commercially](https://openslr.org/14).

## Main screen sketches

Four screens carry the whole practice loop; a Progress screen (weak-sounds chart, history) and Settings complete the app.

&#91;embedded content: main screens · 4 phone wireframes, sample data\]

The Results screen colours each word by score; tapping *Fix 3 red words* steps through each red word on the Fix screen, then asks for the full sentence again.

## Content and difficulty progression

Launch with 120 passages, 20 per level, written in-house or taken from public-domain texts. Each passage is tagged with the British sounds it practises.

| Level | Passage length | Content | Sound focus |
| --- | --- | --- | --- |
| 1 | 1 sentence, 8–12 words | Everyday phrases | Short vowels, clear consonants |
| 2 | 2–3 sentences, \~30 words | Daily routines | /θ/ and /ð/ (think, this), word endings |
| 3 | Paragraph, \~60 words | Short stories, emails | Long vowels: *bath*, *car*, *thought*; no /r/ after vowels |
| 4 | \~100 words | News-style, workplace | Word stress, weak forms (*to*, *for*, *of*) |
| 5 | \~150 words | Opinion pieces, presentations | Linking, rhythm, sentence stress |
| 6 | \~200 words | Literature, tongue-twisters, IELTS-style | Intonation and fast connected speech |

**How the next passage is chosen:** 70% from the current level, weighted towards the user's three weakest sounds; 20% review of words they missed before; 10% a preview of the next level.

**Placement:** a 2-minute test on first use (one passage from each of levels 1, 3 and 5) sets the starting level.

## Additional features roadmap

Each of these works offline with free tools.

| Feature | What it does | Release |
| --- | --- | --- |
| Weak-sounds profile | Shows the user's 5 hardest sounds with trend lines | v1.1 |
| Minimal pairs | Drills sound pairs they confuse (ship/sheep, cot/caught, full/fool) | v1.1 |
| Spaced review | Brings back missed words after 1, 3, 7 and 21 days | v1.1 |
| Record and compare | Plays the user's word right after the British model | v1.1 |
| Streaks and reminders | Daily goal, streak count, local notifications (no server) | v1.1 |
| Before and after | Replays the user's first recording of a passage beside their latest | v1.2 |
| Stress and intonation | Shows stressed syllables and a pitch line against the model | v1.2 |
| Custom text | Paste or photograph text (on-device text recognition) and practise it | v1.2 |
| Topic packs | Job interviews, workplace, travel, IELTS reading | v1.2 |
| Mouth guides | Simple drawings of tongue and lip position for hard sounds | v1.3 |
| Generated passages | A small on-device language model writes passages full of the user's weak sounds | v1.3, if quality holds on phones |
| Other accents | Northern English, Scottish, General American as targets | Later |

## Technical architecture, data and privacy

The app has no backend: Flutter for the interface, a Dart scoring layer, and native ONNX models, with all data in a local SQLite database.

**Layers**

- **Interface (Flutter):** screens, text highlighting, audio playback, charts.
- **Practice logic (Dart):** passage picker, level rules, spaced review queue, streaks.
- **Scoring engine:** recorder (record package) → VAD → phoneme model (sherpa-onnx / ONNX Runtime) → alignment and scoring in Dart or a small C++ plug-in.
- **Content pack:** passages, tags and pre-computed British phonemes as a versioned JSON bundle in the app.
- **Storage:** SQLite (drift or sqflite) for attempts and scores; audio files in app-private storage.

**Data model**

| Table | Key fields |
| --- | --- |
| passages | id, level, text, words\[\] with expected phonemes and stress, sound tags |
| attempts | id, passage\_id, date, overall score, fluency score, audio file (optional) |
| word\_results | attempt\_id, word index, score, phonemes heard vs expected |
| sound\_stats | phoneme, rolling accuracy, attempts count, last practised |
| review\_queue | word, due date, interval, ease |
| user\_profile | level, placement result, daily goal, streak |

**Privacy (UK GDPR)**

- Audio never leaves the device; there is no analytics SDK in version 1.
- Recordings are deleted after scoring unless the user turns on "keep recordings" for before-and-after replay.
- A settings option deletes all recordings and history in one tap.
- Export: the user can save their progress as a file for backup.

## Release plan, metrics and risks

Start with a two-week engine test; the scoring accuracy decides everything else.

**Phases**

1. **Engine spike (2 weeks):** run the phoneme model on a phone, score 50 recorded sentences from 5 speakers, compare with a teacher's marks. Go only if agreement reaches 80%.
2. **MVP (8 weeks):** features F1–F4, 6 levels, placement test, 120 passages.
3. **Beta (4 weeks):** 30–50 learners via TestFlight and Google Play internal testing.
4. **v1.1 to v1.3:** roadmap features above.

**Success metrics**

| Metric | Target after beta |
| --- | --- |
| Word-level agreement with teacher | 80% or higher |
| Scoring time, 60-word passage | Under 3 s |
| Users practising 3+ days a week | 40% |
| Average score gain on repeated passages over 4 weeks | +10 points |
| App download size | Under 150 MB |

**Risks**

| Risk | Mitigation |
| --- | --- |
| The free phoneme model was trained on many languages and may be lenient or harsh on British vowels | Calibrate score thresholds on recordings of British speakers; fine-tune on free British speech data if needed |
| Full model too large or slow on older phones | Ship the light model; offer the full one as an optional download |
| Heavy foreign accents or noisy rooms give unfair scores | Check audio level and noise first; ask for a quieter spot |
| British dictionary gaps | Pre-compute library passages; mark unknown words as not scored |
| GPL tools leaking into the app | Use eSpeak NG only in the content build, never shipped |

**Open questions**

- Free app, one-off purchase, or subscription?
- Who writes and checks the 120 launch passages?
- Which free British speech data will calibrate scoring?

## Sources

- [wav2vec2-lv-60-espeak-cv-ft model card (Meta, Apache-2.0)](https://huggingface.co/facebook/wav2vec2-lv-60-espeak-cv-ft)
- [wav2vec2-espeak-ctc ONNX export](https://huggingface.co/sadda-speech/wav2vec2-espeak-ctc)
- [asr\_lib changelog: sherpa\_onnx Flutter on Android, iOS, desktop](https://pub.dev/packages/asr_lib/changelog)
- [Britfone British pronunciation dictionary](https://www.npmjs.com/package/britfone)
- [Piper TTS](https://github.com/agisota/piper-TTS)
- [BEEP dictionary licence (OpenSLR)](https://openslr.org/14)
