# Word labels: right / wrong

The go/no-go test for the scoring engine is **word agreement of at least 80%** with a
right / wrong label per word. There are two ways to get those labels.

## Default: synthetic labels (no teacher needed)

British-accent TTS voices read the eval sentences from **phonemes**, once as written and
once with 1-3 injected learner errors (θ->t, v->w, ɪ->iː, an added r, a dropped final
consonant, h-dropping, moved stress, ...). Each word's label is known by construction:
a word with an injected error is `wrong`, every other word is `right`. No listening is
needed, and the labels are rebuilt from committed text, so they never drift.

```bash
python -m tools.eval.synth.build fetch          # voices, pinned + SHA-256 (tools/eval/SOURCES.md)
python -m tools.eval.synth.build plan           # passages, manifest, labels.csv (text only)
python -m tools.eval.synth.build synth --workers 4   # audio, resumable (hours on CPU)
EVAL_MODEL_DIR=/path/to/full tools/eval/run_harness.sh
# or just the comparison, from an existing harness run:
python -m tools.eval.synth.report --labels tools/eval/data/synth/labels.csv \
    --words tools/eval/work/synth/words_default.csv
```

`tools/eval/data/synth/labels.csv` has the same columns as the teacher sheet below
(`teacher` = `synthetic`, `notes` = what was injected, e.g. `0:θ->t`), plus `error`
(the error type), `voice`, `split` (`tune` / `heldout` voices), `read` (`clean` /
`error`) and `aug` (speed, noise, reverb, phone band). `agreement.py score` reads it as
it is. The gate (`synth.report`, exit 1 below 80%) uses the **held-out voices** by
default, because the tuning voices may have been used to calibrate.

**This is a proxy, not a teacher.** TTS voices are not learners: the errors are clean
phoneme substitutions in an otherwise native voice, with no accent, hesitation or
in-between sounds, and the voice may not realise every injected sound exactly. Expect
it to be optimistic. See "Synthetic British-voice evaluation" in docs/eval-report.md.

## Optional: teacher labels

A British-English teacher labelling real learner recordings is still the better test.
Use it when it becomes possible; the same 80% gate applies (`run_harness.sh` runs both).

### What you get

- `tools/eval/labels/sentences.tsv`: the 50 sentences the learners read aloud (VCTK
  elicitation and newspaper sentences).
- Recordings: 5 learners x 50 sentences, as
  `tools/eval/data/learners/<learner>/<passage>.wav` (16 kHz mono WAV; the owner
  supplies them, see "For the owner" below).
- `tools/eval/labels/labels.template.csv`: one row per scorable word, 2,220 rows
  (5 learners x 444 words).

### What to do

1. Copy `labels.template.csv` to `labels.csv` (same folder).
2. Listen to each recording. For each word, fill in the `label` column:
   - `right`: the word sounds acceptable in Standard Southern British English (SSBE).
     A trained listener would not correct it.
   - `wrong`: you would ask the learner to fix this word. That includes a wrong sound
     (`think` said as "tink"), a sound left out or added, the wrong stressed syllable,
     or an American sound where SSBE differs (an r after a vowel in "car", the "hot"
     vowel said like "hart" or "hut").
   - If the learner left the word out, mark it `wrong`.
3. Judge the word, not the whole sentence: rhythm, speed and intonation don't count.
   Normal connected-speech forms are `right`: weak forms ("of" as /əv/, "to" as /tə/),
   linking r ("far away"), a glottal stop for t, and elision ("nex(t) week").
4. Optional columns: `teacher` (your initials) and `notes` (what was wrong, e.g.
   `θ->t`). Notes help us find out why the engine disagreed.
5. If you're not sure, choose what you would do in a lesson. Leave `label` blank only
   if you can't hear the word at all (noise, cut-off). Blank rows are not counted.

Allowed values: `right` / `wrong` (also `r`, `w`, `ok`, `x`, `1`, `0`).

It takes about 2–3 hours for the 250 recordings. If two teachers label the same file,
save the copies as `labels.<initials>.csv`. Their agreement with each other tells us the
best agreement we can expect from the engine.

### Scoring (for the developer)

```bash
# run the engine on the learner recordings, then compare with the labels
EVAL_MODEL_DIR=/path/to/full tools/eval/run_harness.sh
# or just the comparison, from an existing harness run
python -m tools.eval.agreement score --labels tools/eval/labels/labels.csv \
    --words tools/eval/work/learners/words_default.csv
```

The engine counts a word as "wrong" when it's red (`fix` or `missed`). Amber counts as
right (`--amber wrong` to change that). The script prints the agreement, Cohen's kappa,
how many right words the engine marked red, and how many wrong words it caught. It exits
with 1 below 80% (NO-GO). `eval.yml` runs the same check every week.

To recalibrate against the labels once they exist, run the harness with the probe config
(`python -m tools.eval.calibrate probe-config`). Then search on a subset of the learners
and keep one or two learners out to check the result. See docs/eval-report.md.

### For the owner: recording the learners

- Pick 5 adult learners with a range of first languages and levels (e.g. 2
  intermediate, 2 upper-intermediate, 1 advanced). Get their written consent to keep and
  share the recordings with the teacher, for testing only.
- Each learner reads the 50 sentences in `sentences.tsv` once, in a quiet room, with a
  phone held 20–30 cm away. Save one WAV per sentence as
  `<learner>/<passage>.wav`, where learner is `L1`–`L5` and passage is the
  `passage` column (e.g. `L1/p225_002.wav`). Mono, 16 kHz, 16-bit (convert with
  `ffmpeg -i in.m4a -ac 1 -ar 16000 -sample_fmt s16 out.wav`).
- Trim long silences at the start and end. Leave pauses inside the sentence as they are.
- Do not commit the recordings to git. They are personal data. Keep them on a private
  drive and give CI a private zip URL (`EVAL_LEARNER_AUDIO_URL`, plus
  `EVAL_LEARNER_AUDIO_TOKEN` if needed). Commit `labels.csv`: it holds no audio or
  names.
