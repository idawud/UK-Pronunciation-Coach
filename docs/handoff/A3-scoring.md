# Handoff: A3-scoring

Pure-Dart alignment and pronunciation scoring in `lib/engine/scoring/`: a
`PronunciationScorer` (`GopPronunciationScorer`) and a `Tips` (`TableTips`). Both pass
the shared contract suites (`runPronunciationScorerContract(..., checkSemantics: true)`,
`runTipsContract`). No Flutter imports; no changes to `pubspec.yaml` or `lib/core/`.

## How to use

```dart
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

const scorer = GopPronunciationScorer();          // or (config: ScoringConfig.fromJson(json))
final result = scorer.score(passage, posteriors, speechSegments, attemptId: id, at: now);
final word = scorer.scoreWord(wordSpec, posteriors); // single-word retry
final detail = scorer.analyse(passage, posteriors, speechSegments); // + fluency breakdown, extras, alignment
const tips = TableTips();
tips.tipFor('θ', 't'); // "Put your tongue between your teeth and blow, ..."
```

I1 binds `pronunciationScorerProvider` to `GopPronunciationScorer()` and `tipsProvider` to
`TableTips()`. Scoring is synchronous; for long passages it can run in an isolate.

## Algorithm

1. **Phoneme mapping** (`data/phoneme_map.dart`, `phoneme_mapper.dart`). Each expected
   SSBE phoneme (stress marks stripped, `:` -> `ː`, tie bars removed) maps to a set of
   accepted model symbols, read against `PhonemePosteriors.vocab` (never hard-coded),
   e.g. `əʊ` -> {`əʊ`, `oʊ`}, `ə` -> {`ə`, `ɐ`, `ᵻ`, `əl`}, `ɹ` -> {`ɹ`, `r`},
   `ɪə` -> {`iə`} (the espeak vocab has no `ɪə`). Fallbacks when the vocab has none of
   them: a listed sequence (diphthong split `e ɪ`), then dropping the length mark, then
   per-character. r-coloured vowels (`ɚ`, `ɑːɹ`, ...) are deliberately not accepted.
   Tested against the real `facebook/wav2vec2-lv-60-espeak-cv-ft` vocab.json (392
   symbols, `<pad>` blank at 0, `<s>`, `</s>`, `<unk>` treated as special), copied into
   `test/engine/scoring/support/espeak_vocab.dart`: every Britfone phoneme is one unit.
   A2 should confirm the vocab it ships matches.
2. **Alignment** (`ctc_aligner.dart`). CTC Viterbi over the extended state sequence
   (blank, unit, blank, ...), optional blanks, blank required between identical units.
   Any word may be **skipped** at a log cost (`skipWordPenalty` 5): the path jumps from
   the blank before the word to the blank after it. Emission of a unit = max log-prob
   over its accepted symbols. Beam pruning (100 nats) on both ends of the live state
   window and windowed back-pointers keep it fast. Gives start/end frames per unit,
   hence per phoneme (a phoneme's span runs to the next phoneme's start) and per word.
3. **GOP** per phoneme: mean log-posterior of the expected symbols over the unit's
   frames minus the mean of the best competing symbol (competitors = the top 4 phones
   of each frame, excluding accepted symbols). Multi-unit phonemes average their units.
   The competitor is reported as `heard` when it beats the expected sound.
   Calibration: piecewise-linear curve in `config/` (GOP -6 -> 0, 0 -> 50, 2 -> 78,
   5 -> 95, 8 -> 100).
   - **Dropped sound**: if none of the phoneme's frames holds speech other than the
     neighbouring phonemes' sounds squeezed in by the forced alignment, `heard: ''`,
     score 0.
   - **Intrusive r**: a vowel followed (within 10 frames, up to the end of the next
     phoneme) by an `ɹ`/`r` or r-coloured spike gets `heard: '<vowel>ɹ'` and at most 45.
     Skipped when the next sound is a written r, or for linking r before a vowel-initial
     next word.
4. **Word score** = weighted mean of phoneme scores (primary-stressed vowels 1.5),
   **capped at worst phoneme + 50** (`wordMaxAboveWorst`; 100 disables). The cap is my
   addition: without it a word with one clearly wrong sound out of five ("Tursday",
   other sounds perfect) scored 82 and showed green. Status uses the config thresholds
   (80 / 60, same as `WordStatus` defaults).
5. **Missed words**: skipped by the aligner, or mean speech probability (1 - P(blank))
   over the word's unit frames < 0.3, or every phoneme dropped. Score 0, status missed.
   A scorable word none of whose phonemes map to the vocab is also reported missed.
6. **Extra / repeated words**: frames the alignment leaves in inter-word blank states are
   scanned for speech frames (1 - P(blank) >= 0.5), collapsed into phones. >= 2 phones
   is inserted speech; if its phones match a neighbouring word (LCS similarity >= 0.6)
   it is a repeat, otherwise ceil(phones / 4) extra words.
