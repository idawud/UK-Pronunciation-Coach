# Handoff: I2-eval

## Update 2026-10-20: synthetic British-voice labels (branch feat/i2-synth-eval)

No teacher will be paid, so the default accuracy gate now uses synthetic labels.
British TTS voices read the eval sentences from phonemes, once as written and once with
1–3 injected learner errors, so each word's right/wrong label is known by construction.
Full numbers are in docs/eval-report.md, "Synthetic British-voice evaluation".

**What I built** (`tools/eval/synth/`, 100% pytest coverage, ruff clean):

- `voices.py`: the voice registry and pinned files with SHA-256, plus the Kokoro and
  Piper ONNX engines.
  - Kokoro-82M British voices (Apache-2.0) and Piper cori medium/high (MIT).
  - Licences were checked at the source; see `tools/eval/SOURCES.md`.
- `phonemes.py`: Britfone SSBE to Kokoro misaki-GB symbols and to eSpeak `en` (Piper).
- `sentences.py` + committed `sentences.tsv`: 200 app sentences and 100 VCTK texts.
- `inject.py`: the error catalogue from `tips_table.dart` and common errors. This covers
  substitutions, an added r, a dropped final consonant, h-dropping, an added h and
  moved stress.
- `augment.py`: speed, padding, synthetic noise at 10–30 dB, reverb and a phone band
  (numpy only).
- `build.py`: `fetch` / `sentences` / `plan` / `synth` / `status` / `subset`.
  - It writes `passages.json`, `manifest.tsv`, `labels.csv` (agreement.py format plus
    error/voice/split/read/aug columns), `items.tsv` and WAVs into the git-ignored
    `tools/eval/data/synth/`.
- `report.py`: agreement, kappa, the always-right baseline, per split/voice/read/
  augmentation, per-error-type detection and clean-read false red.
  - It gates the held-out voices at 80% (optional `--min-kappa`).
- `calibrate.py`: a word-score grid search on the tuning voices, capped by native VCTK
  false red.
- `run_harness.sh`: runs every gate (native, synthetic, optional teacher) and fails if
  any failed. `EVAL_SYNTH_BUILD=1` synthesises; `EVAL_SYNTH_PARTIAL=1` scores a partial
  build.
- `eval.yml`: restores the synthetic audio from cache. It synthesises only on manual
  runs with `build_synth` (voices cached; timeout 360 min), so weekly runs without the
  cache skip.
- `LABELLING.md`: synthetic labels are the default, and teacher labels are optional.

**Results** (3,600 clips, 30,228 words, current defaults):

- Held-out voices (bm_george, bf_isabella, cori): 87.4% agreement, kappa 0.26.
  - 23.7% of injected errors come out red.
  - 3.4% false red on right words.
- All voices: 87.5% agreement, kappa 0.25. Clean reads: 3.1% red.
- An engine that marks every word right would also agree 87.4%.
- VCTK native re-run: 3.6% false red (held out 3.7%), unchanged.
- Calibration is **unchanged**:
  - the kappa-optimal config under the VCTK cap is the current default;
  - the agreement-optimal one is more lenient and catches fewer errors.
- Interim verdict: the 80% gate passes on paper, but my verdict is **NO-GO on
  accuracy**, because kappa is low and the engine catches fewer than 1 in 4 clean,
  deliberate errors.

**Known gaps**:

- **It's a proxy.** TTS voices make clean substitutions with no accent, so the result
  can be off in either direction.
- The model's `heard` shows the injected sound in only 38% of substitutions. TTS
  realisation and model bias can't be separated without a listener.
- Tuning voices read a third of the sentences each, because of the CPU budget
  (Kokoro ONNX runs at about real time per core here).
- Piper output is not deterministic (VITS noise), so cori clips differ slightly between
  re-renders.
