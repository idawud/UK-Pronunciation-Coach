# Testing

Testing is part of done. Every pull request must pass every `ci.yml` job (docs/ci.md);
run `scripts/check.sh` before you push.

## Layers and gates

| Layer | What it covers | Tool | Location | Gate |
| --- | --- | --- | --- | --- |
| Unit | Scoring maths, alignment, level rules, review intervals, storage, tips | flutter_test, mocktail | `test/` mirroring `lib/` | 85% lines for `lib/engine/`, `lib/practice/`, `lib/data/` |
| Contract | Each implementation behaves like its interface | shared suites | `test/contracts/` | fakes and every real implementation pass |
| Widget | Every screen state: loading, empty, error, permission denied | flutter_test | `test/ui/` | 70% lines for `lib/ui/` |
| Golden | Screens match the sketches, light + dark, phone + tablet | alchemist, bundled fonts | `test/ui/goldens/` | Linux CI only (`golden` job) |
| Python | Content build, model export, eval harness, CI scripts | pytest, ruff | `tools/*/tests/` | 80% for `tools/` |
| Content | Bundle schema, 20 passages per level, phonemes for every scorable word | Dart test + `tools/ci/check_content.py` | `test/content/` | must pass |
| On-device | Native parts: recording from fixture audio, ONNX, SQLite, TTS | integration_test | `integration_test/<agent-id>/` | must pass (emulator) |
| End-to-end | Full journeys with network off | integration_test (+ host mirror in `test/e2e/`) | `integration_test/e2e/` | must pass on main |
| Accuracy | Word agreement with teacher labels | `tools/eval` | `tools/eval/` | >= 80% |

The coverage gate (`tools/ci/coverage_gate.py`) reads `coverage/lcov.info`, ignores
`*.g.dart` / `*.freezed.dart`, and counts the code lines of any Dart file in a gated
folder that no test imports as uncovered, so an untested file cannot hide.
A folder with no Dart code yet is skipped.

## Commands

```bash
scripts/check.sh                       # everything below (goldens on Linux only)
scripts/check.sh --quick               # skip goldens and Python
flutter test                           # all Dart tests (unit, widget, contract, golden)
flutter test --exclude-tags golden,perf   # what the CI "test" job runs
flutter test --tags perf --concurrency=1  # timing gates, alone (check.sh and CI do this)
flutter test test/e2e                  # host e2e journey (needs the light model fetched)
flutter test --tags golden             # what the CI "golden" job runs
flutter test --update-goldens --tags golden   # regenerate goldens (Linux only)
flutter test test/engine/scoring       # one folder
flutter test integration_test/<agent-id> -d <device>   # on-device
python3 tools/ci/coverage_gate.py coverage/lcov.info
.venv/bin/python -m pytest tools --cov && .venv/bin/ruff check tools
dart run build_runner build            # after an approved model change
```

Local setup: Flutter 3.47.7 stable (the version CI pins), then
`python3 -m venv .venv && .venv/bin/pip install -r tools/requirements-dev.txt`.

## Folder layout

```
test/
  contracts/            shared suites: run<Contract>Contract(factory) + fakes_contract_test.dart
  core/                 models round-trip, fakes, providers (W0)
  engine/{audio,runtime,scoring}/   A1, A2, A3
  data/                 C2;  data/content/  C1 repository;  content/  C1 bundle checks
  practice/  voice/     C3, C4
  ui/<screen folder>/   widget tests per screen;  ui/goldens/  all goldens
  fixtures/             shared WAVs, posteriors, results, fonts (see its README)
  helpers/golden.dart   golden sizes and the IPA fallback font
  flutter_test_config.dart   loads fonts, configures alchemist (runs for every test)
integration_test/<agent-id>/   on-device tests;  integration_test/e2e/  I1 journeys
tools/<area>/tests/            pytest
```

## Contract suites

Each contract has one reusable suite in `test/contracts/<name>_contract.dart`:

| Suite | Factory you pass |
| --- | --- |
| `runAudioRecorderContract(create, {recordFor})` | recorder with permission granted (on device, fixture audio injected) |
| `runPhonemeRecognizerContract(create, {clip, checkDownload})` | fresh recognizer; full tier not downloaded; download via a local / fake transport, never the network |
| `runPronunciationScorerContract(create, {checkSemantics})` | scorer; real scorers keep `checkSemantics: true` |
| `runTipsContract(create)` | tips |
| `runContentRepositoryContract(create, {fullLibrary})` | repository; real C1 keeps `fullLibrary: true` (20 per level) |
| `runProgressRepositoryContract((clock) => ...)` | fresh, empty store using `clock` (in-memory drift is fine) |
| `runPracticeEngineContract((clock) => ...)` | engine over an empty progress store and content containing `samplePassages` |
| `runVoiceServiceContract(create)` | service (unit: fake TTS engine; device: real TTS) |

