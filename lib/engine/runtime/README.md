# lib/engine/runtime (owner: A2-runtime)

Implements `PhonemeRecognizer` (`OnnxPhonemeRecognizer.create()`): a wav2vec2-style CTC
phoneme model in ONNX, run with ONNX Runtime's C API in a background isolate. The
light tier is bundled; the full tier is downloaded once over Wi-Fi (with progress,
resume and SHA-256 check). `recommendedTier()` decides which tier a device gets.

| File | Role |
| --- | --- |
| `onnx_phoneme_recognizer.dart` | the `PhonemeRecognizer`; wires everything below |
| `inference_worker.dart` | long-lived isolate that owns the session: WAV -> normalise -> model -> log-softmax |
| `ctc_session.dart` | ORT C API via `onnxruntime_v2`'s FFI bindings (`input_values` [+ `attention_mask`] -> `logits`) |
| `audio_input.dart` | 16-bit WAV decode/encode, zero-mean / unit-variance normalisation |
| `model_vocab.dart` | `vocab.json`, blank detection, log-softmax, greedy decode (debug only) |
| `model_manifest.dart` | `assets/models/manifest.json` (format in `tools/ci/fetch_models.py`) |
| `model_files.dart` | light model: copied out of the asset bundle (or a directory in dev/tests) |
| `model_downloader.dart` | full-model download: `.part` resume, Wi-Fi wait, SHA-256, `verified.json` |
| `network.dart` | HTTPS transport (the only network use in the app), Wi-Fi check |
| `tier_advisor.dart` | light / full choice from RAM, OS and hardware, or a 5 s benchmark; cached |

Model files are never committed. Tests: `test/engine/runtime/` (the contract suite
runs against a tiny fixture model, and against the real dev model when it is cached
in `.model-cache/dev/`) and `integration_test/A2-runtime/`. See
`docs/handoff/A2-runtime.md`.
