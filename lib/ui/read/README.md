# lib/ui/read (owner: U2-read)

Read and record screen (`ReadScreen(args: ReadArgs)`, built by the router).

| File | What |
| --- | --- |
| `read_screen.dart` | Screen + `ReadBody` (renders one `ReadState`; used by goldens) |
| `read_state.dart` | `ReadState`, `ReadContent`, sealed `ReadPhase` (loading, idle, recording, scoring, permission denied, retry needed, failed, done) |
| `scoring_controller.dart` | `ScoringController` (`scoringControllerProvider(args)`): record -> VAD -> model tier -> recognise -> score -> save or pop; logs practice time |
| `widgets/record_controls.dart` | `RecordButton` (tap or hold-to-record), `LevelWaveform`, `formatElapsed` |

Tests: `test/ui/read/`; goldens in `test/ui/goldens/read_screen_golden_test.dart`.