- `eval.yml` was checked as YAML/logic only, not run on GitHub.
- `docs/licences.md` rows were requested in contract request 4 (I don't own that file).

---

## Engine-spike version (2026-10-19)

I built the accuracy harness, a native-British eval set with controlled-error probes, a
calibration of `ScoringConfig`, the teacher-labelling kit and `eval.yml`. The numbers
and the spike verdict are in **docs/eval-report.md**.

## What I built

- **Harness** (`tools/eval/dart/`): runs the real engine on the Linux host and writes
  per-word and per-clip CSVs.
  - Engine: A2's `OnnxPhonemeRecognizer` with the plug-in's host ORT library, then A3's
    `GopPronunciationScorer`.
  - It can score several configs in one run and caches posteriors by WAV and model.
  - It is a `flutter test` entry point, because the recognizer imports Flutter. It sits
    outside `test/`, so normal test runs skip it.
- **Lexicon** (`tools/eval/lexicon.py`): Britfone 3.0.1 (MIT), pinned and SHA-256 checked,
  plus derived plurals. eSpeak NG en-gb-x-rp is a flagged fallback (dev-side only).
  BEEP is never used.
- **Eval set** (`tools/eval/build_set.py`, `tools/eval/evalset/`):
  - 250 VCTK clips (CC-BY-4.0): 5 Southern England speakers x 50 sentences.
  - Accents were verified against the corpus's own `speaker-info.txt`, read from the
    official zip with HTTP range requests (`speaker_info.py`).
  - Tuning speakers: p225, p228, p229. Held out: p231, p232.
  - 250 `swap` and 250 `sub` probes.
  - Only `clips.tsv` is committed; the audio, passages and manifest are rebuilt.
- **Analysis and calibration** (`analyse.py`, `calibrate.py`):
  - false red / amber, probe detection, weak phonemes, the known label issues, timing;
  - a grid search over a simulation of the word-score step, checked against real Dart
    (99.6–99.8% colour agreement).
- **Teacher kit**:
  - `tools/eval/LABELLING.md`;
  - `tools/eval/labels/`: the learner manifest for L1–L5 x 50 sentences, `sentences.tsv`,
    `labels.template.csv` (2,220 words);
  - `agreement.py`: agreement, kappa, confusion, exits 1 below 80%, SKIPPED without
    labels.
- **Runner / CI**:
  - `tools/eval/run_harness.sh`: passages, native run plus the false-red gate (< 5%),
    learner run plus the agreement gate (≥ 80%). Each part skips when its inputs are
    missing.
  - `.github/workflows/eval.yml`: manual and weekly.
    - It fetches the full model only when `assets/models/manifest.json` lists a real URL.
    - It rebuilds or caches the VCTK audio.
    - Learner audio comes from the optional `EVAL_LEARNER_AUDIO_URL` variable (and the
      `EVAL_LEARNER_AUDIO_TOKEN` secret).
    - It uploads CSVs and summaries.
- **Calibration** (`lib/engine/scoring/config/scoring_config.dart`):
  - the curve is moved 2 nats more lenient (`a3Calibration` kept);
  - `wordMaxAboveWorst` 50 → 40, `droppedScore` 0 → 60, `intrusiveRScore` 45 → 80;
  - `defaultExtraAccepted` maps the model's en-us labels;
  - thresholds unchanged at 80 / 60.
  - Native false red: 28.6% → 3.6% (held-out 3.7%). Probe detection: 97.6% → 89.2%.

## How to use it

```bash
export PATH="$HOME/flutter/bin:$PATH"
python -m tools.eval.build_set build --shards <dir with VCTK shards 10,22,32,33>
EVAL_MODEL_DIR=/home/idawud/coach-models/release-full/full tools/eval/run_harness.sh
```

See `tools/eval/README.md` for single runs, custom configs and recalibration.

## Changes outside `tools/eval/` and `config/`

- `.github/workflows/eval.yml`: new (allowed for I2).
- `test/tools/eval/eval_harness_test.dart`: new Dart tests for the harness (8 tests).
  It is a new folder mirroring `tools/eval/`, which is the only place `flutter test`
  runs Dart tests.
- Tests in A3's folder that asserted A3's old config numbers. No test was removed;
  `test/engine/scoring` still has 91 tests and all pass.
  - `test/engine/scoring/config/scoring_config_test.dart`, "calibration is monotonic":
    `phonemeScore(0) == 50` became `phonemeScore(-2) == 50`, plus
    `a3Calibration(0) == 50`.
  - `test/engine/scoring/gop_pronunciation_scorer_test.dart`:
    - "a substituted phoneme lowers the word and reports heard" now uses
      `ScoringConfig(extraAccepted: {})`, which is A3's mapping. With the new
      ə→æ acceptance, the synthetic `æ` in "bath" is aligned into a neighbouring
      schwa. The word is still red, but heard attribution moves. Dropping ə→æ would
      cost +2.3 points of native false red.
    - "a dropped sound is heard as empty": `score == 0` became
      `score == config.droppedScore`.
    - "a separate r sound after a vowel is caught": `<= 45` became
      `<= config.intrusiveRScore`.
    - "stressed vowels weigh 1.5": uses `wordMaxAboveWorst: 100`, so the new tighter
      cap doesn't hide the weighting.
- No change to `phoneme_map.dart`. Everything goes through `extraAccepted`; the
  requests are in `docs/contract-requests/I2-eval.md`.

## Tests

- `pytest tools/eval`: 38 tests, 99% coverage of `tools/eval/`.
- `test/tools/eval`: 8 Dart tests.
- `ruff` is clean.
- `scripts/check.sh` passes: format, analyze, 336 Dart tests (6 skipped are A2's pre-existing skips), coverage gate (`lib/engine/` 98.1%), ruff, 118 pytest at 98.8% coverage of `tools/` (with `tools/models/requirements.txt` installed), content and licence checks.

## Known gaps

- **No teacher labels**, so the ≥ 80% word-agreement gate is not measured. The probes
  are only a proxy. The owner needs to record 5 learners and a teacher needs to label
  them (LABELLING.md).
- **Full tier only, x86 desktop.** Median RTF is 0.38 (about 8–10 s for a 25 s passage).
  There is no light model or phone measurement yet. Recalibrate when the light model
  exists: it is trained on RP labels, so most `extraAccepted` entries should go.
- What the calibration gives up: American LOT and r-coloured vowels are no longer
  flagged, and a lone dropped sound costs less (the `əl` artefact, contract request 1).
- About 7% of green native words still carry an r-coloured `heard` (contract request 3:
  show tips only on non-green words).
- Most of the remaining false red comes from Britfone citation forms (contract
  request 2: pronunciation variants and weak forms).
- Eval set limits:
  - VCTK studio audio, no VAD (speech segments are passed empty);
  - one male speaker;
  - Southern accents only;
  - native speakers not teacher-checked (a few "false reds" may be real slips).
- `eval.yml` was checked as YAML only, not run on GitHub. It skips until the full model is
  published and the learner audio and labels exist.
- A4's VCTK region list has two errors (p239 is SW England; p230 is Stockton-on-Tees).
  See contract request 5.
