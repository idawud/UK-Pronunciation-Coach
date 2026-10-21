# integration_test/e2e (owner: I1-integration)

End-to-end journey with fixture audio and no network:
first run -> onboarding -> placement -> Home -> Read -> Results -> Fix a word ->
level up after 3 high scores -> Progress shows history -> delete all data.

| File | What |
| --- | --- |
| `journey.dart` | The steps (`Journey`), `JourneyMic` (plays the chosen fixture clip, then silence, into A1's real recorder) and `NetworkSpy` (fails the run if any HTTP client or socket is opened) |
| `journey_test.dart` | On-device run: every real implementation, a fresh database file, the bundled light model and Silero VAD |
| `fixture_clips.dart` | Generated: `test/e2e/fixtures/*.wav` as base64 (`dart run test/e2e/make_fixture_clips.dart`) |

The same `Journey` runs on the Linux host in `test/e2e/journey_host_test.dart`
(real recorder, recognizer on the host ONNX Runtime, scorer, content, drift and
practice engine; fake TTS and notifications), so `scripts/check.sh` exercises it
whenever the light model has been fetched (`python3 tools/ci/fetch_models.py --tier light`).

Run on a device or emulator (model files fetched first):

```bash
python3 tools/ci/fetch_models.py --tier light
adb shell cmd connectivity airplane-mode enable   # Android: network off
flutter test integration_test/e2e -d <device>
```

`.github/workflows/integration.yml` runs it on the API 34 emulator with aeroplane
mode on (every push to main) and on an iOS simulator (nightly).
