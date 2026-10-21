# Contract and native requests: C4-voice

## Status (I1-integration, 2026-10-21)

1. `<queries>` TTS_SERVICE: **done** (`android/app/src/main/AndroidManifest.xml`).
2. Binding: **done** (`createVoiceService()` in `lib/core/providers.dart`).
3. Open-TTS-settings helper: **deferred** (optional, needs a new plug-in; the install guidance and "Check again" work without it).

No change to `lib/core/contracts/` is needed: `SystemVoiceService` passes
`runVoiceServiceContract` unchanged.

## 1. Android: TTS service query (native, for R1 / I1)

**What:** add to `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`
(merge with any existing `<queries>` block):

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.TTS_SERVICE" />
  </intent>
</queries>
```

**Why:** apps targeting API 30+ have package visibility filtering; without this
query `TextToSpeech` cannot bind to the installed engine on some devices, so
`getVoices` returns nothing and `hasBritishVoice()` wrongly reports false. The
flutter_tts README asks for exactly this. C4 may not edit `android/`.

**Affects:** nothing in Dart. Verify with `integration_test/C4-voice/` on the
API 34 emulator.

## 2. Bind the real service (I1, `lib/core/providers.dart`)

```dart
import '../voice/voice.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = createVoiceService(); // Piper only with --dart-define=PIPER_VOICE=true
  ref.onDispose(service.stop);
  return service;
});
```

## 3. Optional: a "how to install a British voice" helper (UI owners)

`hasBritishVoice()` re-reads the installed voices on every call, so onboarding
(U1) and Settings (U4) can simply call it again when the app resumes after the
user visits system settings. Opening the system TTS settings screen needs a
platform intent (`com.android.settings.TTS_SETTINGS`) that flutter_tts does not
offer; if wanted, add a small helper (e.g. `app_settings`, MIT) in a later PR.
No contract change required.
