# lib/engine/audio (owner: A1-audio)

Implements `AudioRecorder` (lib/core/contracts/audio_recorder.dart) as
`CoachAudioRecorder`. Import everything from `audio.dart`.

| File | What |
| --- | --- |
| `coach_audio_recorder.dart` | The recorder; `CoachAudioRecorder.platform()` for the app; `loadBundledVad` |
| `mic.dart` | Plug-in seams: `MicSource` (`RecordMicSource`, `record` raw PCM16 stream) and `MicPermissions` (`PermissionHandlerMicPermissions`) |
| `fixture_mic.dart` | `FixtureMicSource` (plays a WAV instead of the microphone) and `FixedMicPermissions`, for tests and I1's e2e |
| `signal.dart` | Pure maths: dBFS, level 0-1, peak, SNR estimate, `QualityReport`, `LevelMeter` |
| `vad.dart` | `SpeechProbabilityModel` / `VadBackend`, chunking, segments (150 ms pad, merge, clamp), `SilenceTimer` (2 s), `EnergyVadBackend` fallback |
| `silero_vad.dart` | Silero VAD v5/v6 on ONNX Runtime's C API (library shipped by `onnxruntime_v2`) |
| `wav.dart` | WAV decode / encode and the streaming `WavFileWriter` |

The Silero model is bundled as `assets/models/silero_vad.onnx` (fetched, not
committed; see docs/handoff/A1-audio.md). Without it the recorder falls back to the
energy VAD. Tests: `test/engine/audio/`, `integration_test/A1-audio/`. Binding it in
`lib/core/providers.dart` is I1's job.
