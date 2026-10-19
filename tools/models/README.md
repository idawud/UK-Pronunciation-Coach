# tools/models (owner: A4-models)

Dev-side Python that builds the phoneme models A2 loads. Never shipped; never commit model
binaries (`release/`, `work/`, `data/` here are git-ignored). Full docs: `docs/models.md`.

| Module | Does |
| --- | --- |
| `export_onnx.py` | HF wav2vec2 CTC -> ONNX opset 17 (`input_values` -> `logits`) -> uint8 dynamic quantisation |
| `evaluate.py` | logits vs PyTorch on clips, PER (greedy CTC vs eSpeak references), size, CPU time |
| `train_light.py` | fine-tune wav2vec2-base on eSpeak RP labels (`--tiny` for CPU smoke runs) |
| `data.py` | VCTK (CC-BY-4.0) clips by speaker/accent -> 16 kHz WAV + manifest.tsv |
| `phonemes.py` | vocab helpers, eSpeak NG (binary) IPA labels, CTC decode, PER |
| `manifest.py`, `release.py` | SHA-256 manifest / SHA256SUMS; GitHub Release upload (dry run unless `--publish`) |
| `reproduce.sh` | `full`, `light-smoke`, `light` (GPU), `release` |

Setup: `.venv/bin/pip install -r tools/requirements-dev.txt -r tools/models/requirements.txt`
(CPU torch). Tests: `.venv/bin/python -m pytest tools/models --cov` (no network, no eSpeak).
Python deps go in `requirements.txt` here (licence-checked in CI).
