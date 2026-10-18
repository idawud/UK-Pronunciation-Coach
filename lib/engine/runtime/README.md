# lib/engine/runtime (owner: A2-runtime)

Implements `PhonemeRecognizer`: wav2vec2-style CTC phoneme model in ONNX on device,
light tier bundled, full tier downloaded once over Wi-Fi (progress, SHA-256, resume),
inference in a background isolate, `recommendedTier()`.

Model files: never commit them. `assets/models/manifest.json` lists release assets
(format in `tools/ci/fetch_models.py`); CI fetches and caches them by SHA-256.
Tests: `test/engine/runtime/`, `integration_test/A2-runtime/` running
`runPhonemeRecognizerContract` with `test/fixtures/audio/clean_read.wav`.
