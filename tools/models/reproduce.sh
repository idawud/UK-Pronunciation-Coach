#!/usr/bin/env bash
# Rebuild both model tiers from a clean machine. See docs/models.md.
#
#   tools/models/reproduce.sh full        # full tier: export + int8 + verify + PER (CPU, ~15 min)
#   tools/models/reproduce.sh light-smoke # light pipeline, tiny random model, real data (CPU, minutes)
#   tools/models/reproduce.sh light       # real light-tier fine-tune (needs a CUDA GPU)
#   tools/models/reproduce.sh light-cpu   # light tier WITHOUT a GPU: distil the full model (CPU, ~14 h)
#   tools/models/reproduce.sh release     # manifest.json + SHA256SUMS (dry run, no upload)
#
# Needs: Python 3.12, ~6 GB RAM for the full export, eSpeak NG on PATH (or ESPEAK_NG=...)
# for PER references and light-tier labels. Downloads: the full model (1.3 GB), VCTK
# Parquet shards (~0.5 GB each) and, for the light tier, wav2vec2-base (0.4 GB).
set -euo pipefail
cd "$(dirname "$0")/../.."

M=tools/models
PY="${PY:-.venv/bin/python}" # on a notebook GPU: PY=python SKIP_SETUP=1
STEPS="${STEPS:-20000}"

setup() {
  [[ -n "${SKIP_SETUP:-}" ]] && return 0
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

# Light tier without a GPU (docs/models.md, "Light tier without GPU"): the full model is the
# teacher; a 6-layer copy of it is trained on the teacher's cached per-frame posteriors.
# Resumable: re-run the same command after an interruption. HOURS caps training wall clock.
LIGHT_CPU_LAYERS="${LIGHT_CPU_LAYERS:-0,4,8,12,16,20}"
LIGHT_CPU_QUANT=(--quantise-conv --quant-exclude "${LIGHT_CPU_KEEP_FP32:-conv_layers.0/}")
light_cpu() {
  setup
  local W=$M/work/light-cpu D=$M/data/light-cpu T=$M/work/light-cpu/teacher
  [[ -f $T/pytorch_model.bin ]] || $PY -c "from huggingface_hub import snapshot_download as s; \
s('facebook/wav2vec2-lv-60-espeak-cv-ft', revision='ae45363bf3413b374fecd9dc8bc1df0e24c3b7f4', \
local_dir='$T', allow_patterns=['*.json', 'pytorch_model.bin'])"
  # held-out: A4's 60 clips (p225, p227, p228, p229); training never sees these or I2's
  # eval speakers (p231, p232). Train: every other speaker in shards 10/22/32/33, plus the
  # English-accent speakers of shards 11/12/24/31 and 16/20 (about 4.4 h after trimming).
  [[ -f $D/eval/manifest.tsv ]] || $PY -m tools.models.data --shards 10,22 \
    --speakers p225,p227,p228,p229 --per-speaker 15 --out $D/eval
  [[ -f $D/a/manifest.tsv ]] || $PY -m tools.models.data --shards 10,22,32,33 \
    --speakers p250,p299,p360,p318,p364,p279,p241,p292,p239,p376 --out $D/a
  [[ -f $D/b/manifest.tsv ]] || $PY -m tools.models.data --shards 11,12,24,31 \
    --speakers p243,p270,p279,p254,p268,p250,p273,p267,p274 --out $D/b
  [[ -f $D/c/manifest.tsv ]] || $PY -m tools.models.data --shards 16,20 \
    --speakers p244,p258,p257 --out $D/c
  for s in eval a b c; do
    $PY -m tools.models.distill prepare --teacher $T --manifest $D/$s/manifest.tsv \
      --cache $W/cache-$s
  done
  $PY -m tools.models.distill train --teacher $T --cache $W/cache-{a,b,c} \
    --eval-cache $W/cache-eval --out $W/student --keep-layers "$LIGHT_CPU_LAYERS" \
    --steps 1200 --hours "${HOURS:-10.5}" --max-frames 1600 --lr 2e-4 --warmup 50 \
    --eval-every 100 --ckpt-minutes 30
  $PY -m tools.models.export_onnx --model $W/student/hf "${LIGHT_CPU_QUANT[@]}" \
    --out $M/release/light --work $W
  $PY -m tools.models.evaluate --model $W/student/hf --release $M/release/light --work $W \
    --verify-clips $D/eval/manifest.tsv --eval-clips $D/eval/manifest.tsv --ref-voice en-us
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
  light-cpu) light_cpu ;;
  release) $PY -m tools.models.release --release-dir $M/release ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
