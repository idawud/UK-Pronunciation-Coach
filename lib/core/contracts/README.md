# lib/core/contracts (owner: W0-scaffold, frozen)

Abstract interfaces every Wave 1 agent codes against, plus typed errors, `Clock` and
the route paths / arguments shared by the screens (`navigation.dart`). Pure Dart.

| Contract | Implemented by | Shared test suite |
| --- | --- | --- |
| `AudioRecorder` | A1 (lib/engine/audio) | `test/contracts/audio_recorder_contract.dart` |
| `PhonemeRecognizer` | A2 (lib/engine/runtime) | `test/contracts/phoneme_recognizer_contract.dart` |
| `PronunciationScorer`, `Tips` | A3 (lib/engine/scoring) | `pronunciation_scorer_contract.dart`, `tips_contract.dart` |
| `ContentRepository` | C1 (lib/data/content) | `content_repository_contract.dart` |
| `ProgressRepository` | C2 (lib/data) | `progress_repository_contract.dart` |
| `PracticeEngine` | C3 (lib/practice) | `practice_engine_contract.dart` |
| `VoiceService` | C4 (lib/voice) | `voice_service_contract.dart` |

Frozen: never edit. Write proposals in `docs/contract-requests/<agent-id>.md`.
