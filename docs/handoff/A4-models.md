# Handoff: A4-models

Model preparation tooling for the engine spike. Details, numbers and licences are in
`docs/models.md`; this is the short version.

## What was built

- `tools/models/` (Python, dev-side only): ONNX export (opset 17) + uint8 dynamic
  quantisation, verification against PyTorch, PER / size / CPU-time report, VCTK data
  prep, light-tier fine-tuning, SHA-256 manifest and a GitHub Release publisher (dry run
  by default), plus `reproduce.sh` for a clean machine. 53 pytest tests, about 98% coverage
  of `tools/models/`, no network or eSpeak needed in tests.
- **Full tier built locally** (not committed, not published):
  `tools/models/release/full/model.onnx` (355,431,615 B, sha256 `61335ed8…be26e93`) and
  `vocab.json` (392 tokens, blank `<pad>` = 0), plus `release/manifest.json` and `SHA256SUMS`.
  - fp32 ONNX matches PyTorch to 8e-4.
  - The quantised model agrees with PyTorch on 99.2% of frame argmaxes.
  - PER on 60 held-out VCTK clips (`en-us` references): 8.61% quantised vs 8.37% fp32.
  - 20 s of audio takes 5.6 s on 4 desktop threads.
- **Light tier**: the full pipeline is written and was run end to end on CPU with a tiny
  random model on real VCTK clips and real eSpeak labels:
  label → train → export → quantise → evaluate.
  The real `wav2vec2-base` load and training step were checked on CPU.
  Expected export size is 95.2 MB with uint8 MatMul+Conv quantisation.
  **The real GPU training run has not been done**; docs/models.md has the command and the cost estimate
  (about 1.5–3 h on one 24 GB GPU).

## How to use it

```bash
.venv/bin/pip install -r tools/requirements-dev.txt -r tools/models/requirements.txt
ESPEAK_NG=/path/to/espeak-ng tools/models/reproduce.sh full    # full tier + report
tools/models/reproduce.sh light-smoke                           # CPU proof of the light pipeline
STEPS=20000 tools/models/reproduce.sh light                     # GPU machine only
tools/models/reproduce.sh release                               # manifest, dry run
python -m tools.models.release --repo OWNER/REPO --publish      # human decision; not done
```

For A2: the graph is `input_values` float32 [1, samples] → `logits` [1, frames, vocab]. Apply
log-softmax yourself. There is no `attention_mask` input. After publishing, copy
`tools/models/release/manifest.json` to `assets/models/manifest.json`. Manifest names are flat:
`full-model.onnx`, `full-vocab.json`, `light-model.onnx`, `light-vocab.json`.

## A2-runtime format requests

| Request | Status |
| --- | --- |
| Use uint8 (QUInt8) weights | Done. The CPU ConvInteger kernel needs them. On the full model, uint8 MatMul-only also tracks fp32 slightly better than int8. Tests check that the weights are uint8 and that the file loads on ONNX Runtime's CPU EP. |
| I/O `input_values` → `logits` | Done. The optional `attention_mask` input is omitted. |
| HF vocab.json with `<pad>` = 0, 392 tokens (full) | Done. |
| One `.onnx` + one vocab per tier, flat names | Done (manifest `name` is flat; `path` is the release-folder location). |
| Full tier at about 318 MB like onnx-community `model_quantized.onnx` | Not followed. I kept the full tier at 355 MB (MatMul only, conv layers fp32). Quantising Conv too gives 317.7 MB, but argmax agreement drops from 99.2% to 96.5%, PER rises from 8.6% to 9.2%, and it runs slower on x86. Use `--quantise-conv` if size matters more. |

## Outside my folders

- `docs/licences.md` (ownership exception the coordinator allowed):
  - the full-model row now names its files;
  - the light-model row names its planned files and the VCTK attribution;
  - two dev-side rows were added (VCTK; the tools/models Python packages).

## Known gaps

