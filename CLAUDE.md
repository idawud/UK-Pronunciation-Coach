# CLAUDE.md

Guidance for Claude Code agents working in this repository.

## What this is

**UK Pronunciation Coach**: an offline Flutter app (iOS 16+, Android minSdk 29, phones and tablets) that scores how closely a user's read-aloud passage matches Standard Southern British English, highlights wrong words, and drills them.

- Product spec: `.docs/UK Pronunciation Coach – Product Spec.md` (copied to `docs/SPEC.md` by Wave 0; `docs/SPEC.md` is the working copy).
- Build plan, agent IDs, prompts: `.docs/UK Pronunciation Coach – Agent Build Prompts.md`. **Read your agent's section before starting.**

Scoring pipeline (all on device): Britfone lookup → record 16 kHz mono → Silero VAD → wav2vec2 CTC phoneme posteriors (ONNX, 20 ms frames) → CTC Viterbi forced alignment → GOP per phoneme → word / accuracy / fluency scores → tips.

## Stack

Flutter + Dart (null-safe), Riverpod, go_router, freezed + json_serializable, drift (SQLite), `record`, `permission_handler`, sherpa_onnx / onnxruntime, flutter_tts, fl_chart, flutter_local_notifications. Lints: flutter_lints. Tests: flutter_test, mocktail, alchemist (goldens), integration_test. Dev-side Python in `tools/` (pytest, ruff).

## Hard rules (every agent)

