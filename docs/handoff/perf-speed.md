# Handoff: perf-speed (stop-to-Results latency)

Branch `feat/perf-speed`. Goal: shorten the time from "stop recording" to Results.

## What was built

1. **Live (incremental) recognition.** While the user reads, the recorder's VAD
   probabilities pick pauses (`engine/runtime/chunk_planner.dart`); each completed piece
   (plus 160 ms of audio context on each side) goes to the model in the background
   (`live_recognition_session.dart`). On stop only the tail is recognised, the per-piece
   frames are joined (cuts are on 20 ms frame boundaries, so the joined posteriors have
   exactly the whole clip's frame count), and the scorer runs as before. A tail that is
   just a pause is filled with the last frame instead of running the model.
   Any problem (audio does not match the clip, a piece failed or was skipped, the tier
   changed during the recording) falls back to `recognise(clip)` on the whole clip.
   - New optional contracts in `lib/core/contracts/live_recognition.dart`
     (`LiveAudioSource`, `IncrementalPhonemeRecognizer`, `LiveRecognition`). Additive;
     see `docs/contract-requests/perf-speed.md`. `CoachAudioRecorder` (A1's folder,
     about 20 lines) publishes `liveAudio`; `OnnxPhonemeRecognizer` implements the rest.
   - `ScoringController` starts a session before `recorder.start()`, feeds it, finishes
     it in `_score`, and drops it on cancel, discard, retry, error, too-quiet clips and
     dispose. `--dart-define=LIVE_SCORING=false` turns it off.
2. **Feeding only speech.** Pieces are cut in pauses and silent tails are not run; leading
   and inter-piece silence only appears as context. (A pause longer than the context
   inside a piece is still run; pieces never skip a pause in the middle.)
3. **ONNX Runtime options.** Threads = big/performance cores, 1..4 (`cpu_cores.dart`:
   cpufreq on Android/Linux, `hw.perflevel0.physicalcpu` on Apple). Graph optimisation was
   already `ENABLE_ALL`. `execution_providers.dart` + `OrtCtcModelSession.open`:
   `--dart-define=ORT_ACCELERATOR=xnnpack|nnapi|coreml|cpu`; used only if requested, the
   platform can have it and the library lists it; any failure falls back to CPU.
   `ORT_THREADS=n` overrides the thread count. Default stays CPU: both models are
   dynamically quantised (`MatMulInteger`/`ConvInteger`), which XNNPACK/NNAPI/Core ML do
   not run, so they would take few nodes and add copies. **Not measured**: the host
   library only has the CPU provider; the provider code paths run only on a phone.
4. **Model variants.** Not done. Both shipped models are already uint8 dynamic-quantised;
   a different export could not be checked here against the >= 97% frame-agreement rule
   within this task, and the live path made it unnecessary for the latency goal.
5. **Preload.** Verified and tested: `ScoringController._load` calls `_prepareModel`
   as soon as the passage is loaded, so the model loads when the Read screen opens
   (test `the model is loaded as soon as the screen has opened`).

## Results (this desktop, 8 logical cores, shared; 24.8 s / 60-word clip, Silero VAD live)

Stop-to-result = from `recorder.stop()` to the scorer's result. Best of N, spread in
brackets. Load average was 3-12 during runs, so spreads are wide.

| Tier | Threads | Whole clip (before), N=3 | Live, stop right after last word (tail 2.7 s), N=5 | Live, 1.1 s of silence at the end (tail filled), N=3 |
| --- | --- | --- | --- | --- |
| light | 4 | 6.96 s (6.96-7.10) | 0.61 s (0.61-1.12) | 0.14 s (0.14-1.02) |
| light | 1 | 19.2 s (19.2-28.3) | 1.23 s (1.23-3.08) | 2.2 s (2.2-5.7) |
| full | 4 | 10.8 s (10.8-27.1) | 0.76 s (0.76-0.90) | 0.06 s (0.06-0.77) |
| full | 1 | 15.8 s (15.8-27.3) | 1.04 s (1.04-3.05) | 6.4 s (6.4-20.8) |

The last column at 1 thread shows the limit: when real-time factor is near or above 1
(1 thread, loaded machine) the background work cannot keep up with the speech and a
backlog is left at stop. At 4 threads RTF is about 0.25-0.4 (light), 0.4 (full).
CPU time: total CPU of a live run is 1.3-2x that of a whole-clip run (the 160 ms
contexts and a busier machine), but almost all of it happens during the recording
(cpu after stop: 0.2-4 s versus 20-30 s for the whole clip). Raw JSON lines come from
the benchmark below.

Earlier desktop numbers quoted in the task (8.2-9.0 s light, 11.4-13.5 s full, 4 threads)
match the whole-clip column.

### Equivalence (live vs whole-clip scoring)

36 synthetic long passages (7 TTS sentences joined with 0.3-0.9 s pauses, ~64 words,
10 voices, clean and error reads; `PERF_EQUIV_*`), 2304 words per tier, 4 threads:

| Tier | Frame argmax agreement | Word status agreement | Mean abs word diff | Max word diff | Words not green: whole -> live |
| --- | --- | --- | --- | --- | --- |
| full | 96.6% | 90.6% | 4.4 | 100 | 13.6% -> 10.0% |
| light | 94.5% | 66.2% | 15.1 | 100 | 54.2% -> 41.7% |

On the 25 s fixture (l3-013, one clip): max word diff 19-21 (full), 80-83 (light);
overall score 94 vs 94 (full), 89 vs 90 (light).

Honest reading: live scoring is not identical. wav2vec2 normalises and attends over the
piece it is given instead of the whole clip; the posteriors differ in about 3.5% (full)
to 5.5% (light) of frames and GOP is sensitive near thresholds. For both tiers live gives
fewer non-green words on mostly correct reads, i.e. it errs towards the truth, and the
light tier is clearly less stable on long clips whole (54% of words not green on mostly
correct reads). Raising the context to 640 ms or 1.5 s changed light agreement only from
66% to 69-71% so it was left at 160 ms. **Decision for the reviewer**: live is on for both
tiers; if a score-identical result matters more than latency, set `liveScoring` default
to false (`LIVE_SCORING`) or restrict it to the full tier. I2 should recalibrate the
thresholds on live posteriors (A3 files not touched here).

## Phone estimates (ESTIMATES, not measured)

Mid-range phones run this model roughly 1.5-3x slower per big core than this desktop
(by the 4-core CPU ratios in `docs/models.md`). With the tail near 2.7 s of audio at RTF
0.5-1: stop-to-result about 1.5-3 s (full), 1-2 s (light), when the phone is fast enough
to keep up in the background (RTF < 1). Whole-clip on the same phone would be about
12-30 s. If RTF is above 1 on a given phone, a backlog remains at stop and live helps
less. Needs a real measurement.

### How to measure on a phone

1. Build release/profile with `--dart-define=LIVE_SCORING=false` and again with
   `=true`; optionally `--dart-define=ORT_THREADS=2|3|4` and
   `--dart-define=ORT_ACCELERATOR=xnnpack` (or `nnapi` / `coreml`).
2. Read the same 60-word passage aloud (or play the fixture through the speaker/
   a loopback) 5 times each; on tap of stop, note the time until Results appears
   (screen recording at 60 fps, count frames) and take the best and the spread.
3. For CPU: `adb shell dumpsys cpuinfo | grep <package>` before and after, or Android
   Studio Profiler; on iOS use Instruments Time Profiler.
4. Compare the Results screen word colours between the two builds.
5. Record the figures in this file.

## How to run the host benchmarks

```bash
PERF_BENCH=1 PERF_BENCH_THREADS=1,4 PERF_BENCH_RUNS=3 \
PERF_BENCH_MODELS="light=assets/models/light-model.onnx,full=$HOME/coach-models/release-full/full/model.onnx" \
flutter test test/engine/runtime/live_scoring_benchmark_test.dart
# equivalence over a folder of <passageId>.<x>.wav
PERF_EQUIV_DIR=... [PERF_EQUIV_PASSAGES=passages.json] [PERF_EQUIV_MODELS=...] \
flutter test test/engine/runtime/live_equivalence_eval_test.dart
```
Both are tagged `benchmark` and skip unless their variables are set.

## Tests

`chunk_planner_test`, `live_recognition_session_test` (join alignment, tail filling,
fallbacks, cancel), `execution_providers_test` (provider plan, threads, cpufreq parsing),
`test/ui/read/live_scoring_test.dart` (controller: live flow, no live support, start
failure, add failure, finish failure and retry, cancel while scoring, discard, recorder
start failure, too-quiet clip, model preload).

## Known gaps

- Provider selection (XNNPACK/NNAPI/Core ML) and thread choice unmeasured on a phone.
- Light-tier live scores differ more from whole-clip scores (above); needs I2's call.
- Model export/quantisation variants not explored.
- Each live piece loads 160 ms extra context, so total CPU rises (mostly while recording,
  which could add battery use on long passages).
- Only `CoachAudioRecorder` and `OnnxPhonemeRecognizer` implement the new contracts; the
  fakes do not (the Read screen falls back).
