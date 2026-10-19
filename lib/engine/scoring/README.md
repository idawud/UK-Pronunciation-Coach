# lib/engine/scoring (owner: A3-scoring)

Pure-Dart `PronunciationScorer` (`GopPronunciationScorer`) and `Tips` (`TableTips`).
No Flutter imports (`test/engine/scoring/pure_dart_test.dart` enforces it), so it runs in
an isolate or a desktop CLI. Import `scoring.dart`.

| File | What |
| --- | --- |
| `data/phoneme_map.dart` | SSBE (Britfone-style) phoneme -> accepted model symbols; vowel and rhotic sets |
| `phoneme_mapper.dart` | `normalizeIpa`, `ModelVocab` (read from `PhonemePosteriors.vocab`), `PhonemeMapper` |
| `ctc_aligner.dart` | `alignCtc`: CTC Viterbi forced alignment with optional blanks, word skips, beam |
| `gop_pronunciation_scorer.dart` | GOP per phoneme, word scores, missed / extra / repeated words; `analyse()` returns details |
| `fluency.dart` | `computeFluency`: rate, pauses, continuity |
| `data/tips_table.dart`, `table_tips.dart` | 105 advice entries |
| `config/scoring_config.dart` | every tunable number (I2-eval owns `config/` from Wave 2) |

See `docs/handoff/A3-scoring.md` for the algorithm and known gaps.
