# test/fixtures (owner: W0-scaffold)

Shared test inputs. Read-only for other agents: if you need a new shared fixture, add
it under your own test folder or ask in `docs/contract-requests/<agent-id>.md`.

| Path | What | How it was made |
| --- | --- | --- |
| `audio/*.wav` | 16 kHz mono 16-bit PCM clips: `clean_read`, `mispronounced_thursday` ("Tursday"), `read_then_silence` (2.5 s tail, for `silenceDetected`), `quiet_read` (peak -40 dBFS, `tooQuiet`), `noisy_read` (SNR ~5 dB, `tooNoisy`), `silence`, `noise` | `tools/ci/make_audio_fixtures.py` (eSpeak NG en-gb voice, dev-side only; noise with a fixed seed) |
| `audio/manifest.json` | Text, duration, peak, expected `AudioQuality`, rough speech regions per clip | same script |
| `passages/sample_passages.json` | The 3 sample passages (levels 1, 3, 5) as `Passage` JSON | `dart run scripts/generate_fixtures.dart` |
| `posteriors/river_canned.json` | `PhonemePosteriors` matching the canned river result (θ→t in Thursday, ɑː→æ in castle and bath) | same |
| `posteriors/tea_perfect.json` | Perfect-read posteriors for the level 1 passage | same |
| `results/river_canned_attempt.json` | The canned `AttemptResult` (Thursday, castle, bath red) | same |
| `fonts/` | Roboto + Material Icons (Apache-2.0) and DejaVu Sans (Bitstream Vera licence, IPA fallback) for goldens | copied from the Flutter SDK / Debian `fonts-dejavu-core` |

Notes:

- The posteriors are synthetic (known answers), not model output for the WAV clips.
  Real model output for `clean_read.wav` belongs to A2's tests once a model exists.
- eSpeak speech is robotic. It is fine for recorder, VAD and level tests, not for
  judging scoring accuracy (that is I2's eval set).
- `fixtures_test.dart` fails if the JSON drifts from `lib/core/fakes/sample_data.dart`
  or a WAV is not 16 kHz mono 16-bit.