7. **Fluency** (`fluency.dart`) = 0.4 rate + 0.3 pauses + 0.3 continuity.
   - Rate: words said / span from first to last aligned word; 130-170 wpm scores 100,
     falling to 0 at 40 and 320 wpm. Not judged under 3 words.
   - Pauses: an inter-word gap >= 500 ms, or one containing a VAD silence (between
     `speech` segments) >= 250 ms. Each costs 8 + 10 per second beyond 0.5 s; pauses at
     punctuation are free up to 1.5 s.
   - Continuity: 100 - 250 x (missed + extra + repeated) / words.
   - Nothing said: fluency 0.
8. **Accuracy** = mean word score over scorable words (missed = 0);
   **overall** = round(0.7 accuracy + 0.3 fluency).

All numbers live in `config/scoring_config.dart` (`ScoringConfig`, JSON round-trip) for
I2. `extraAccepted` lets I2 widen the mapping (e.g. accept `ɑ` for `ɒ`) without editing
A3's table.

## Tips

`TableTips`: 105 entries (84 expected/heard substitutions, 8 dropped-sound tips, 12
general per-sound tips, 1 "In British English, don't sound the r here." rule for any
vowel heard with an r). Spellings are folded (`e`/`ɛ`, `ɛə`/`eə`, `r`/`ɹ`, `g`/`ɡ`,
`ɐ` -> `ə`, ...). Unknown dropped sounds get "Don't leave out the /x/ sound; say it
clearly."; other unknown pairs return null.

## Tests and results

`flutter test test/engine/scoring`: **92 tests pass**. Includes:
- both contract suites;
- synthetic posteriors over the real 392-symbol vocab (`support/synth.dart`): perfect
  read (dense frames and peaky 1-frame CTC spikes), substituted phonemes (heard `t`,
  `æ`), missed words (middle, first, last, consecutive, silence, zero frames, forced
  alignment through silence), dropped sound, long pause, free pause at a full stop, VAD
  silence pause, inserted word, repeated word, intrusive / linking / written r, stress
  weighting, config thresholds, unscorable and unmappable phonemes, `scoreWord`, tier;
- aligner, mapper, fluency, config and tips unit tests;
- **benchmark**: 200 words, 3,265 frames x 392 symbols, JIT under `flutter test` after
  3 warm-up runs: median 20.7 ms (min 14.6 ms) in the final `scripts/check.sh` run;
  up to 84.5 ms median while the machine was heavily loaded (load average ~10 on 8
  cores). AOT build: ~40-60 ms on the loaded machine. Gate: median < 100 ms.

Coverage of `lib/engine/scoring/`: **100% of lines** (625/625 in `lib/engine/`).
`scripts/check.sh` passes: format, analyze, 244 Dart tests, coverage gate, ruff + 30
pytest, content and licence checks. (Local setup note: this machine has no
`ensurepip`, so the worktree `.venv` was made with `python3 -m venv --without-pip` and
filled with another venv's pip via `pip --python .venv/bin/python install -r ...`.)

## Known gaps

- **Not validated on real model output.** All tests use synthetic posteriors. The
  calibration curve, skip penalty, missed / speech thresholds and the cap are guesses
  for I2 to tune on the engine-spike eval set.
- **en-us training labels.** The espeak model was trained with espeak phonemisation of
  Common Voice transcripts, probably en-us for English. It may emit `oʊ` for GOAT
  (accepted), `ɑː`/`ɑ` for LOT (not accepted: would flag every "hot"), `ɚ`/`ɑːɹ` for
  British non-rhotic vowels (flagged as an added r), `ɾ` for t. I2 should check these
  first and widen `extraAccepted` where native British speakers are flagged.
- **Ties in flat posteriors.** When expected sounds have equally bad emissions (two
  adjacent substitutions, dense synthetic frames), Viterbi tie-breaking decides the
  boundary, so `heard` can be attributed to the neighbouring phoneme. With dense (non
  peaky) frames, inserted speech next to a word can be absorbed into that word's last
  phoneme instead of counted as extra; with peaky CTC output (real wav2vec2) it lands
  between words as intended.
- Skipping a word needs one frame per skipped word; a badly said word may be skipped and
  its speech counted as extra (missed + extra) rather than scored low.
- Competitors are the top 4 phones per frame, not the full vocab (a speed trade-off;
  the best mean competitor is in practice among them).
- Pauses at sentence ends are free only when `WordSpec.offset` is set (passages from
  C1); custom text has no punctuation info.
- `ScoringAnalysis.extras` and the fluency breakdown are not part of `AttemptResult`
  (see `docs/contract-requests/A3-scoring.md`, optional).
- The test copy of the model vocab (`test/engine/scoring/support/espeak_vocab.dart`) is
  from the Apache-2.0 model repo and is test-only; nothing is shipped by A3, so
  `docs/licences.md` (W0-owned) needs no entry from A3. A2 records the model itself.
