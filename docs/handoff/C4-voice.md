# Handoff: C4-voice

`SystemVoiceService` implements `VoiceService` with the phone's own offline en-GB
voice through flutter_tts (MIT). An optional Piper neural voice sits behind a
feature flag (off) as an interface, a licence-reviewed voice catalogue and a
fallback service; the Piper engine itself is a documented next step.

## How to use it

```dart
import 'package:uk_pronunciation_coach/voice/voice.dart';

final voice = createVoiceService();          // SystemVoiceService over FlutterTtsEngine
await voice.hasBritishVoice();               // false -> show "install a British voice"
await voice.voiceName();                     // "Daniel (Enhanced)", "English (UK) RJS", null
await voice.speak('Thursday');               // normal (1.0)
await voice.speak('Thursday', rate: VoiceService.slowRate);  // slow (0.6)
await voice.stop();
```

I1 binds it in `lib/core/providers.dart` (snippet in
`docs/contract-requests/C4-voice.md`). `hasBritishVoice()` / `voiceName()` re-read
the installed voices each call, so onboarding can re-check after the user installs
a voice in system settings; the next `speak` uses the new voice.

## Behaviour

- **Voice selection** (`voice_selection.dart`): keep voices whose locale is en-GB
  (`en-GB`, `en_GB`, `en-GB-*`, `eng-GBR`, `en-UK`); drop network voices
  (`network_required`, `networkTts` feature without `embeddedTts`, `-network` names),
  not-downloaded voices (`notInstalled`) and iOS Personal Voices. Rank by quality
  (iOS premium > enhanced > default; Android very high > high > normal > unknown >
  low > very low; iOS Eloquence and legacy novelty voices 5 points below their
  tier), then lower Android latency, then name. If `setVoice` is rejected, or there
  is no en-GB voice, the engine is set to language `en-GB` and still speaks (the
  button is never silent) while `hasBritishVoice()` reports false.
- **Rates** (`rate_mapping.dart`), contract rate -> flutter_tts `setSpeechRate`:

  | Platform | Native scale | 1.0 (normal) | 0.6 (slow) | rule |
  | --- | --- | --- | --- | --- |
  | Android | `TextToSpeech` 1.0 = normal, linear; plug-in multiplies by 2 | 0.5 (native 1.0) | 0.3 (native 0.6) | `rate / 2` |
  | iOS / macOS | `AVSpeechUtterance.rate` 0-1, default 0.5, non-linear | 0.5 | 0.35 | below 1: `0.5 - (1-rate)*0.375`; above: `0.5 + (rate-1)*0.5` |
  | others | (not shipped) | 0.5 | 0.3 | Android rule |

  Output is clamped to 0-1. Rates outside 0.1-2.0 (or NaN) throw `ArgumentError`.
- **speak** stops anything playing, then waits for the engine's completion /
  cancel / error event (flutter_tts `awaitSpeakCompletion` is off because on iOS a
  cancelled utterance never completes it). The cancel event caused by our own
  `stop` is swallowed so it cannot end the next utterance. A timeout (5 s + 150 ms
  per character / rate) guards against engines that drop the completion event.
- **iOS audio session:** shared instance, category `playback` (plays in silent
  mode), option `duckOthers`, mode `spokenAudio`. A1's recorder will switch the
  session to record; check the order of play-then-record on a device in I1.

## Tests

- `test/voice/`: 101 tests, **100% line coverage** of `lib/voice/`.
  - `runVoiceServiceContract` **passes** against `SystemVoiceService` with the fake
    TTS engine (with and without an en-GB voice) and against `PiperVoiceService`
    (Piper available / unavailable).
  - Voice ranking tables (iOS and Android), locale and offline rules, display names.
  - Rate mapping per platform, and the rates actually sent through the service.
  - Completion, error, outside cancel, stop, stale cancel, stop during set-up,
    refused / throwing engine, timeout (fake_async), rescan after install.
  - `FlutterTtsEngine` against a mocked `flutter_tts` MethodChannel (argument shapes,
    iOS set-up calls, platform events).
- `integration_test/C4-voice/voice_service_device_test.dart`: contract suite on the
  real plug-in, voice listing, word / sentence at both rates, stop. **Analysed only;
  not run** (no emulator here).
- `scripts/check.sh` passes.

## Piper (optional, `--dart-define=PIPER_VOICE=true`, off by default)

What exists: `VoiceFlags`, `PiperEngine` interface, `PiperVoiceService` (rate ->
Piper `length_scale = 1/rate`; falls back to the system voice when Piper is
unavailable, fails to load or cannot speak a text), `piperEnGbVoices` licence
catalogue. `createVoiceService` uses Piper only when the flag is on **and** an engine
is passed, so today the app always uses the system voice.

**Licence findings** (all 11 en_GB voices in rhasspy/piper-voices; table in
`docs/licences.md`):
- **Allowed: `en_GB-cori-medium` (63.5 MB) and `en_GB-cori-high` (114 MB).** Trained
  from scratch by Bryce Beattie on public-domain LibriVox recordings (Cori Samuel,
  British female). Medium is the sensible size.
- **Not allowed: every other voice.** alan, alba, aru, jenny_dioco,
  northern_english_male, semaine and vctk are fine-tuned from en_US *lessac*
  (Blizzard 2013 data: research only, explicitly no commercial speech products);
  alan-low and southern_english_female-low from en_US *ryan* (CC BY-NC-SA). semaine's
  own data is CC BY-NC-SA; alan's is "All Rights Reserved".
- **Blocker for sherpa_onnx:** besides the duplicate ONNX Runtime, sherpa-onnx's Piper
  support compiles in eSpeak NG (GPL-3.0) for phonemisation, which may not ship.

**Next step (not done):** implement `PiperEngine` with A2's ONNX Runtime (no new
native dependency) and a Dart phonemiser that maps Britfone IPA (C1, MIT) onto the
voice's `phoneme_id_map` (Cori was trained on eSpeak `en` = British phonemes, so the
inventory matches closely; needs a symbol mapping and stress marks), falling back to
the system voice for out-of-vocabulary words. Ship the model as a Release asset with
SHA-256 and a `docs/licences.md` row, then audio playback of the 22,050 Hz output
(needs a player plug-in; check its licence).

## pubspec edits (ownership exception)

`pubspec.yaml`: added `flutter_tts: ^4.2.5` (MIT; no Dart dependencies besides
Flutter). `pubspec.lock` updated by `flutter pub add` (one new entry). Commit
f5e0a02.

## Requests

`docs/contract-requests/C4-voice.md`: (1) Android manifest `<queries>` for
`android.intent.action.TTS_SERVICE` (API 30+ package visibility; without it voices
may not be listed); (2) I1 provider binding; (3) optional open-TTS-settings helper
for U1/U4. No contract changes.

## Known gaps

- Not run on a device: Android/iOS behaviour, the real voice lists and the iOS slow
  value (0.35) need checking by ear; tune `TtsRateMapping.iosSlowSlope` if 0.6x
  sounds wrong. Integration tests only analysed.
- Android voices with `quality: unknown` from third-party engines (e.g. Samsung) rank
  below "normal"; fine for Google TTS, unverified elsewhere.
- If an engine sends no cancel event on `stop`, one later genuine outside cancel is
  ignored and that `speak` ends by timeout instead.
- Piper engine not implemented (see above).
