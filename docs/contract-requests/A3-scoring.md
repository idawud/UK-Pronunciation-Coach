# Contract requests: A3-scoring

No change is required: `GopPronunciationScorer` and `TableTips` pass the shared
`PronunciationScorer` and `Tips` suites unchanged.

Optional, for a later wave (nothing blocks on these):

1. **Fluency detail in `AttemptResult`.** Results could explain the fluency score
   (speaking rate, pauses, extra / repeated words). Today only the 0-100 number reaches
   the UI; `GopPronunciationScorer.analyse()` already returns a `FluencyBreakdown` and
   the inserted speech (`ExtraSpeech`). Proposal: an optional
   `FluencyDetail? fluencyDetail` on `AttemptResult` (wpm, pause count, extra count,
   repeat count). Affects C2 (storage), U3 (results), the fake and the suite.
2. **Performance note for model owners (no contract change).** freezed wraps
   `PhonemePosteriors.frames` in an unmodifiable list view; per-element access through
   it is slow in hot loops, so the scorer copies the outer list once. Producers (A2)
   need not do anything.
