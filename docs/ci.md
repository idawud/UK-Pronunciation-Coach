# CI

GitHub Actions workflows live in `.github/workflows/`. All use dependency caching
(Flutter SDK + pub via `subosito/flutter-action`, pip, Gradle, AVD snapshot, model
files) and cancel superseded runs (`concurrency` + `cancel-in-progress`). Flutter is
pinned to **3.47.7** in each workflow (`FLUTTER_VERSION`); bump it in one PR together
with any golden updates.

| Workflow | Runs when | Jobs | Owner |
| --- | --- | --- | --- |
| `ci.yml` | every pull request, push to main | `lint`, `test`, `golden`, `python`, `content`, `licences`, `build-android` | W0 |
| `integration.yml` | push to main, nightly 02:00 UTC, PRs labelled `run-integration`, manual | `android-emulator` (API 34, KVM), `ios-simulator` (nightly / manual, macos-latest) | W0 sets up, I1 completes |
| `eval.yml` | manual, weekly | accuracy harness, fails under 80% | I2 |
| `release.yml` | tag `v*` | signed AAB + IPA, GitHub Release, optional beta upload | R1 |

## ci.yml jobs

| Check name | What it does |
| --- | --- |
| `lint` | `dart format` check (generated files excluded), `flutter analyze --fatal-infos`, `build_runner build` + `git diff --exit-code` (generated code committed and current) |
| `test` | fetches the bundled light model (cached), `flutter test --coverage --exclude-tags golden,perf` (unit, widget, contract, content, fixtures, and the host e2e journey `test/e2e/`), then `tools/ci/coverage_gate.py` (85% engine / practice / data, 70% ui), then the timing tests alone (`flutter test --tags perf --concurrency=1`); uploads `lcov.info` |
| `golden` | `flutter test --tags golden` on ubuntu; uploads `failures/` on failure |
| `python` | `ruff check tools`, `ruff format --check tools`, `pytest tools --cov` (80% gate from pyproject.toml) |
| `content` | `tools/ci/check_content.py` on `assets/content/passages.v1.json` (skips with a notice until C1 delivers it; C1 adds the rebuild-and-diff step) |
| `licences` | `tools/ci/check_licences.py`: no GPL / AGPL Dart package (resolved from pubspec.lock) or `tools/**/requirements*.txt` package; every model / voice / dictionary file named in `docs/licences.md`. Approved exceptions: `tools/ci/licence_allowlist.txt` |
| `build-android` | `flutter build apk --debug`, uploaded as the `app-debug-apk` artifact |

## Branch protection for `main`

Settings -> Branches -> add rule for `main`:

- Require a pull request before merging (1 approval).
- Require status checks to pass, and require branches to be up to date. Required checks:
  `lint`, `test`, `golden`, `python`, `content`, `licences`, `build-android`.
- Do not require `android-emulator` / `ios-simulator` on PRs (they run on main and
  nightly, and on PRs only with the `run-integration` label). `integration.yml` must be
  green on the commit before any release tag (R1's `release.yml` checks it).
- Create the `run-integration` label so PR authors can opt in.
- The e2e journey (`integration_test/e2e/`) runs in the `android-emulator` job with
  aeroplane mode on (`adb shell cmd connectivity airplane-mode enable`) and nightly on
  the iOS simulator (network on there, but the journey fails on any HTTP client or
  socket the app opens). It is part of `integration.yml`, so it gates every release tag.

## Model files in CI

`assets/models/manifest.json` (added by A4 / A2) lists each model file's release URL,
SHA-256, tier and whether it is bundled. `tools/ci/fetch_models.py` downloads missing
files into `.model-cache/` (cached with `actions/cache`, key = hash of the manifest),
verifies SHA-256, and copies `bundle: true` files into `assets/models/`. Model binaries
are git-ignored and never committed, except `assets/models/silero_vad.onnx` (Silero VAD,
2.3 MB, MIT), which is committed.

## Costs

Public repositories run Actions free; private ones use the monthly allowance. macOS
minutes cost more, so the iOS job is nightly only.
