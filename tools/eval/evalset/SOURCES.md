# Eval set sources and licences

## Native British speech: CSTR VCTK Corpus 0.92

- Yamagishi, Veaux and MacDonald, University of Edinburgh. **CC-BY-4.0.**
  Attribution: "CSTR VCTK Corpus (University of Edinburgh), CC BY 4.0".
  Original: <https://datashare.ed.ac.uk/handle/10283/3443>.
- Audio comes from the silence-trimmed Parquet mirror `jspaulsen/vctk` at revision
  `fb74847570d78d2b23e83193d8e55df80e6271b2` (CC-BY-4.0; Silero VAD trim plus 25 ms
  padding). This is the mirror A4 uses. We keep `mic1` only and resample to 16 kHz mono.
  The shards are `data/train-000{10,22,32,33}-of-00034.parquet`.
- Clips: `clips.tsv`, 250 sentences (50 per speaker).
  - The 10 VCTK elicitation sentences that all five speakers read and that Britfone fully
    covers (e.g. "Ask her to bring these things with her from the store.").
  - 40 more per speaker, picked at random (seed 20261019) from that speaker's
    newspaper sentences of 4–20 words that Britfone fully covers. No eSpeak fallback was
    needed for any word in the set.
- Speakers, checked against the corpus's own `speaker-info.txt`. We read that file
  from the official zip with HTTP range requests (`python -m tools.eval.speaker_info`).
  A copy is in this folder.

  | Speaker | Age | Sex | Region (speaker-info.txt) | Split | Held out of A4's light-tier training |
  | --- | --- | --- | --- | --- | --- |
  | p225 | 23 | F | Southern England | tune | yes |
  | p228 | 22 | F | Southern England | tune | yes |
  | p229 | 23 | F | Southern England | tune | yes |
  | p231 | 23 | F | Southern England | held out | no (no light model trained yet) |
  | p232 | 23 | M | Southern England | held out | yes |

- Every clip is read from one script. Speakers may still make small reading slips,
  so a few "false red" words could be real misreadings.
- Note for A4: `speaker-info.txt` lists **p239 as "SW England"**. `VCTK_ENGLISH` in
  `tools/models/data.py` has "SE England" (and "Stockport" for p230, which the file gives
  as "Stockton-on-tees"). See docs/contract-requests/I2-eval.md.

## Expected pronunciations: Britfone 3.0.1

- Jose Llarena, **MIT**. Pinned commit `1062be14adc96c358f2087ac5449d72130c7a6f4` of
  <https://github.com/JoseLlarena/Britfone>, SHA-256 checked (`tools/eval/lexicon.py`),
  downloaded into the git-ignored `tools/eval/data/britfone/`.
- First variant of each word. Plurals and possessives that Britfone lacks are derived
  from the stem (`britfone+s`).
- eSpeak NG `en-gb-x-rp` (GPL-3.0, run as a binary, dev-side only) is the flagged
  fallback for words Britfone lacks. The current set doesn't use it. BEEP is never used.

## Controlled-error probes

These are generated, not recorded (`build_set.py`). For each clip:

- `swap`: one content word of the expected text is replaced by a different word (with
  at least half its phonemes different) taken from the set's own vocabulary.
- `sub`: one phoneme of one word's expected pronunciation is replaced by a typical
  learner error (`θ->t`, `ð->d`, `v->w`, `ɪ->iː`, `æ->ɛ`, ...).

The audio is the correct native reading in both cases. The probes therefore check whether
the engine notices a mismatch between the expected and the spoken sounds. They are a
**proxy**, not agreement with a teacher on real learner speech.
