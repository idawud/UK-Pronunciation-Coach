# Licences

Every model, dictionary, voice and font that ships in the app must be listed here with
its licence and source; the CI `licences` job fails if a file under `assets/models/`,
`assets/voices/` or a dictionary under `assets/content/` is not named on this page.
Only Apache-2.0, MIT, BSD or similarly permissive licences may ship. Never GPL / AGPL;
never BEEP or any research-only / non-commercial lexicon. U4's Licences page lists
everything in the "Shipped" table.

## Shipped in the app

| Component | File(s) | Licence | Source | Added by |
| --- | --- | --- | --- | --- |
| _Light phoneme model (planned: pipeline ready, GPU training run pending)_ | `light-model.onnx`, `light-vocab.json` | Apache-2.0 (base model); trained on CSTR VCTK Corpus, CC-BY-4.0, attribution: "Trained in part on the CSTR VCTK Corpus (University of Edinburgh), CC BY 4.0" | facebook/wav2vec2-base fine-tuned in-house (docs/models.md) | A4 / A2 |
| Full phoneme model, optional download | `full-model.onnx`, `full-vocab.json` | Apache-2.0 | facebook/wav2vec2-lv-60-espeak-cv-ft, re-exported to ONNX + uint8 quantised (docs/models.md) | A4 / A2 |
| _Silero VAD (planned)_ | _tbd by A1_ | MIT | snakers4/silero-vad via sherpa-onnx | A1 |
| _Britfone dictionary (planned)_ | _tbd by C1_ | MIT | Britfone | C1 |
| _Passages (planned)_ | `passages.v1.json` | original or public domain, see `assets/content/SOURCES.md` | in-house | C1 |
| _Piper en_GB voice (optional, off by default)_ | _tbd by C4_ | check the voice's own licence | Piper | C4 |
| Noto Sans Regular (IPA-capable UI font, family `NotoSansIPA`) | `assets/fonts/NotoSans-Regular.ttf` (licence text: `assets/fonts/NotoSans-OFL.txt`) | SIL Open Font License 1.1 | notofonts/latin-greek-cyrillic (Google Fonts / Noto Project), SHA-256 478c558e…3823 | U1 |

Replace each _planned_ row with the real file names when the component lands.
Dart packages are checked automatically from `pubspec.lock`.

## Dev-side only (never shipped)

| Tool | Licence | Used for |
| --- | --- | --- |
| eSpeak NG | GPL-3.0 | `tools/` only: IPA for words Britfone lacks (C1, flagged for review) and the speech in `test/fixtures/audio/` (W0). Called as a binary, never linked or bundled. |
| Roboto, Material Icons (test/fixtures/fonts) | Apache-2.0 | golden tests |
| DejaVu Sans (test/fixtures/fonts) | Bitstream Vera licence (permissive) | golden tests, IPA glyph fallback |
| pytest, pytest-cov, ruff, numpy | MIT / MIT / MIT / BSD-3-Clause | tools/ tests and scripts |
| CSTR VCTK Corpus 0.92 | CC-BY-4.0 | `tools/models/`: light-tier training data, held-out PER and logits checks (A4). Data never shipped; only trained weights. |
| torch, transformers, onnx, onnxruntime, safetensors, huggingface_hub, soundfile, pyarrow | BSD-3-Clause / Apache-2.0 / Apache-2.0 / MIT / Apache-2.0 / Apache-2.0 / BSD-3-Clause / Apache-2.0 | `tools/models/` export, quantisation, training (A4) |
