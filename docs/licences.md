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
| Britfone 3.0.1 British English dictionary (normalised to the app's SSBE spelling; also the source of the phonemes in the passages, minimal pairs and alternatives) | `assets/content/britfone.v1.tsv`, `assets/content/BRITFONE_LICENSE.txt`, `assets/content/alternatives.v1.json` | MIT, Copyright (c) 2017 Jose Llarena | [JoseLlarena/Britfone](https://github.com/JoseLlarena/Britfone) at `1062be1`; source copy in `tools/content/britfone/` | C1 |
| Passages (120 + 3 placement) and minimal pairs | `assets/content/passages.v1.json`, `assets/content/minimal_pairs.json` | Original writing for this app; 3 passages quote traditional public-domain tongue-twisters (see `assets/content/SOURCES.md`). Phonemes from Britfone (MIT); 93 words not in Britfone transcribed with eSpeak NG at build time and reviewed (`tools/content/review.md`) | in-house | C1 |
| Noto Sans Regular (IPA-capable UI font, family `NotoSansIPA`) | `assets/fonts/NotoSans-Regular.ttf` (licence text: `assets/fonts/NotoSans-OFL.txt`) | SIL Open Font License 1.1 | notofonts/latin-greek-cyrillic (Google Fonts / Noto Project), SHA-256 478c558e…3823 | U1 |
| _Piper en_GB voice (optional, off by default; not bundled yet)_ | _planned: `en_GB-cori-medium.onnx` + `.onnx.json` (63.5 MB), Release asset_ | weights MIT (rhasspy/piper-voices); training data public domain (LibriVox, Cori Samuel); trained from scratch, no restricted base checkpoint | rhasspy/piper-voices `en/en_GB/cori/medium`, by Bryce Beattie (brycebeattie.com/files/tts) | C4 |
| System text-to-speech voice | none (the phone's installed en-GB voice, used through flutter_tts, MIT) | platform | Android TextToSpeech / iOS AVSpeechSynthesizer | C4 |

Replace each _planned_ row with the real file names when the component lands.
Dart packages are checked automatically from `pubspec.lock`.

### Dart packages with an approved exception

The licence check reads MPL-2.0 as AGPL (the MPL text names the GNU Affero licence
as a possible "Secondary License"). These are allowed by name in
`tools/ci/licence_allowlist.txt`:

| Package | Licence | Pulled in by | Shipped? | Approved |
| --- | --- | --- | --- | --- |
| `dbus` 0.8.x | MPL-2.0 | `flutter_local_notifications_linux`, `connectivity_plus` (Linux implementation) | No: Linux desktop only; never compiled into the Android or iOS app | owner, 2026-10-20 |
| `nm` 0.6.x | MPL-2.0 | `connectivity_plus` (Linux implementation) | No: Linux desktop only | owner, 2026-10-20 |

Plug-ins added for reminders and the Wi-Fi check (all permissive):
`flutter_local_notifications` and its platform packages (BSD-3-Clause),
`timezone` (BSD-2-Clause, IANA tz data public domain), `flutter_timezone`
(Apache-2.0), `connectivity_plus` (BSD-3-Clause), and transitively `http`
(BSD-3-Clause), `xml` and `petitparser` (MIT).

## Dev-side only (never shipped)

| Tool | Licence | Used for |
| --- | --- | --- |
| eSpeak NG | GPL-3.0 | `tools/` only: IPA for words Britfone lacks (C1, flagged for review) and the speech in `test/fixtures/audio/` (W0). Called as a binary, never linked or bundled. |
| Roboto, Material Icons (test/fixtures/fonts) | Apache-2.0 | golden tests |
| DejaVu Sans (test/fixtures/fonts) | Bitstream Vera licence (permissive) | golden tests, IPA glyph fallback |
| pytest, pytest-cov, ruff, numpy | MIT / MIT / MIT / BSD-3-Clause | tools/ tests and scripts |
| CSTR VCTK Corpus 0.92 | CC-BY-4.0 | `tools/models/`: light-tier training data, held-out PER and logits checks (A4). Data never shipped; only trained weights. |
| torch, transformers, onnx, onnxruntime, safetensors, huggingface_hub, soundfile, pyarrow | BSD-3-Clause / Apache-2.0 / Apache-2.0 / MIT / Apache-2.0 / Apache-2.0 / BSD-3-Clause / Apache-2.0 | `tools/models/` export, quantisation, training (A4) |

## Piper en_GB voices reviewed (C4, 2026-10-19)

Checked each voice's MODEL_CARD in rhasspy/piper-voices, its dataset licence and the
licence of the checkpoint it was fine-tuned from (fine-tuning carries the base
model's training data into the weights). The repo's MIT tag covers the code and
packaging, not the training data. Mirrored in `lib/voice/piper/piper_voices.dart`.

| Voice | Dataset licence | Fine-tuned from | Verdict |
| --- | --- | --- | --- |
| cori (medium, high) | public domain (LibriVox) | none (from scratch) | **allowed** |
| alan (low) | mimic3 apope, "All Rights Reserved" | en_US ryan (RyanSpeech, CC BY-NC-SA 4.0) | not allowed |
| alan (medium) | mimic3 apope, "All Rights Reserved" | en_US lessac | not allowed |
| alba (medium) | CC BY 4.0 | en_US lessac | not allowed |
| aru (medium) | CC BY 4.0 | en_US lessac | not allowed |
| jenny_dioco (medium) | Jenny (Dioco): commercial use with attribution | en_US lessac | not allowed (a from-scratch Jenny by Bryce Beattie exists, but it is an Irish accent, not SSBE) |
| northern_english_male (medium) | CC BY-SA 4.0 (OpenSLR 83) | en_US lessac | not allowed (also not SSBE) |
| semaine (medium) | CC BY-NC-SA 4.0 | en_US lessac | not allowed |
| southern_english_female (low) | CC BY-SA 4.0 (OpenSLR 83) | en_US ryan (CC BY-NC-SA 4.0) | not allowed |
| vctk (medium) | CC BY 4.0 | en_US lessac | not allowed |

en_US lessac is trained on the Blizzard 2013 Lessac / Voice Factory data, whose
licence is "Research Purposes only" and explicitly excludes developing or selling
voice-synthesis products.

**Runtime constraint:** Piper voices expect eSpeak NG phonemes. sherpa-onnx's Piper
TTS builds and links eSpeak NG (GPL-3.0), so it cannot ship here (eSpeak NG is
allowed only in `tools/`). A Piper engine must phonemise without eSpeak (e.g.
Britfone IPA mapped onto the voice's `phoneme_id_map`) and run the `.onnx` on A2's
ONNX Runtime. See `docs/handoff/C4-voice.md`.
