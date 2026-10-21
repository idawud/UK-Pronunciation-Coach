# assets/models (owner: A2-runtime, loader only)

Model files are downloaded, never committed (`*.onnx` is git-ignored), with one
exception: `silero_vad.onnx` (Silero VAD v6.2, MIT, 2.3 MB, SHA-256 `1a153a22…88e3`),
which A1's recorder loads from the bundle, is committed (I1). A4 publishes
them as GitHub Release assets; `manifest.json` here lists them with SHA-256
(format in `tools/ci/fetch_models.py`). Every model must be listed in docs/licences.md.

What the loader (`lib/engine/runtime/`) expects:

- one `*.onnx` and one `*.json` (Hugging Face `vocab.json`) entry per tier;
- light tier: `bundle: true` with **flat names** (e.g. `light_model.onnx`,
  `light_vocab.json`): only `assets/models/` is registered in `pubspec.yaml`, and
  Flutter does not bundle subfolders;
- full tier: `bundle: false`, downloaded to app support storage and stored under
  each file's base name.

`manifest.json` points at the published release `models-v1` of
idawud/UK-Pronunciation-Coach-models. Fetch the bundled light tier before a build:
`python3 tools/ci/fetch_models.py --tier light`.
