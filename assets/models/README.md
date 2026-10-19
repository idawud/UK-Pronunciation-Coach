# assets/models (owner: A2-runtime, loader only)

Model files are downloaded, never committed (`*.onnx` is git-ignored). A4 publishes
them as GitHub Release assets; `manifest.json` here lists them with SHA-256
(format in `tools/ci/fetch_models.py`). Every model must be listed in docs/licences.md.

What the loader (`lib/engine/runtime/`) expects:

- one `*.onnx` and one `*.json` (Hugging Face `vocab.json`) entry per tier;
- light tier: `bundle: true` with **flat names** (e.g. `light_model.onnx`,
  `light_vocab.json`): only `assets/models/` is registered in `pubspec.yaml`, and
  Flutter does not bundle subfolders;
- full tier: `bundle: false`, downloaded to app support storage and stored under
  each file's base name.

Until A4 publishes, there is no `manifest.json`. The app then has no light model, and
`fullModelSizeBytes` reports the dev model's size.
