# Contract requests: C1-content

## Status (I1-integration, 2026-10-21)

1. `WordSpec.alternatives`: **done**. `BundledContentRepository` fills it from `alternatives.v1.json` (and Britfone variants for `lookup`); `GopPronunciationScorer` scores each word against its best-matching form. VCTK native false red (full tier): 3.6% -> 1.7% (held-out 3.7% -> 2.2%); probe detection unchanged. See `docs/handoff/integration.md`.

`BundledContentRepository` passes `runContentRepositoryContract` (`fullLibrary: true`)
unchanged. One optional change, from I2-eval's findings.

## 1. Alternative pronunciations on `WordSpec` (models, W0 / I1; scorer A3)

- **What:** add an optional field to `WordSpec`:

  ```dart
  /// Other accepted pronunciations of this word (weak/strong forms, Britfone variants,
  /// "-day" as /deɪ/, "ex-" as /ɛk/ ...). Empty when the word has only one.
  @Default(<List<PhonemeSpec>>[]) List<List<PhonemeSpec>> alternatives,
  ```

  and let `PronunciationScorer` score each word against `phonemes` and every
  alternative, keeping the best (or let the aligner pick the best path per word).
- **Why:** I2 measured that about 2 of the remaining 3.6 points of "native speaker
  marked red" come from correct forms that the expected pronunciation does not
  include: weak "from" /frəm/ and "are" /ə/ vs strong, smoothed "our" /ɑː/,
  "Thursday" /-deɪ/ vs /-di/, "expect" /ɛk-/ vs /ɪk-/. A passage can only carry one
  expected form per word today.
- **Data is ready:** the build already writes
  `assets/content/alternatives.v1.json` (`{"version": 1, "alternatives": {word:
  [pron, ...]}}`, preferred first, stress marks on vowels, the app's SSBE spelling) for
  the 179 passage words with more than one accepted form: all Britfone variants and
  weak forms, the pre-vowel forms of "the" / "to", `tools/content/extra_variants.tsv`
  (forms Britfone lacks: weak "from", smoothed "our" / "hour") and the "-day" / "ex-"
  rules. `assets/content/britfone.v1.tsv` also keeps every Britfone variant per word,
  so `lookup()` can fill the field for custom text. Once the field exists, C1 (or I1)
  only needs to put the alternatives into each `WordSpec` in `passages.v1.json` and in
  `BritfoneLexicon.lookup`; no other content change.
- **Affects:** `lib/core/models/word_spec.dart` (+ generated files), A3's aligner /
  scorer, C1's build and lookup. Backward compatible (defaults to empty).
