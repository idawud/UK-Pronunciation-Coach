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
# 3. Learner set (tools/eval/data/learners/<speaker>/<passage>.wav, see LABELLING.md):
#    harness + word agreement with tools/eval/labels/labels.csv. Fails below 80%.
# Every step whose inputs are missing (model, audio, labels) prints SKIPPED and passes.
set -euo pipefail
cd "$(dirname "$0")/../.."

if ! command -v flutter >/dev/null 2>&1 && [[ -x "$HOME/flutter/bin/flutter" ]]; then
  export PATH="$HOME/flutter/bin:$PATH"
fi
if [[ -x .venv/bin/python ]]; then PY=.venv/bin/python; else PY=python3; fi

DATA=${EVAL_DATA_ROOT:-tools/eval/data}
SET=$DATA/evalset
OUT=${EVAL_OUT_ROOT:-tools/eval/work}
MODEL_DIR=${EVAL_MODEL_DIR:-}
LABELS=${EVAL_LABELS:-tools/eval/labels/labels.csv}
MAX_RED=${EVAL_MAX_RED:-0.05}
CACHE=${EVAL_CACHE:-$OUT/posteriors}

step() { printf '\n==> %s\n' "$*"; }

step "passages + manifest (text only)"
"$PY" -m tools.eval.build_set passages --out "$SET"

have_model() { [[ -n "$MODEL_DIR" && -f "$MODEL_DIR/model.onnx" && -f "$MODEL_DIR/vocab.json" ]]; }

run_harness() { # manifest data_dir out_dir
  EVAL_MANIFEST="$1" EVAL_DATA="$2" EVAL_PASSAGES="$SET/passages.json" \
    EVAL_MODEL_DIR="$MODEL_DIR" EVAL_OUT="$3" EVAL_CACHE="$CACHE" \
    flutter test tools/eval/dart/run_eval_test.dart
}

step "native set: false red and controlled-error probes"
if ! have_model; then
  echo "SKIPPED: no model (set EVAL_MODEL_DIR to a folder with model.onnx + vocab.json)"
elif [[ ! -d "$SET/wav" ]]; then
  echo "SKIPPED: no native audio in $SET/wav (python -m tools.eval.build_set build --shards ...)"
else
  run_harness "$SET/manifest.tsv" "$SET" "$OUT/native"
  "$PY" -m tools.eval.analyse "$OUT/native" --json "$OUT/native/summary.json" --max-red "$MAX_RED"
fi

step "learner set: word agreement with teacher labels (go/no-go >= 80%)"
if have_model && compgen -G "$DATA/learners/*/*.wav" >/dev/null; then
  run_harness tools/eval/labels/learner_manifest.tsv "$DATA" "$OUT/learners"
else
  echo "SKIPPED: learner harness (needs the model and $DATA/learners/<speaker>/*.wav)"
fi
"$PY" -m tools.eval.agreement score --labels "$LABELS" --words "$OUT/learners/words_default.csv" \
  --json "$OUT/agreement.json"
