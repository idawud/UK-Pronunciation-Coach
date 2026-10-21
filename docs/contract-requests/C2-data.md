# Contract requests: C2-data

## Status (I1-integration, 2026-10-21)

1. and 2. **Done** as documentation: `ProgressRepository.saveAttempt` and `updateWordResult` doc comments now say both. No code change.

Nothing blocking: `DriftProgressRepository` passes the frozen `ProgressRepository`
suite unchanged. Two clarifications for the post-Wave-1 review:

1. **`saveAttempt` with an existing id.** The doc says it "saves (or replaces, by id)" and
   "folds every scored phoneme into the sound stats". An EMA cannot be un-folded, so
   re-saving the same attempt folds its phonemes a second time (the fake does the same).
   Proposal: document "replacing an attempt folds its phonemes again; callers should save
   each attempt once and use `updateWordResult` for retries". No code change.
2. **Review items enqueued by `updateWordResult` have empty `phonemes`.** `WordResult`
   carries expected IPA but not stress, so the repository cannot build `PhonemeSpec`s
   faithfully. Fix a word then needs a `ContentRepository.lookup`. Proposal: document
   this, or have C3 (which knows the passage) upsert the item with phonemes after the
   retry. No signature change.

No native configuration is needed in `android/` or `ios/` (see docs/handoff/C2-data.md).
