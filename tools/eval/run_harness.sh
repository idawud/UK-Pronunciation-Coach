#!/usr/bin/env bash
# I2-eval: runs the accuracy harness end to end and the go/no-go checks.
#
#   EVAL_MODEL_DIR=/path/to/full tools/eval/run_harness.sh
#
# 1. Builds passages.json + manifest.tsv for the native eval set (Britfone, fetched at a
#    pinned commit; eSpeak NG fallback only if ESPEAK_NG / espeak-ng is available).
# 2. Native set (tools/eval/data/evalset/wav, built by `build_set build`): real engine
#    via `flutter test tools/eval/dart/run_eval_test.dart`, then false-red / probe
#    metrics. Fails when native false red >= EVAL_MAX_RED (default 0.05).
# 3. Synthetic British-voice set (the default accuracy gate, labels known by
#    construction; see tools/eval/LABELLING.md): plan (text only), optional synthesis
#    (EVAL_SYNTH_BUILD=1; hours on CPU, needs the voices from
#    `python -m tools.eval.synth.build fetch`), harness, then agreement per split.
#    Fails when agreement on EVAL_SYNTH_GATE voices (default heldout) < 80%.
#    EVAL_SYNTH_PARTIAL=1 scores the fully rendered sentences of a partial build.
# 4. Optional learner set (tools/eval/data/learners/<speaker>/<passage>.wav) with
#    teacher labels (tools/eval/labels/labels.csv). Fails below 80%.
# Every step whose inputs are missing (model, audio, voices, labels) prints SKIPPED and
# passes. All gates run; the script exits 1 if any of them failed.
set -euo pipefail
cd "$(dirname "$0")/../.."

if ! command -v flutter >/dev/null 2>&1 && [[ -x "$HOME/flutter/bin/flutter" ]]; then
  export PATH="$HOME/flutter/bin:$PATH"
fi
if [[ -x .venv/bin/python ]]; then PY=.venv/bin/python; else PY=python3; fi

DATA=${EVAL_DATA_ROOT:-tools/eval/data}
SET=$DATA/evalset
SYN=$DATA/synth
OUT=${EVAL_OUT_ROOT:-tools/eval/work}
MODEL_DIR=${EVAL_MODEL_DIR:-}
LABELS=${EVAL_LABELS:-tools/eval/labels/labels.csv}
MAX_RED=${EVAL_MAX_RED:-0.05}
CACHE=${EVAL_CACHE:-$OUT/posteriors}
SYNTH_GATE=${EVAL_SYNTH_GATE:-heldout}
STATUS=0

step() { printf '\n==> %s\n' "$*"; }
gate() { "$@" || STATUS=1; }

step "passages + manifest (text only)"
"$PY" -m tools.eval.build_set passages --out "$SET"

have_model() { [[ -n "$MODEL_DIR" && -f "$MODEL_DIR/model.onnx" && -f "$MODEL_DIR/vocab.json" ]]; }

run_harness() { # manifest data_dir passages out_dir
  EVAL_MANIFEST="$1" EVAL_DATA="$2" EVAL_PASSAGES="$3" \
    EVAL_MODEL_DIR="$MODEL_DIR" EVAL_OUT="$4" EVAL_CACHE="$CACHE" \
    flutter test tools/eval/dart/run_eval_test.dart
}

step "native set: false red and controlled-error probes"
if ! have_model; then
  echo "SKIPPED: no model (set EVAL_MODEL_DIR to a folder with model.onnx + vocab.json)"
elif [[ ! -d "$SET/wav" ]]; then
  echo "SKIPPED: no native audio in $SET/wav (python -m tools.eval.build_set build --shards ...)"
else
  run_harness "$SET/manifest.tsv" "$SET" "$SET/passages.json" "$OUT/native"
  gate "$PY" -m tools.eval.analyse "$OUT/native" --json "$OUT/native/summary.json" \
    --max-red "$MAX_RED"
fi

step "synthetic British voices: word agreement (proxy go/no-go >= 80%)"
"$PY" -m tools.eval.synth.build plan --out "$SYN"
if [[ "${EVAL_SYNTH_BUILD:-0}" == "1" ]]; then
  "$PY" -m tools.eval.synth.build synth --out "$SYN" --workers "${EVAL_SYNTH_WORKERS:-4}" ||
    echo "SKIPPED: synthesis (voices missing? python -m tools.eval.synth.build fetch)"
fi
SYN_STATUS=$("$PY" -m tools.eval.synth.build status --out "$SYN")
echo "$SYN_STATUS"
if ! have_model; then
  echo "SKIPPED: synthetic harness (no model)"
elif ! grep -q 'still to render: 0$' <<<"$SYN_STATUS" && [[ "${EVAL_SYNTH_PARTIAL:-0}" != "1" ]]; then
  echo "SKIPPED: synthetic audio incomplete (EVAL_SYNTH_BUILD=1, restore the cache, or"
  echo "         EVAL_SYNTH_PARTIAL=1 to score only the fully rendered sentences)"
else
  "$PY" -m tools.eval.synth.build subset --out "$SYN"
  run_harness "$SYN/manifest.complete.tsv" "$SYN" "$SYN/passages.json" "$OUT/synth"
  gate "$PY" -m tools.eval.synth.report --labels "$SYN/labels.complete.csv" \
    --words "$OUT/synth/words_default.csv" --json "$OUT/synth/summary.json" \
    --gate "$SYNTH_GATE"
fi

step "learner set (optional): word agreement with teacher labels (>= 80%)"
if have_model && compgen -G "$DATA/learners/*/*.wav" >/dev/null; then
  run_harness tools/eval/labels/learner_manifest.tsv "$DATA" "$SET/passages.json" \
    "$OUT/learners"
else
  echo "SKIPPED: learner harness (needs the model and $DATA/learners/<speaker>/*.wav)"
fi
gate "$PY" -m tools.eval.agreement score --labels "$LABELS" \
  --words "$OUT/learners/words_default.csv" --json "$OUT/agreement.json"

exit "$STATUS"
