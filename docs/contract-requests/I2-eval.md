# Contract / ownership requests from I2-eval

Found during the engine spike (see docs/eval-report.md). I changed only my own
folders (`tools/eval/`, `lib/engine/scoring/config/`, `docs/eval-report.md`,
`.github/workflows/eval.yml`) plus four tests in `test/engine/scoring/` that asserted
A3's old config numbers. The test changes are listed in docs/handoff/I2-eval.md.

## 1. A3 (`gop_pronunciation_scorer.dart`): `ə l` / `əl` is scored as a dropped sound

**Problem.** The model has a single token `əl`. In `data/phoneme_map.dart`, both `ə` and
`l` accept it. When a word ends in Britfone's `ə l` ("people", "beautiful", "miracle",
"physical", "universal") and the model emits one `əl` token, `_hasOwnSpeech` sees only
a symbol that the neighbouring unit also accepts. One of the two phonemes is then
reported as dropped (`heard: ''`).

- On the native set, before calibration, 81 schwas and 60 l's were "dropped" this way.
  They were the third-largest source of false red.
- My calibration works around it with `droppedScore: 60`. That also means a real
  dropped sound now costs less.

**Request.** In `_hasOwnSpeech`, count a frame as the phoneme's own speech when the
phoneme's unit accepts the frame's symbol, even if a neighbour accepts it too. (The
alternative, removing `əl` from one of the two entries, loses the single-token match.)
After that fix, `droppedScore` could go back towards 0–40. Re-run
`tools/eval/run_harness.sh` to check.

## 2. C1 (passage content) and A3: pronunciation variants and weak forms

**Problem.** Britfone's first variant is a citation form. Native Southern speakers reading
aloud use other forms that are just as correct, and these cause most of the false red that
remains (about 2 of the 3.6 points):

| Pattern | Example words | What natives said |
| --- | --- | --- |
| weak forms (Britfone strong form) | from, are, could, should, at, a | /frəm/, /ə/, /kəd/ |
| `-day` | Wednesday, yesterday | /deɪ/ (Britfone variant 1 is /i/) |
| `ex-`, `in-` | explained, expected, influence | /ɛk-/, /ɪn-/ vs /ɛn-/ |
| smoothing | our, hour | /ɑː/ (heard `ɑːɹ` by the model) |

**Request (C1).** Keep all Britfone variants for each word in the bundle (`THURSDAY(1)`,
`THURSDAY(2)`). Add weak forms for about 40 function words.

**Request (contract, W0/A3).** `WordSpec` gains optional
`alternatives: List<List<PhonemeSpec>>`. The scorer aligns each word against every
variant and keeps the best. CTC alignment supports this through a word-level choice
between unit sequences.

Until then, I2 can only accept extra symbols per phoneme (`extraAccepted`), which is too
blunt for weak forms. Accepting `ə` for `ɒ` everywhere would hide real LOT-vowel errors.

## 3. U3 / I1: r-coloured vowels on green words

The full-tier model labels many British vowels before a written r with American
r-coloured tokens (`ɔːɹ` for "store", `ɑːɹ` for "are"). This happened in 57% of
`ɔː` vowels on native speech. The model cannot tell a sounded r from a silent one here.

- I set `intrusiveRScore` to 80, so the flag no longer turns native words red.
- The phoneme still comes back with `heard: 'ɔːɹ'`. Then 152 of 2,135 native words (7%)
  are green but carry a "don't sound the r" phoneme.

**Request (U3).** Show phoneme tips only for words that are not green. Otherwise the r tip
appears on correct native speech. Revisit when A4's light model (trained on RP labels)
exists.

## 4. W0 (`docs/licences.md`): dev-side rows for the eval set

Please add these dev-side rows (nothing is shipped):

- **CSTR VCTK Corpus 0.92**, CC-BY-4.0: also used by `tools/eval/` as the native eval set
  (250 clips, 5 speakers, never shipped).
- **Britfone 3.0.1**, MIT: used dev-side by `tools/eval/lexicon.py` (pinned commit
  `1062be1`, downloaded, not committed). The existing "Britfone (planned)" row is C1's
  shipped copy.
- **Kokoro-82M v1.0** (hexgrad, ONNX export by onnx-community), Apache-2.0: 8 British
  voices used by `tools/eval/synth/` to read the synthetic eval set. Never shipped.
- **Piper en_GB-cori-medium / -high**, MIT, public-domain LibriVox data: same use.
  Details, pinned revisions and SHA-256 are in `tools/eval/SOURCES.md`.

The eSpeak NG row already covers `tools/` use. `tools/eval` uses it only as a flagged
fallback, and the current eval set needs none.

## 5. A4 (`tools/models/data.py`): two VCTK regions are wrong

I read the corpus's own `speaker-info.txt` from the official zip
(`python -m tools.eval.speaker_info`; a copy is in `tools/eval/evalset/speaker-info.txt`)
and compared it with `VCTK_ENGLISH`. The other 31 entries match, and no "English"
speaker is missing. Two regions differ:

| Speaker | `VCTK_ENGLISH` | speaker-info.txt | Effect |
| --- | --- | --- | --- |
| p239 | SE England | **SW England** | wrongly in the `southern` accent group |
| p230 | Stockport | **Stockton-on-tees** | label only (both Northern) |