Use them from your own test file:

```dart
import '../contracts/progress_repository_contract.dart';

void main() {
  runProgressRepositoryContract((clock) async => DriftProgressRepository.inMemory(clock: clock));
}
```

The suites and the fakes are frozen with the contracts. If a suite is wrong, write it
up in `docs/contract-requests/<agent-id>.md`.

## Fakes and fixtures

- `lib/core/fakes/` has a working fake for every contract; tweak public fields to reach
  states (`FakeAudioRecorder(permission: MicPermission.permanentlyDenied)`,
  `FakePhonemeRecognizer(failDownload: true)`, `FakePronunciationScorer(wordScores: [...])`).
- `sample_data.dart`: 3 passages (levels 1, 3, 5), the canned river attempt (Thursday,
  castle, bath red), `syntheticPosteriors()` / `syntheticSpeech()` for posteriors with a
  known answer (substitutions, missed words), `buildAttempt()` / `goodAttempt()`.
- Screens: override providers, e.g.
  `ProviderScope(overrides: [audioRecorderProvider.overrideWithValue(FakeAudioRecorder(...))])`.
- `test/fixtures/`: WAV clips (clean, mispronounced, silence tail, quiet, noisy,
  silence, noise) with `audio/manifest.json`, canned JSON. See `test/fixtures/README.md`.

## Golden tests

- alchemist `goldenTest(...)`; tag `golden` is automatic.
- `test/flutter_test_config.dart` loads Roboto, Material Icons and DejaVu Sans (IPA
  glyphs Roboto lacks) from `test/fixtures/fonts/`. Wrap the theme with
  `withTestFonts(AppTheme.light())` from `test/helpers/golden.dart` so IPA renders.
- Readable goldens (`goldens/linux/`) are generated and compared on Linux only;
  obscured-text goldens (`goldens/ci/`) everywhere. Regenerate on Linux with the pinned
  Flutter version. Cover light + dark and phone (390x844) + tablet (820x1180).
- Put each screen's golden test in `test/ui/goldens/<screen>_golden_test.dart`.

## On-device tests

- `integration_test/<agent-id>/`, run by `.github/workflows/integration.yml` on an
  Android API 34 emulator (and nightly on an iOS simulator).
- Fixture audio only: never a real microphone, never the network.
- Model files come from GitHub Release assets listed in `assets/models/manifest.json`
  (`tools/ci/fetch_models.py`, cached by SHA-256).

## Timing tests and flakiness

Tests that time something are tagged `perf` (`@Tags(['perf'])` at the top of the
file) and run on their own after the main run: `flutter test --tags perf
--concurrency=1` (check.sh and CI's `test` job). The main run uses every core and
other processes may share the machine, which made these fail although nothing was
slow on an idle machine:

| Test | Gate (unchanged) | Fix |
| --- | --- | --- |
| A3 `test/engine/scoring/benchmark_test.dart` | 200 words scored in < 100 ms | `perf` tag; best of 3 medians of 7 runs (a consistently slow scorer still fails); a second case with alternative pronunciations |
| C2 `test/data/progress/performance_test.dart` | 1,000 attempts load in < 200 ms | `perf` tag; best of 10 loads |
| U2 `scoring_controller_test.dart` "waveform keeps only the latest values" | 64 values kept | waits until every level value was emitted instead of a fixed 100 ms of real time |

Write new timing tests the same way, and prefer waiting for a condition (or fake
time) over a fixed real delay. Never add retries.

## End-to-end journey

`integration_test/e2e/journey.dart` holds the journey; `integration_test/e2e/journey_test.dart`
runs it on a device and `test/e2e/journey_host_test.dart` on the Linux host with the
real engine (it skips when `assets/models/light-model.onnx` is missing: run
`python3 tools/ci/fetch_models.py --tier light`). See `integration_test/e2e/README.md`.

Unit and widget tests under `test/` bind every provider to its fake by default
(`test/flutter_test_config.dart` sets `debugUseFakesOverride`); the app itself uses
the real implementations. A test that wants a real one overrides the provider.

## Rules

- Never skip or delete a failing test to get green: fix it or record why in your
  handoff note. Fix flaky tests rather than adding retries.
- Tests must not touch the network, the real clock (inject `Clock`), or a real
  microphone.
