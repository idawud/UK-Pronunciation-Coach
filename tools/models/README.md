# tools/models (owner: A4-models)

Python model preparation: ONNX export + int8 quantisation of the full tier, light tier
fine-tune, PER / size / CPU-time report, SHA-256 manifest, GitHub Release upload.
Never commit model binaries. Tests: `tools/models/tests/` (pytest, 80% gate).
Add Python deps to `tools/models/requirements.txt` (licence-checked in CI).
