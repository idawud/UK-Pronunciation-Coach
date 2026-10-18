# assets/models (owner: A2-runtime, loader only)

Model files are downloaded, never committed (`*.onnx` is git-ignored). A4 publishes
them as GitHub Release assets; `manifest.json` here lists them with SHA-256
(format in `tools/ci/fetch_models.py`). Every model must be listed in docs/licences.md.
