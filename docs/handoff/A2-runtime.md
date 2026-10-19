# Handoff: A2-runtime

`OnnxPhonemeRecognizer` implements `PhonemeRecognizer`. It runs a wav2vec2 CTC phoneme
model in ONNX with ONNX Runtime's C API in a background isolate, and returns per-frame
log-softmax posteriors (20 ms frames) over the model's `vocab.json`. The light tier is
bundled; the full tier is downloaded once over Wi-Fi with progress, resume and
SHA-256 check. `recommendedTier()` picks the tier from the hardware or, if unsure, a
5 s benchmark.

## How to use it

```dart
final recognizer = await OnnxPhonemeRecognizer.create(); // app: rootBundle + app-support dir
final tier = profile.tierOverride ?? await recognizer.recommendedTier();
await recognizer.load(await recognizer.isTierAvailable(tier) ? tier : ModelTier.light);
final posteriors = await recognizer.recognise(clip); // AudioClip from A1 (16 kHz WAV)
```

I1 binds it in `lib/core/providers.dart`. Tests and tools build it with the plain
constructor, which takes every collaborator (light-model source, manifest,
`ModelTransport`, `NetworkMonitor`, `DeviceInfoSource`, session opener).
`lastInferenceTime` reports how long the model alone took on the last call.

Files: see `lib/engine/runtime/README.md`. Models live under
`<app support>/models/{light,full}/`, and the cached tier is in `tier.json`.

## Package choice and licence check

**`onnxruntime_v2` 1.23.2+2** (pub.dev, MIT, repo
github.com/Persie0/onnxruntime_flutter_1_22_0). I kept it, with one change: I call the
**stable ORT C API** through its generated FFI bindings and load the native library
myself. Its high-level Dart API is not used.

- Native libraries are Microsoft's ONNX Runtime (**MIT**). Android uses the Gradle
  AAR `com.microsoft.onnxruntime:onnxruntime-android:1.23.2`; iOS uses the
  `onnxruntime-objc` 1.23.0 pod; Linux/Windows/macOS use a bundled
  `libonnxruntime.so.1.22.0` and equivalents. Platforms: Android, iOS, Linux, macOS,
  Windows.
- Maintenance risk: it is a small fork (5 likes, published ~9 months ago, unverified
  uploader) of `gtbluesky/onnxruntime` (1.4.1, unmaintained for 2 years, ORT 1.15
  era). The fork does track current ORT releases and adds 16 KB-page Android
  support, which Play requires. Because A2 depends only on the ORT C API (requested
  API version 14) and on the plug-in shipping the native library, replacing the
  plug-in later only touches `openOnnxRuntimeLibrary` and one import.
- **sherpa_onnx** (Apache-2.0, 1.13.8) was not chosen. Its Dart API returns decoded
  text, tokens and timestamps from its own recognisers, not the raw per-frame CTC
  logits of an arbitrary wav2vec2 model, which A3's forced alignment needs. A1 may
  still use it for Silero VAD.
- **onnxruntime** 1.4.1 (the original plug-in) is unmaintained and ships an old ORT
  without 16 KB-page support.

Other packages A2 added (licence files read from the pub cache): `ffi` 2.2.0, `crypto`
3.0.7, `path_provider` 2.1.6 (+ platform packages), `device_info_plus` 13.3.0 (+
platform interface, `win32`, `win32_registry`): all **BSD-3-Clause**. Transitive:
`petitparser`, `xml` are MIT; `code_assets`, `hooks`, `jni*`, `objective_c`,
`record_use`, `xdg_directories` are BSD-3. **`connectivity_plus` was added and then
removed.** Its Linux-only dependencies `nm` and `dbus` are MPL-2.0, which
`check_licences.py` reads as AGPL. The Wi-Fi check is now pure `dart:io`
(`InterfaceNetworkMonitor`); see contract request 1.

## pubspec edits (ownership exception)

`pubspec.yaml` dependencies added: `crypto ^3.0.7`, `device_info_plus ^13.3.0`, `ffi
^2.2.0`, `onnxruntime_v2 ^1.23.2+2`, `path_provider ^2.1.6`. `pubspec.lock` was
regenerated to match. `connectivity_plus` was added in 4f0cf12 and removed in
2f2c6f7. The `assets/models/` asset entry was already there, and I did not change
it. `assets/models/README.md` now documents the loader's expectations. No
`manifest.json` yet: A4 owns the files.

