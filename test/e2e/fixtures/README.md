# test/e2e/fixtures (owner: I1-integration)

Audio the e2e journey plays into A1's real recorder (16 kHz mono 16-bit WAV).
`integration_test/e2e/fixture_clips.dart` embeds the same files as base64 for the
device run; regenerate it with `dart run test/e2e/make_fixture_clips.dart`
(`fixture_clips_test.dart` fails when it is stale).

| File | Content | Role | Source |
| --- | --- | --- | --- |
| `off_script.wav` | "On Thursday we walked by the river." | Matches no passage: placement reads (start at level 1) and the first passage (red words for Fix a word) | Copy of `test/fixtures/audio/clean_read.wav` (W0, eSpeak NG output, dev-side only) |
| `l1-003.wav` | "I think I left my keys in the kitchen." | Clean read of passage l1-003 (Lost keys), level-up run | Kokoro-82M v1.0 voice `bm_george` (Apache-2.0), rendered from the passage's Britfone phonemes by I2's `tools/eval/synth` (`dry/` output: no noise or effects) |
| `l1-004.wav` | "My dad has a bad back, so he can't run." | Clean read of l1-004 (Bad back) | same |
| `l1-014.wav` | "Did you remember to bring your lunch box from the van?" | Clean read of l1-014 (Lunch box) | same |

The three clean reads score 94-95 overall with the light model (I2's harness,
2026-10-21; 95-97 with the full model), so the run of three at 85+ that moves the
user up a level is not borderline. Nothing here ships in the app.