1. **Stay in your folders.** Only create or edit files your agent ID owns (table below). Need a contract change? Don't edit it: write the proposal in `docs/contract-requests/<agent-id>.md`.
2. **Contracts and models are frozen** after Wave 0: `lib/core/contracts/`, `lib/core/models/`. Code against the interfaces, never another agent's implementation. Use `lib/core/fakes/` for dependencies.
3. **Offline and private.** No paid or cloud APIs, no runtime network calls (sole exception: A2's one-time full-model download over Wi-Fi). No analytics, tracking or crash-reporting SDKs. No user data leaves the phone.
4. **Licences.** Ship only Apache-2.0, MIT, BSD or similar. Never ship GPL/AGPL code. eSpeak NG is allowed **only** in `tools/`. Never use BEEP or any research-only / non-commercial lexicon. Record every model, dictionary and voice in `docs/licences.md`.
5. **Testing is part of done.** See `docs/testing.md` and the gates below. Never skip or delete a failing test to get green; fix it, or record why in your handoff note.
6. **No large binaries in git.** Model files go to GitHub Release assets with a SHA-256 manifest.
7. **Finish** with `docs/handoff/<agent-id>.md`: what you built, how to use it, known gaps.

## Ownership map

| ID | Branch | Owns |
| --- | --- | --- |
| W0-scaffold | main | project skeleton, `lib/core/{models,contracts,fakes}/`, `lib/core/providers.dart` (until I1), `test/contracts/`, `test/fixtures/`, `.github/`, `scripts/`, `tools/ci/`, `docs/{SPEC,testing,ci}.md` |
| A1-audio | feat/a1-audio | `lib/engine/audio/`, `test/engine/audio/` |
| A2-runtime | feat/a2-runtime | `lib/engine/runtime/`, `assets/models/` (loader only) |
| A3-scoring | feat/a3-scoring | `lib/engine/scoring/` (pure Dart, no Flutter imports), `test/engine/scoring/` |
| A4-models | feat/a4-models | `tools/models/`, `docs/models.md` |
| C1-content | feat/c1-content | `tools/content/`, `assets/content/`, `lib/data/content/` |
| C2-data | feat/c2-data | `lib/data/` except `lib/data/content/` |
| C3-practice | feat/c3-practice | `lib/practice/` |
| C4-voice | feat/c4-voice | `lib/voice/` |
| U1-home | feat/u1-home | `lib/ui/{shell,home,theme,practise,onboarding}/` |
| U2-read | feat/u2-read | `lib/ui/read/` |
| U3-results | feat/u3-results | `lib/ui/results/`, `lib/ui/fix/` |
| U4-progress | feat/u4-progress | `lib/ui/progress/`, `lib/ui/settings/` |
| I1-integration | feat/i1-integration | `lib/core/providers.dart`, `integration_test/e2e/`, `docs/handoff/integration.md` (small fixes elsewhere allowed, listed in handoff) |
| I2-eval | feat/i2-eval | `tools/eval/`, `lib/engine/scoring/config/`, `docs/eval-report.md` |
| R1-release | feat/r1-release | `android/`, `ios/` (signing/store config only), `store/`, `tools/beta/`, `docs/release.md` |

Every agent also owns: its tests under `test/` mirroring its `lib/` path, `integration_test/<agent-id>/` for on-device tests, `docs/handoff/<agent-id>.md`, `docs/contract-requests/<agent-id>.md`.

UI agents use theme tokens from U1 via `Theme.of(context)`; never define your own colours. Score colours: good ≥ 80, close 60–79, fix < 60, plus a non-colour cue (underline + icon).

## Waves and workflow

- **Wave 0** (W0, on `main`): scaffold, contracts, fakes, contract test suites, CI. Human reviews before Wave 1.
- **Engine spike** (recommended): A2 + A3 + A4 + cut-down I2 on 50 sentences / 5 speakers. Continue only if word agreement ≥ 80%.
- **Wave 1** (12 agents in parallel, one git worktree each, branched from Wave 0's commit):
  `git worktree add ../coach-<id-lowercase> -b feat/<id-lowercase> main` (e.g. `../coach-a1-audio`, `feat/a1-audio`).
  Merge in any order; then merge contract-request changes in one small PR.
- **Wave 2**: I1 (integration, e2e) and I2 (eval + calibration) in parallel.
- **Wave 3**: R1 release and beta, after I1 passes and I2 says go.

Keep commits small with clear messages. Open a PR to `main` per agent branch; all `ci.yml` checks must pass.

## Commands

Setup in each shell: `export PATH="$HOME/flutter/bin:$PATH"` and `source .venv/bin/activate` (Python tools; create with `python3 -m venv .venv && pip install -r tools/requirements-dev.txt` in a fresh worktree).

```bash
scripts/check.sh                     # run before every push: format, analyze, tests + coverage gate, pytest
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage              # unit + widget + contract + golden
flutter test test/engine/scoring     # one folder
dart run build_runner build   # after editing freezed/json/drift sources
flutter test integration_test/<agent-id>   # on-device tests (emulator/simulator)
python3 tools/ci/coverage_gate.py coverage/lcov.info
pytest tools/ && ruff check tools/
```

## Testing gates

| Layer | Location | Gate |
| --- | --- | --- |
| Unit | `test/` mirroring `lib/` | 85% for `lib/engine/`, `lib/practice/`, `lib/data/` |
| Contract | `test/contracts/` (`run<Contract>Contract(factory)`) | fakes and every real implementation pass |
| Widget | `test/ui/` | 70% for `lib/ui/`; cover loading, empty, error, permission-denied |
| Golden | `test/ui/goldens/` (alchemist, bundled fonts) | Linux CI only; light + dark, phone + tablet |
| Python | `tools/*/tests/` | 80% for `tools/` |
| Content | `test/content/` | schema valid, 20 passages per level, every scorable word has phonemes |
| On-device | `integration_test/<agent-id>/` | fixture audio only, never a real mic or network |
| E2E | `integration_test/e2e/` | must pass on main, network off |
| Accuracy | `tools/eval/` | ≥ 80% word agreement with teacher labels |

Fixtures (WAV clips, canned posteriors and results) live in `test/fixtures/`.

## Performance targets

Recording start < 300 ms · 60-word passage scored < 2.5 s (full tier, mid-range phone; spec limit 3 s) · scoring 200 words in Dart < 100 ms · 1,000 attempts load < 200 ms · download < 150 MB with light model bundled.
