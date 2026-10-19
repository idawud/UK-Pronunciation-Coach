# Scoring accuracy: engine-spike report (I2-eval)

Date: 2026-10-19. Engine: the full-tier model (`full/model.onnx`, uint8,
sha256 `61335ed8…be26e93`, facebook/wav2vec2-lv-60-espeak-cv-ft) through A2's
`OnnxPhonemeRecognizer`, then A3's `GopPronunciationScorer`, run on the Linux host. There
is no light model yet. Everything below can be reproduced with `tools/eval/` (see its
README).

## Verdict

| Question | Answer |
| --- | --- |
| Does the engine leave native Southern British speech alone? | **Yes, after calibration.** 3.6% of native words are red (target < 5%). On the 2 held-out speakers it is 3.7%. Before calibration it was 28.6%. |
| Does it catch known errors? | **Mostly (proxy).** 99.6% of word swaps and 79% of single-phoneme substitutions come out red; 91% of substitutions are not green. |
| Does it agree with a teacher on learner speech (the ≥ 80% gate)? | **Unknown.** No teacher labels exist yet. The template, instructions and script are ready. |
| Is it fast enough? | **Not with the full tier on this CPU.** The median real-time factor is 0.38, so a 25 s passage takes roughly 8–10 s on 4 x86 threads. Real phones and the light tier still need measuring. |

**Recommendation: conditional GO for the engine spike.** The scoring pipeline works on real
speech, and a calibration exists that keeps native speakers out of red. It also still
flags most controlled errors. The **release** go/no-go still depends on 3 things:

1. The teacher agreement run, with 5 learners x 50 sentences (≥ 80% word agreement).
   This is the real gate, and nothing here replaces it.
2. Pronunciation variants and weak forms in the content and scorer (contract request 2).
   Without them, about 2 points of the remaining false red come from correct native
   forms. I expect learners to hit them even more often.
