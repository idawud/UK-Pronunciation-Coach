# Contract requests: A4-models

## 1. Licences page: the light model is now distilled from the full model (for U4)

1. **Change:** in `lib/ui/settings/licence_data.dart`, update the `Light phoneme model (bundled)` entry's `source`.
   - Now: `'facebook/wav2vec2-base, fine-tuned for this app'`.
   - Proposed: `'facebook/wav2vec2-lv-60-espeak-cv-ft, reduced to 6 layers and distilled for this app'`.
   - Keep the VCTK note.

   In `test/ui/settings/licences_screen_test.dart`, drop `'wav2vec2-base'` from the list of sources
   that must appear. Once that lands, `docs/licences.md` can drop its "If the GPU route is used instead:
   facebook/wav2vec2-base" sentence. That sentence only stays now so that the cross-check passes.
2. **Why:** the bundled light model (`light-model.onnx`, branch `feat/a4-light-cpu`) is no longer a
   wav2vec2-base fine-tune. It is a 6-of-24-layer copy of facebook/wav2vec2-lv-60-espeak-cv-ft
   (Apache-2.0), trained on the full model's posteriors over VCTK audio (CC-BY-4.0). See
   `docs/models.md`, "Light tier without GPU". I may not edit `lib/ui/settings/`, so I am filing it here.
3. **Who it affects:** U4 (the Licences page and its test) only. There is no contract or model-type change.