## Development model (until A4 delivers)

`facebook/wav2vec2-lv-60-espeak-cv-ft` (Apache-2.0), ONNX export
`onnx-community/wav2vec2-lv-60-espeak-cv-ft-ONNX`:

| | |
| --- | --- |
| File used | `onnx/model_quantized.onnx` (dynamic **uint8**), 317,712,852 bytes, sha256 `3d1479b5c70836645a4310902479f7f7e8bbc8c16c58745d918804f4f6f9d120` (identical to `model_uint8.onnx`) |
| Vocab | `vocab.json`, **392 symbols** (indices 0-391): `<pad>`=0, `<s>`=1, `</s>`=2, `<unk>`=3, then IPA (e.g. `n`=4, `s`=5) |
| Blank | **`<pad>`, index 0** (`pad_token_id` 0) |
| Frames | conv strides 5·2·2·2·2·2·2 = 320 samples = **20 ms, 50 frames/s**; receptive field 400 samples; frames = ⌊(samples − 400) / 320⌋ + 1 (3.21 s → 160, 20 s → 999) |
| Input | `input_values` float32 [1, samples], zero-mean / unit-variance (`do_normalize: true`); no `attention_mask` input in this export |
| Output | `logits` float32 [1, frames, 392] |

**`model_int8.onnx` from the same repo does not load** in ONNX Runtime (CPU has no
int8-activation `ConvInteger` kernel). A4 must quantise with uint8 (see contract
request 2).

Fetch it (git-ignored cache, ~318 MB):

```bash
mkdir -p .model-cache/dev && cd .model-cache/dev
B=https://huggingface.co/onnx-community/wav2vec2-lv-60-espeak-cv-ft-ONNX/resolve/main
curl -fLO $B/vocab.json && curl -fL -o model_quantized.onnx $B/onnx/model_quantized.onnx
```

`test/engine/runtime/dev_model_test.dart` picks it up from there (or from
`A2_DEV_MODEL_DIR`) and is skipped when it is absent. Sanity check on the fixture "On
Thursday we walked by the river." (eSpeak voice), greedy decode:
`ɔ n θ ɜː s t eɪ w iː w ɔː k t aɪ ð ə ɹ ɪ v ɚ`. The vocab mapping is right.

## Tests and results

- **Contract suite:** `runPhonemeRecognizerContract` **passes** (all 5 tests,
  including download via an in-memory transport) against `OnnxPhonemeRecognizer`
  with the tiny fixture model on the real host ORT. The 4 non-download tests also
  pass with the real dev model as the light tier.
- Unit tests in `test/engine/runtime/` (91 with the dev model present):
  - WAV decode/encode, normalisation, vocab parsing, log-softmax;
  - ORT session (with and without `attention_mask`, error paths) and the isolate
    protocol;
  - downloader: resume, server ignoring Range, oversized `.part`, checksum failure
    and retry, HTTP errors, Wi-Fi wait / loss / cancel, concurrent calls, delete,
    stale marker;
  - tier rules and cache, bundled-asset copy, loopback HTTP transport, interface
    Wi-Fi check, tier relabelling during a load race, restart persistence, dispose.
- Fixture model: `test/engine/runtime/fixtures/tiny_ctc{,_mask}.onnx` (13 KB, random
  weights, wav2vec2 frame maths, 8-symbol vocab). Rebuild with
  `.venv/bin/pip install onnx numpy && .venv/bin/python
  test/engine/runtime/fixtures/make_tiny_model.py`. On-device test
  `integration_test/A2-runtime/` embeds it as base64 (`tiny_model_data.dart`; regenerate
  if the fixture changes).
- Host tests load the plug-in's Linux `libonnxruntime.so.1.22.0` straight from the
  pub cache (`helpers/host_ort.dart`), because `flutter test` does not build plug-ins.
  On non-Linux hosts a pure-Dart stub session stands in.
- **Coverage:** `lib/engine/` 96.7% (gate 85%).
- **`scripts/check.sh`: passes** (format, analyze, 244 Dart tests incl. goldens,
  coverage gate, ruff + 30 pytest, content, licences).

### Benchmark (20 s clip, this machine)

8-CPU x86-64 WSL2 laptop VM, no GPU, other agents running at the same time (load
average 4-5). `dev_model_test.dart` takes 20 s of speech (the fixture looped), warms
up, then runs `recognise()` 3 times through the isolate. The model uses 4 ORT intra-op
threads.

