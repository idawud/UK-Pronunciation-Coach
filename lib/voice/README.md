# lib/voice (owner: C4-voice)

`VoiceService` for the British model voice. Entry point: `voice.dart`
(`createVoiceService()`, `VoiceFlags`).

| File | What |
| --- | --- |
| `tts_engine.dart` | `TtsEngine` seam + `TtsVoice` / `TtsEvent` (fake it in tests) |
| `flutter_tts_engine.dart` | `TtsEngine` over flutter_tts (MIT) |
| `voice_selection.dart` | ranks installed offline en-GB voices; display names |
| `rate_mapping.dart` | contract rate (1.0 / 0.6) -> flutter_tts rate per platform |
| `system_voice_service.dart` | `SystemVoiceService`: the default `VoiceService` |
| `piper/` | optional Piper voice behind `VoiceFlags.piperVoice` (off): engine interface, licence catalogue, fallback service. No engine implementation yet. |

Tests: `test/voice/` (fake TTS engine; runs `runVoiceServiceContract`),
`integration_test/C4-voice/` (real plug-in). See `docs/handoff/C4-voice.md`.
