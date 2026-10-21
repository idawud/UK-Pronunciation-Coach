# Contract requests: A1-audio

## Status (I1-integration, 2026-10-21)

1. Silero VAD bundled: **done**. `assets/models/silero_vad.onnx` (v6.2, SHA-256 `1a153a22…88e3`) is committed (git-ignore exception, 2.3 MB) instead of a manifest entry: I1 cannot publish release assets. The recorder no longer falls back to the energy VAD.
2. `docs/licences.md` row: **done**.
3. iOS `PERMISSION_MICROPHONE=1`: **done** in the new `ios/Podfile` (Flutter's template). Unverified on a device (no Xcode here).
4. Wiring: **done** (`CoachAudioRecorder.platform()` in `lib/core/providers.dart`).

No change to `lib/core/contracts/` or `lib/core/models/` is needed: `AudioRecorder`,
`AudioClip` (with `quality`, `peakDbfs`, `snrDb`) and `Segment` cover everything, and
the shared suite passes unchanged. The requests below are for files A1 does not own.

## 1. Bundle the Silero VAD model (A2 / A4: `assets/models/manifest.json`)

`CoachAudioRecorder` loads `assets/models/silero_vad.onnx` (flat name, bundled).
`*.onnx` there is git-ignored, so the file must come from the model manifest that
`tools/ci/fetch_models.py` reads. Proposed entry (no `tier`, so every
`--tier` filter keeps it; A2's loader should ignore entries without a tier):

```json
{"name": "silero_vad.onnx",
 "url": "https://github.com/snakers4/silero-vad/raw/v6.2/src/silero_vad/data/silero_vad.onnx",
 "sha256": "1a153a22f4509e292a94e67d6f9b85e8deb25b4988682b7e174c65279d8788e3",
 "size": 2327524, "bundle": true}
```

Re-hosting it as a release asset of this repo next to the phoneme models is fine
too (keep the SHA-256). Until it is bundled the app uses the energy-based fallback VAD
(works, but treats any loud sound as speech).

## 2. `docs/licences.md` row (whoever owns it; W0 / I1)

Replace the planned Silero row with:

| Silero VAD v6.2 | `silero_vad.onnx` (2,327,524 B) | MIT (Copyright (c) 2020-present Silero Team) | github.com/snakers4/silero-vad, tag v6.2, `src/silero_vad/data/silero_vad.onnx` | A1 |

It runs on the ONNX Runtime that `onnxruntime_v2` already ships (no sherpa_onnx, so no
second copy of ONNX Runtime in the app).

## 3. Native config (R1 / I1: `android/`, `ios/`)

- **iOS**: permission_handler compiles every permission out unless enabled. There is
  no `ios/Podfile` in the repo yet (Flutter creates it on the first CocoaPods build);
  once it exists, add to its `post_install` block:
  `config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_MICROPHONE=1']`.
  Without it `Permission.microphone` always reports denied on iOS.
- **iOS** `NSMicrophoneUsageDescription` is already in Info.plist (W0).
- **Android** `RECORD_AUDIO` is already in the manifest (W0). `record` 7 needs no other
  change; minSdk 29 is above its minimum.
- Not verified locally (no Android SDK / Xcode here); the A1 on-device tests will show
  it in CI.

## 4. Wiring (I1: `lib/core/providers.dart`)

```dart
final audioRecorderProvider = Provider<AudioRecorder>((ref) {
  final recorder = CoachAudioRecorder.platform();
  ref.onDispose(recorder.dispose);
  return recorder;
});
```

For e2e, inject fixture audio instead of the microphone:
`CoachAudioRecorder(mic: FixtureMicSource.wav(bytes), permissions: FixedMicPermissions())`.
