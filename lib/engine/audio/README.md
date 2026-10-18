# lib/engine/audio (owner: A1-audio)

Implements `AudioRecorder` (lib/core/contracts/audio_recorder.dart): 16 kHz mono
16-bit WAV via `record`, microphone permission via `permission_handler`, level
stream (~20/s), Silero VAD via sherpa_onnx (`silenceDetected` after 2 s,
`speechSegments` with 150 ms padding) and the `AudioQuality` pre-check.

Tests: `test/engine/audio/` (WAV fixtures in `test/fixtures/audio/`, see its
manifest) and `integration_test/A1-audio/` running `runAudioRecorderContract`.
Bind it in `lib/core/providers.dart` is I1's job; do not edit that file.