- ~~The light model does not exist yet.~~ Superseded: a CPU-distilled light model now exists (see "Light tier
  without GPU" below). The wav2vec2-base GPU run is still not done.
- **Nothing is published.** The GitHub Release URL is a placeholder:
  `https://github.com/OWNER/REPO/releases/download/models-v1/<asset>`.
- **Small held-out set**: 60 clips from 4 speakers (3 Southern England F, 1 Cumbrian M).
  - The planned fifth speaker, p232 (Southern M, shard 33), was skipped to save bandwidth.
  - It is still in `EVAL_SPEAKERS`, so training excludes it.
- **The PER references are eSpeak output, not hand labels.**
  - `en-us` references fit the full model's training labels.
  - Against RP references, PER is 16.2%, mostly American vowel symbols. A3's mapping should treat `oʊ`≈`əʊ`,
    `ɚ`≈`ə`, and `ɑːɹ`≈`ɑː` as equivalent.
- **The VCTK accent list was typed from memory** of `speaker-info.txt`. All 33 IDs exist in the data, but the
  regions should be checked against the original zip before the real training run.
- **Phone speed**: CPU times are desktop x86 with other agents sharing the machine. The full tier is about
  7 s for a 25 s passage on 4 desktop threads, far from the 2.5 s phone target. A2/I2 should treat the full
  tier as slow and optional.
- **CI cost**: the `python` CI job now installs CPU torch, transformers and onnxruntime (about 1 GB). That should
  fit the 15-minute limit with pip caching, but I could not run it on GitHub.
- **Local eSpeak**: the eSpeak NG binary in `~/.local/root` needed libpulse. I extracted it into the session
  scratchpad and used a wrapper script; nothing was installed system-wide.

## Light tier without GPU (branch feat/a4-light-cpu, 2026-10-20)

**Built:** a CPU-only light tier. The full model was distilled into a 6-layer copy of itself, with no GPU and no hand
labels. Full details and numbers are in `docs/models.md`, section "Light tier without GPU".

- **Survey.** No shippable small model uses our eSpeak vocab.
  - The best alternative is Peacockery/hubert-base-phoneme-en (Apache-2.0, LibriSpeech). Its vocab is 39 ARPAbet
    phones, and its PER is 10.3% in ARPAbet space, against 7.1% for the full model.
  - ZIPA-small (CC-BY-4.0) needs an fbank front end.
  - The rest fail on licence or data.
- **Tool: `tools/models/distill.py`.**
  - `prepare` runs the teacher once and caches its conv features and log-posteriors as float16.
  - `init-check` compares layer choices before training.
  - `train` uses a KL loss, checkpoints every 30 min and resumes; the LR schedule follows the time budget.
  - `compare` measures agreement with the teacher.
  - Other changes: `export_onnx --quant-exclude`; an exact, about 40x faster 48→16 kHz resampler in `audio.py`; and
    `reproduce.sh light-cpu`, with `PY` and `SKIP_SETUP` overrides for notebooks.
- **Student:** teacher layers 0, 4, 8, 12, 16 and 20; 89.1 M parameters; the same 392-token vocab (byte-identical
  `light-vocab.json`).
  - Data: 6,040 VCTK clips (3.36 h). Held-out speakers and I2's eval speakers are excluded.
  - Time on an i5 laptop: teacher pass 4.4 h, training 7.4 h (1,200 steps).
- **Files** (not committed, not published), in `/home/idawud/coach-models/light-cpu/release/`:
  - `light/model.onnx` (89,664,247 B, uint8, Conv quantised except `conv_layers.0`) and `light/vocab.json`;
  - the full tier, hard-linked;
  - `manifest.json` and `SHA256SUMS` (dry run). `light-model.onnx` has sha256
    `ee06d16a7206fee53f760109c163b06ce3c3be0b4222bc7309aaca3a9a7fe61c`.
- **Quality, honestly: worse than the full tier.**

  | Measure | Light tier | Full tier |
  | --- | --- | --- |
  | PER, en-us references | 24.5% | 8.6% |
  | Frame argmax agreement with the full model | 89.1% | – |
  | I2 native false red | **7.1%** (fails the 5% gate) | 3.6% |
  | Substitution probes caught | 68% | 79% |
  | Word swaps caught | 99.6% | 99.6% |
  | 20 s of audio, 4 desktop threads | 2.0 s | 4.7 s |
  | 20 s of audio, 1 thread | 3.4 s | 8.5 s |

- **For A2:** after publishing, copy `manifest.json` to `assets/models/` and bundle `light-model.onnx` and
  `light-vocab.json`. I2's harness already loaded the file through `OnnxPhonemeRecognizer`.
- **For I2:**
  - Re-calibrate `ScoringConfig` for the light tier, or have it fall back to word-level colours only.
  - Do not make it the default tier until the false-red rate is under 5%.
- **Next step recommended:**
  - More distillation data and time: resume with set c plus LibriSpeech over 2–3 more nights.
  - Or run it, or the wav2vec2-base fine-tune, on a free Kaggle GPU (instructions in docs/models.md).
  - No long new run was started.
- **Outside my folders:** the light-model row and the VCTK row in `docs/licences.md`, under the same coordinator
  exception as before. The row still mentions wav2vec2-base, because U4's Licences page test checks for it.
  `docs/contract-requests/A4-models.md` asks U4 to update the page text.