3. Speed. The full tier needs a phone measurement (I1). Otherwise the light tier
   (A4's GPU run) becomes the default, and it must then be re-calibrated with this
   harness.

Starting Wave 1 screens is reasonable, provided the teacher labels are collected in
parallel. If agreement falls short of 80%, the likely fixes are calibration and lexicon
work (`tools/eval/calibrate.py`), not changes to the screens.

## Method

### Harness

`tools/eval/dart/run_eval_test.dart`, a `flutter test` entry point, because the
recognizer imports Flutter services. For each WAV, the real recognizer produces
log-posteriors, which are optionally cached by WAV hash + model. Then each manifest item
is scored with one or more `ScoringConfig`s. The harness writes per-word CSV rows (status,
score, expected phonemes, stress, heard per phoneme, phoneme scores) and per-clip rows
(accuracy, fluency, frames, audio/model/scoring times).

- Speech segments are passed empty. The VCTK clips are already silence-trimmed, and A1's
  VAD is not in this spike.
- Missed words follow the scorer's own rules.

### Eval set

250 native clips: 5 Southern England VCTK speakers x 50 sentences (CC-BY-4.0). Accents
were checked against the corpus's own `speaker-info.txt`. Details are in
`tools/eval/evalset/SOURCES.md`.

- Tuning speakers: p225, p228, p229 (F).
- Held-out speakers: p231 (F), p232 (M). p232 is the only male, and it is held out.
- 2,135 scorable words.
- Expected phonemes come from Britfone 3.0.1 (MIT): first variant, plus derived
  plurals. The set needed no eSpeak fallback.

### Controlled-error probes (a proxy)

For every clip, two altered expectations are scored against the **unaltered native
audio**:

- **swap** (250): one content word replaced by a clearly different word
  ("these" → "book");
- **sub** (250): one phoneme of one word replaced by a typical learner error
  (θ→t, ð→d, v→w, w→v, ɪ→iː, æ→ɛ, ʃ→s, z→s, ɹ→l, l→ɹ, p↔b, ...).

"Detected" means the target word comes out red. This measures whether the engine notices
that the expected and spoken sounds differ. That is necessary for agreeing with a teacher
but not enough: real learner errors are often partial, accented sounds rather than clean
substitutions. **This is not teacher agreement.**

### Calibration procedure

1. The harness runs with a *probe* config: a linear GOP curve from -10 → 0 to
   10 → 100, with no intrusive-r cap. Each phoneme score then encodes its GOP to 0.2 nats.
2. `tools/eval/calibrate.py` re-implements only the final word-score step (curve, stress
   weight, word cap, dropped / intrusive-r scores, thresholds). It grid-searches 1,296
   configs on the 3 tuning speakers, then a finer 162-config grid with the
   intrusive-r score fixed at 80. The objective is maximum probe detection with native
   false red ≤ 3.5%, and less amber on ties.
   - Simulation and real Dart agree on 99.6–99.8% of word colours.
3. The model-label issues are handled with `extraAccepted`. That needs re-alignment, so
   each variant was a real Dart run.
4. The chosen config was then run for real on all 5 speakers. The held-out numbers below
   come from that real run, and they match the built-in defaults byte for byte.

## Results

### Native speakers (false red = `fix` + `missed`)

| Config | Split | Words | Red | Amber | Green |
| --- | --- | --- | --- | --- | --- |
| A3 defaults (before) | all | 2,135 | 28.6% | 16.1% | 55.3% |
| | tune | 1,298 | 29.0% | 15.8% | 55.2% |
| | **held-out** | 837 | **28.1%** | 16.5% | 55.4% |
| + `extraAccepted` only | all / tune / held-out | | 13.5% / 12.7% / 14.8% | 11.1% | 75.3% |
| **I2 calibration (after, now the default)** | all | 2,135 | **3.6%** | 3.8% | 92.6% |
| | tune | 1,298 | 3.5% | 2.9% | 93.6% |
| | **held-out** | 837 | **3.7%** | 5.3% | 91.0% |

- Per speaker after calibration: p225 4.1%, p228 3.3%, p229 3.1%, p231 4.2%, p232 3.2%.
- Content words: 3.4% red. Function words: 3.7% red.
- Missed: 0.5% of words (10).

### Controlled-error probes (target word red)

| Config | swap | sub | sub not green | both |
| --- | --- | --- | --- | --- |
| A3 defaults (before) | 100% | 95.2% | 100% | 97.6% |
| I2 calibration, all | 99.6% | 78.8% | 90.8% | 89.2% |
| I2 calibration, tune | 99.3% | 78.7% | 88.0% | 89.0% |
| I2 calibration, **held-out** | 100% | 79.0% | 95.0% | 89.5% |
| Calibration *without* `extraAccepted` (simulated, tune / held-out) | 99.3% / 100% | 50% / 47% | | 75% / 74% |

The last row shows why the phoneme-mapping fix matters. Calibration alone can also reach
< 5% false red, but only by making the whole curve lenient, which lets half of the
single-sound errors through.

Detection per substitution after calibration (n in brackets):

- **100%:** θ→t (3), ð→d (21), v→w (8), w→v (27).
- **90–93%:** ɪ→iː (28), ɹ→l (22).
- **70–82%:** l→ɹ (31), b→p (17), ɒ→əʊ (9), eɪ→ɛ (13), ɐ→ɒ (14), p→b (7).
- **50–67%:** iː→ɪ (9), æ→ɛ (7), z→s (20).
- **Weak:**
  - ʃ→s: 20% (5);
  - ʊ→uː: 0% (2);
  - ɜː→ɑː: 0% (7). With NURSE accepting `ɚ` and LOT accepting `ɑː`, NURSE and START
    vowels before a written r both reach the model as r-coloured tokens.

Voicing (z→s, p↔b) and vowel length (iː↔ɪ) are the weak classes. Teachers often treat these
as minor too.

### Per-phoneme weak spots (native words, share of phonemes scoring < 60)

| Phoneme | Before | After | Main confusion (what the model heard) |
| --- | --- | --- | --- |
| ɛə (SQUARE) | 100% | 0% | `ɛ` (en-us labels, plus modern SSBE [ɛː]) |
| ɐ (STRUT) | 97% | 0% | `ʌ`: the table had no `ʌ` for Britfone's `ɐ` |
| ɪə (NEAR) | 100% | 24% | `ɪ`, `ɪɹ`; after: `ə` |
| ɔː (THOUGHT) | 87% | 0% | `ɔːɹ` (r-coloured, spelled r) 42 times, `oʊ` 13 |
| ɑː (START/BATH) | 79% | 18% | `ɑːɹ`; after: `æ` in BATH words ("ask"), the American vowel |
| ɒ (LOT) | 75% | 14% | `ɑː` 34 (A3's "hot" issue); after: `ʌ` in weak "from", "what", "want" |
| ɜː (NURSE) | 52% | 0% | `ɚ` |
| ə | 52% | 4% | `ɚ` 108, `ʌ` 105 ("of", "was"), `æ` 90 ("that", "and", "at"), dropped 81 |
| ʊ | 53% | 15% | weak forms of "could", "should" |
| l | 20% | 0% | dropped 60 (the `əl` token, contract request 1) |
| t | 20% | 0.4% | heard as flap `ɾ` 75 / 494 before; accepted after |

A3's predicted American-label issues were all confirmed:

- the "hot" short o heard as `ɑː`: 34 / 109 LOT vowels;
- r-coloured vowels flagged as an added r: 88 words before;
- flapped t: 75 / 494 t's.

What causes the remaining 76 false-red words:

- weak forms and variants: "from", "are", "our" (smoothing), "-day" as /deɪ/, "ex-" as
  /ɛk/;
- 10 missed words;
- a few BATH vowels heard as American /æ/.

These point to lexicon variants (contract request 2) rather than to the acoustic model.

### Timing (full tier, this machine)

| Measure (250 native clips, mean 2.3 s, max 7.5 s, no cache) | Value |
| --- | --- |
| Model time per clip: min / median / p90 / max | 316 / 750 / 1,529 / 4,512 ms |
| `recognise()` end to end, median | 757 ms (model + ~8 ms) |
| Real-time factor (model / audio): min / median / p90 | 0.27 / 0.38 / 0.52 |
| Scoring per item, median | 1.3 ms |

- 8-CPU x86-64 WSL2 laptop, 4 ORT threads, other agents sharing the machine.
- `model` is the ONNX inference alone; `recognise` adds WAV decode, normalisation and the
  isolate hop.
- Scoring (alignment + GOP + fluency) takes a median of about 1 ms per sentence, so it
  is negligible.
- These are desktop numbers. A 60-word passage (~25 s) at the measured median real-time
  factor would take 8–10 s on this CPU (A2 measured 7–8 s for a 20 s clip). That misses the 2.5 s phone target
  for the full tier, which agrees with A2's and A4's measurements. Phones must be
  measured by I1.

## Calibration changes (`lib/engine/scoring/config/scoring_config.dart`)

| Setting | A3 initial | I2 spike | Why |
| --- | --- | --- | --- |
| `calibration` (GOP → score) | (-6,0) (-3,10) (-1,30) (0,50) (1,65) (2,78) (3,86) (5,95) (8,100) | the same curve 2 nats more lenient: (-6.8,0) (-4.4,10) (-2.8,30) (-2,50) (-1.2,65) (-0.4,78) (0.4,86) (2,95) (4.4,100) | real GOPs for correct native sounds sit lower than the synthetic guess (kept as `ScoringConfig.a3Calibration`) |
| `wordMaxAboveWorst` | 50 | **40** | with the lenient curve, a tighter cap keeps a word with one clearly wrong sound red |
| `droppedScore` | 0 | **60** | 2/3 of "dropped" sounds on native speech were the `əl` artefact or normal elision |
| `intrusiveRScore` | 45 | **80** | the model can't tell a British vowel from an r-coloured one before a written r |
| `extraAccepted` | {} | ɐ→ʌ; ə→ʌ ɚ æ; ɒ→ɑː ɑ; ɜː→ɚ ɝ ɜ; ɛə→ɛ ɛː ɛɹ; ɪə→ɪɹ ɪ ɪː; ɔː→ɔːɹ oːɹ; ɑː→ɑːɹ; ʊə→ʊɹ ɔː ɔːɹ; t→ɾ | the full-tier model writes en-us labels for British speech |
| thresholds | 80 / 60 | 80 / 60 (unchanged) | they match the UI colour rules; the curve does the tuning |

Other settings (skip penalty, missed / speech thresholds, fluency) are unchanged. They had
no visible problems on this set (0.5% missed). Fluency isn't checked against labels.

Trade-offs to keep in mind:

- An American LOT vowel ("hot" as /hɑt/) and an r-coloured vowel are no longer flagged.
  This model can't separate them from native British speech.
- Some STRUT/schwa (ʌ vs ə) and TRAP/schwa contrasts are not judged in unstressed
  syllables.
- A dropped sound alone now costs less.

**Re-tune when the light model arrives**: it is trained on RP labels, so most
`extraAccepted` entries should become unnecessary.

## What is known vs what still needs labels

**Known now:**

- The real pipeline works end to end on real British speech.
- The en-us label bias is the dominant error source, and it is fixed by the mapping.
- Native false red is 3.6%, and 3.7% on held-out speakers.
- Clean controlled errors are caught 89% of the time.
- Scoring time is negligible; model time is the bottleneck.

**Needs teacher labels** (`tools/eval/LABELLING.md`; 5 learners x 50 sentences, 2,220
words):

- word agreement (the ≥ 80% gate);
- false red on words a teacher accepts in *learner* speech;
- recall of real learner errors, including partial or accented sounds;
- re-calibration against labels;
- the amber band's meaning.

Native speakers have also not been teacher-labelled, so a few "false reds" here may be
real slips. The labels template can cover them too.

**Not covered:**

- the light tier (doesn't exist yet);
- phones;
- A1's VAD and real microphone audio (VCTK is studio-quality);
- fluency scoring;
- male speakers: only one;
- non-Southern native accents.

## Reproduce

```bash
python -m tools.eval.build_set build --shards tools/eval/data/vctk   # 4 shards, see SOURCES.md
EVAL_MODEL_DIR=/home/idawud/coach-models/release-full/full tools/eval/run_harness.sh
```

`.github/workflows/eval.yml` (manual and weekly) runs the same steps. It skips cleanly until
the full model is published in `assets/models/manifest.json`, the learner audio is
configured and `tools/eval/labels/labels.csv` exists.
