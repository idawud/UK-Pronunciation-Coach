# lib/voice (owner: C4-voice)

Implements `VoiceService` with the phone's en-GB voice via flutter_tts (offline),
rates 1.0 and 0.6; optional Piper voice behind a flag (record its licence in
docs/licences.md).

Tests: `test/voice/` with a fake TTS engine, running `runVoiceServiceContract`.
