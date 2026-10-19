#!/usr/bin/env bash
# Rebuild both model tiers from a clean machine. See docs/models.md.
#
#   tools/models/reproduce.sh full        # full tier: export + int8 + verify + PER (CPU, ~15 min)
#   tools/models/reproduce.sh light-smoke # light pipeline, tiny random model, real data (CPU, minutes)
#   tools/models/reproduce.sh light       # real light-tier fine-tune (needs a CUDA GPU)
#   tools/models/reproduce.sh release     # manifest.json + SHA256SUMS (dry run, no upload)
#
# Needs: Python 3.12, ~6 GB RAM for the full export, eSpeak NG on PATH (or ESPEAK_NG=...)
# for PER references and light-tier labels. Downloads: the full model (1.3 GB), VCTK
# Parquet shards (~0.5 GB each) and, for the light tier, wav2vec2-base (0.4 GB).
set -euo pipefail
cd "$(dirname "$0")/../.."

M=tools/models
PY=.venv/bin/python
STEPS="${STEPS:-20000}"

setup() {
  if [[ ! -x $PY ]]; then
    python3 -m venv .venv
  fi
  $PY -m pip install -q -r tools/requirements-dev.txt -r $M/requirements.txt
}

eval_data() {
  [[ -f $M/data/eval/manifest.tsv ]] ||
    $PY -m tools.models.data --speakers p225,p227,p228,p229,p232 --per-speaker 12 \
      --out $M/data/eval
}

full() {
  setup
  $PY -m tools.models.export_onnx --model facebook/wav2vec2-lv-60-espeak-cv-ft \
    --out $M/release/full --work $M/work/full
  eval_data
  $PY -m tools.models.evaluate --model facebook/wav2vec2-lv-60-espeak-cv-ft \
    --release $M/release/full --work $M/work/full \
    --verify-clips $M/data/eval/manifest.tsv --eval-clips $M/data/eval/manifest.tsv \
    --ref-voice en-us
}

light_train() { # $1 = train_light args, $2 = data args, $3 = data dir, $4 = work, $5 = release
  setup
  eval_data
  [[ -f $3/manifest.tsv ]] || $PY -m tools.models.data $2 --out "$3"
  $PY -m tools.models.train_light --train "$3/manifest.tsv" \
    --val $M/data/eval/manifest.tsv --full-vocab $M/release/full/vocab.json \
    --out "$4/hf" $1
  $PY -m tools.models.export_onnx --model "$4/hf" --quantise-conv --out "$5" --work "$4"
  $PY -m tools.models.evaluate --model "$4/hf" --release "$5" --work "$4" \
    --verify-clips $M/data/eval/manifest.tsv --eval-clips $M/data/eval/manifest.tsv \
    --ref-voice en-gb-x-rp
}

case "${1:-}" in
  full) full ;;
  light)
    light_train "--steps $STEPS --batch-size 16 --lr 1e-4 --warmup 1000 --fp16" \
      "--accent english --exclude-eval" $M/data/train $M/work/light $M/release/light
    ;;
  light-smoke)
    light_train "--tiny --steps 30 --batch-size 4 --lr 1e-3 --eval-every 15 --val-limit 10" \
      "--shards 10 --speakers p250 --per-speaker 40" $M/data/smoke \
      $M/work/light-smoke $M/work/light-smoke/release  # never in release/
    ;;
  release) $PY -m tools.models.release --release-dir $M/release ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac
