# Handoff: C1-content

Passage content, the British dictionary and `ContentRepository`.

## What was built

| Item | Where |
| --- | --- |
| 120 original passages (20 per level) + 3 placement passages (levels 1, 3, 5) | sources: `tools/content/passages/level1-6.txt`, `placement.txt`; bundle: `assets/content/passages.v1.json` |
| 81 minimal pairs over 20 contrasts (vowels ɪ-iː, ʊ-uː, æ-ʌ, æ-ɛ, ɒ-ɔː, ʌ-ɑː, ɜː-ɑː, ɜː-ɔː, ɛ-eɪ; consonants θ-t, θ-s, θ-f, ð-d, v-w, b-v, l-ɹ, s-ʃ, ʃ-tʃ, n-ŋ, s-z) | `tools/content/minimal_pairs.txt` -> `assets/content/minimal_pairs.json` |
| Britfone 3.0.1 (MIT) source + licence | `tools/content/britfone/` (pinned to commit `1062be1`) |
| Runtime dictionary for `lookup()` (16k words, all variants, preferred first) + licence | `assets/content/britfone.v1.tsv`, `assets/content/BRITFONE_LICENSE.txt` |
| Alternative pronunciations per passage word (I2 request) | `assets/content/alternatives.v1.json` |
| Build script (Python, stdlib only) | `tools/content/build.py`, `lexicon.py`, `espeak.py` |
| Preferred-variant table, extra forms, reviewed eSpeak overrides | `tools/content/variants.tsv`, `extra_variants.tsv`, `lexicon_overrides.tsv` |
| Review report (flagged words, coverage, near-duplicate check) | `tools/content/review.md` |
| Passage sources | `assets/content/SOURCES.md` (generated) |
| `BundledContentRepository` + `BritfoneLexicon` | `lib/data/content/` |

Bundle format: `{"version": 1, "passages": [...], "placement": [...]}`; each passage
matches the `Passage` model with `offset` set on every word (stress 0 omitted). Word
counts per level (min-max, mean): L1 8-12 (10), L2 25-30 (27), L3 52-60 (56),
L4 85-94 (90), L5 137-149 (143), L6 189-207 (199). Every word in every passage is
scorable. Topics follow the SPEC table (everyday phrases; routines; stories and emails;
news and workplace; opinion and presentations; literary prose, tongue-twisters and
IELTS-style essays / long turns).

## How to use

```dart
final repo = BundledContentRepository();          // reads assets via rootBundle
await repo.byLevel(3); await repo.placementPassages();
await repo.lookup('Paste any text here');         // Britfone + rules, offline
```

I1: bind `contentRepositoryProvider` to `BundledContentRepository()` in
`lib/core/providers.dart`.

Rebuild content (dev):

```bash
python -m tools.content.build            # from committed inputs (what CI runs)
python -m tools.content.build --check    # fail if outputs are stale / hand-edited
ESPEAK_NG=/path/espeak-ng python -m tools.content.build --espeak
    # new words Britfone lacks -> eSpeak NG en-gb-x-rp -> lexicon_overrides.tsv (reviewed=no)
```

Locally eSpeak is in `~/.local/root`; it needs a wrapper that sets
`LD_LIBRARY_PATH=$L:$L/pulseaudio` and `--path=$L` (L = `~/.local/root/usr/lib/x86_64-linux-gnu`).

## Pronunciation rules (Python build and Dart lookup implement the same)

- Britfone symbols normalised to the spelling A3's map and tips use: `ɐ`->`ʌ`,
  `g`->`ɡ`, `ɛə`->`eə` (`ɛ`, `i` for happY, `ɹ` kept). A Dart test checks every passage
  phoneme is a key of A3's `ssbePhonemeMap`.
- Variant 1 of Britfone unless `variants.tsv` says otherwise (you, your, him,
  have/has/had, that, isn't strong; use/close/separate as verbs; contact, contract,
  content, survey(s), subjects, transport as nouns; just, sometimes).
- Weak-form words (first variant unstressed) take their strong form before clause
  punctuation or at the end of the text; "the" -> /ði/, "to" -> /tʊ/ before a vowel.
- Words Britfone lacks: regular -s/'s/-es/-ies, -ed, -ing and contractions (I'm,
  we'll, they're, ...) derived from Britfone; then the overrides file.
- Heteronyms that depend on meaning (lives, wind, tear, produce...) were reworded out of
  the passages rather than guessed.
- A Dart test runs `lookup(passage.text)` on all 123 passages and checks it matches the
  built phonemes for every word the runtime table covers (>10,000 words).

## Coverage and review

- 10,717 word tokens: 10,355 from Britfone (96.6%), 253 derived, 109 from overrides
  (93 distinct words), 0 unscorable.
- **93 words flagged for human review** (eSpeak NG en-gb-x-rp output, all `reviewed=no`
  in `tools/content/lexicon_overrides.tsv`, listed with their passages in
  `tools/content/review.md`). I checked them and corrected 8 (happiest, encyclopaedias,
  inconvenience, fortieth, Priya, Imran, receptionist, Mrs); final unstressed ɪ is
  written `i` (Britfone's happY). Correct in the TSV, set `reviewed` to `yes`, rebuild.
- Near-duplicate check: no same-level pair shares more than 50% of content words
  (the build fails otherwise).

## Tests

- `test/data/content/`: `runContentRepositoryContract(fullLibrary: true)`, asset-bundle
  loading, caching, placement separation, lookup unit tests, Python/Dart cross-check.
  `lib/data/content/` line coverage is reported by the gate (100% locally).
- `test/content/passage_bundle_test.dart`: 20 per level, ids, lengths, offsets and
  indexes, phonemes for every word, phoneme inventory, stress only on vowels, one
  primary stress per word, sentence splitting, minimal pairs one sound apart and grouped,
  SOURCES.md and licence present.
- `tools/content/tests/` (pytest): tokenising, Britfone loading/normalising, variants,
  derivations, context rules, eSpeak conversion and flagging (fake runner), build
  validation errors, `--check`/`--espeak`. 99% coverage of `tools/content/`.

## Edits outside my folders

- `.github/workflows/ci.yml`, **content job only** (exception granted): schema check now
  runs with `--require`, and a new step runs `python -m tools.content.build` then
  `git diff --exit-code -- assets/content tools/content/review.md`. CI never calls eSpeak.
- `docs/licences.md`: replaced the planned Britfone and Passages rows with the real ones.
- `pubspec.yaml`: **no change needed** (`assets/content/` was already registered; no new
  dependencies).
- `test/content/placeholder_test.dart`, `test/data/content/placeholder_test.dart`,
  `tools/content/tests/test_placeholder.py` (W0 seeds for my folders) removed.

## Licences

- Britfone 3.0.1, MIT, Copyright (c) 2017 Jose Llarena: shipped
  (`britfone.v1.tsv`, `BRITFONE_LICENSE.txt`, and the phonemes in the passage, pair and
  alternatives files). Row added to `docs/licences.md`.
- eSpeak NG (GPL-3.0): dev-side only, called as a binary by `tools/content/espeak.py`
  under `--espeak`; already in the dev-side table. Its reviewed outputs for 93 words are
  data in `lexicon_overrides.tsv` / the passages; not in the runtime table.
- Passages: original writing; l6-002, l6-007, l6-016 quote traditional public-domain
  tongue-twisters ("Betty Botter", "red lorry, yellow lorry", "Peter Piper"), noted in
  `SOURCES.md`. No BEEP or other non-commercial lexicon is used.

## Contract requests

`docs/contract-requests/C1-content.md`: optional `WordSpec.alternatives` so the scorer
can accept weak/strong and other correct variants (I2 found ~2 of 3.6 points of native
false red come from these). The data is already built (`alternatives.v1.json`).

## Known gaps

- The 93 eSpeak words still need a human pass (marked `no`).
- Weak forms are chosen by rule (clause end -> strong), not by meaning; e.g. a stressed
  "can" mid-sentence still expects /kən/. `alternatives.v1.json` holds the other forms
  for when the contract allows several.
- `lookup()` for custom text has no eSpeak fallback (by design): words outside Britfone
  and the regular inflection/contraction rules are unscorable, including the 93
  override words.
- The tokeniser is ASCII letters plus apostrophes (same as the fake): accented words
  ("café") and digits are not words; passages avoid them, custom text loses them.
- Sound tags: declared focus + the most over-represented learner-hard phonemes (by
  frequency vs the whole library) + the level's feature tags (`short-vowels`,
  `word-endings`, `long-vowels`, `non-rhotic`, `weak-forms`, `word-stress`, `linking`,
  `rhythm`, `sentence-stress`, `intonation`, `connected-speech`). C3 should treat
  non-IPA tags as features, not sounds.