| Run | Model load | 20 s clip end-to-end (min / median / max) | Model alone | RTF (median) |
| --- | --- | --- | --- | --- |
| standalone, best | 0.94 s | 7.55 / 8.43 / 14.2 s | 7.50 / 8.36 / 14.2 s | 0.42 |
| standalone | 2.2-2.8 s | 8.9-10.9 / 9.4-11.3 / 12.8-21 s | ≈ end-to-end − 60 ms | 0.47-0.57 |
| inside `check.sh` (parallel tests, coverage), quieter machine | 1.35 s | 6.95 / 7.04 / 9.48 s | 6.92 / 7.00 / 9.44 s | 0.35 |
| inside `check.sh`, busy machine | 2.2 s | 10.7 / 15.1 / 21.0 s | (not recorded) | 0.75 |

For comparison, raw ORT on the same model: from Dart (ORT 1.22) 6.6-8.9 s at 4 or 8
threads; Python `onnxruntime` 1.31, 4 threads 5.6-7.3 s, 8 threads 5.1-6.1 s. The
whole A2 pipeline (WAV decode, normalise, log-softmax, isolate hop, `PhonemePosteriors`)
adds **~50-70 ms**. The time is in the 315 M-parameter model.

**This is far from the target** (25 s in < 2.5 s on a mid-range phone, full tier).
The x86 numbers say little about ARM64 phones, where ORT's int8 kernels use the dot-
product instructions, but I1/I2 must measure on a real device. If the full tier misses,
options: the light tier by default (A4's wav2vec2-base model, ~3x less work), score per
sentence while the user reads, or the XNNPACK / NNAPI / CoreML execution providers.
When the hardware rules can't decide, `TierAdvisor` already gives the light tier to
any device that takes more than 170 ms to run the light model on 5 s of audio.

## Decisions

- Inference: a long-lived isolate (`InferenceWorker`) owns the ORT session. The
  worker reads the WAV from `clip.path`, so audio never crosses isolates. Logits come
  back as `TransferableTypedData` (no copy). `recognise` is queued behind pending
  `load`s, so the `tier` label always matches the model that ran.
- Loading a new tier opens the new session before closing the old one (a failed load
  keeps the old model). Peak memory briefly holds both.
- Tier rules: light below 3,400 MB reported RAM (a "4 GB" phone reports ~3.6-3.8 GB
  and gets full), on Android < 10 (API 29), or on iPhone before `iPhone11,x` (XS).
  With unknown RAM it benchmarks the light model on 5 s. The answer is cached in
  `tier.json`. Settings override it through `UserProfile.tierOverride` (the caller's
  job).
- Download: one `.part` per file, resumed with HTTP Range (restarts if the server
  answers 200). If Wi-Fi drops it pauses and waits again, with no data lost. Every
  file is hashed in a background isolate; all bad files are deleted before failing,
  so one retry fixes them all. `verified.json` marks completion so start-up doesn't
  re-hash 300 MB. Cancel keeps `.part` files.
- `fullModelSizeBytes` falls back to the dev model's size (317,717,489 bytes) until
  the manifest lists the full tier.

## Known gaps

- **No light model yet.** Until A4 publishes `manifest.json`, the app build has no
  light tier: `isTierAvailable(light)` is false and `load(light)` throws. This breaks
  the "light is always available" promise in production builds only; tests inject a
  light model.
- **On-device tests not run.** There is no Android SDK, emulator or Xcode here, and
  no `linux/` desktop runner. `integration_test/A2-runtime/` is analysed only. The
  iOS symbol-linking risk is in contract request 4.
- **Wi-Fi detection is a heuristic** (contract request 1): it polls interfaces every
  5 s, can't see metered Wi-Fi, and Android's `NetworkInterface.list` behaviour on
  every vendor is unverified.
- **Performance target not met on this CPU** (see the benchmark); it needs measuring
  on real phones.
- Bundling: copying the light model out of the asset bundle loads it fully into
  memory once (~100 MB spike on first run).
- `dev_model_test.dart` takes ~40 s and runs inside `check.sh` whenever the dev model
  is cached; CI skips it.
- Contract requests (`docs/contract-requests/A2-runtime.md`):
  1. allowlist or confirm the `connectivity_plus` removal;
  2. A4 model format: uint8 quantisation, I/O names, flat bundled names;
  3. `docs/licences.md` ORT row;
  4. iOS / Android native notes.
