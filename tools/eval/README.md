# tools/eval (owner: I2-eval)

The accuracy harness, eval set, calibration and teacher-agreement check for the scoring
engine. Results and the spike verdict are in `docs/eval-report.md`.

| File | What it does |
| --- | --- |
| `dart/run_eval_test.dart` | Harness entry point. Runs the **real** engine on the Linux host: A2's `OnnxPhonemeRecognizer`, then A3's `GopPronunciationScorer`. Writes `words_<config>.csv` and `clips_<config>.csv`. |
| `dart/eval_harness.dart` | Harness logic: manifest, posterior cache, scoring with N configs, CSV. Tests are in `test/tools/eval/`. |
| `lexicon.py` | Text to Britfone phonemes (MIT, pinned and SHA-checked), with a flagged eSpeak NG fallback (dev-side only). |
| `build_set.py` | Selects VCTK clips (`evalset/clips.tsv`), extracts the audio and writes passages, the manifest and the error probes. |
| `speaker_info.py` | Reads VCTK's `speaker-info.txt` from the official zip with HTTP range requests. |
| `analyse.py` | Native false-red / amber rates, probe detection, weak phonemes, the known label issues, timing. |
| `calibrate.py` | Calibration search: the probe config exposes the GOP; a simulation of the word-score rules matches Dart on 99.6% of words. |
| `agreement.py` | Teacher-label template and word agreement (go/no-go at 80%). |
| `run_harness.sh` | Runs everything end to end; `.github/workflows/eval.yml` calls it. |
| `LABELLING.md`, `labels/` | Teacher instructions, the learner manifest, the 50 sentences and the label template. |
| `evalset/` | Clip list, sources and licences, VCTK `speaker-info.txt`. |

## Quick start

```bash
export PATH="$HOME/flutter/bin:$PATH"
python -m tools.eval.build_set build --shards tools/eval/data/vctk   # needs 4 VCTK shards (see evalset/SOURCES.md)
EVAL_MODEL_DIR=/home/idawud/coach-models/release-full/full tools/eval/run_harness.sh
```

Or run one harness pass with your own configs:

```bash
EVAL_MANIFEST=tools/eval/data/evalset/manifest.tsv EVAL_DATA=tools/eval/data/evalset \
EVAL_PASSAGES=tools/eval/data/evalset/passages.json EVAL_MODEL_DIR=/path/to/full \
EVAL_OUT=tools/eval/work/run EVAL_CACHE=tools/eval/work/posteriors \
EVAL_CONFIGS="default,probe=tools/eval/work/probe.json" \
flutter test tools/eval/dart/run_eval_test.dart
python -m tools.eval.analyse tools/eval/work/run
```

- The harness is a `flutter test` file because the recognizer imports Flutter services.
  It sits outside `test/`, so `flutter test` and CI never pick it up by themselves.
- With the posterior cache, re-scoring 750 items with a new config takes about 10 s.
- `tools/eval/data/` (audio, Britfone, shards) and `tools/eval/work/` (runs) are
  git-ignored. Never commit model files or learner recordings.

## Recalibrating

```bash
python -m tools.eval.calibrate probe-config > tools/eval/work/probe.json   # add extraAccepted if needed
# harness with EVAL_CONFIGS=probe=tools/eval/work/probe.json, then:
python -m tools.eval.calibrate search tools/eval/work/run/words_probe.csv --out tools/eval/work/tuned.json \
    --extra tools/eval/work/extra.json --max-red 0.035
python -m tools.eval.calibrate check tools/eval/work/run/words_probe.csv tools/eval/work/tuned.json \
    tools/eval/work/tuned_run/words_tuned.csv     # simulation vs a real Dart run
```

Then copy the chosen numbers into `lib/engine/scoring/config/scoring_config.dart`.
