# Contract requests: A2-runtime

No change to `lib/core/contracts/` or `lib/core/models/` is needed: `OnnxPhonemeRecognizer`
passes `runPhonemeRecognizerContract` unchanged. The items below need someone else's files.

## 1. Licence allowlist decision: `connectivity_plus` (W0 / human): DONE

**Done 2026-10-20**: owner approved `nm` and `dbus`; `ConnectivityNetworkMonitor` is
restored with `InterfaceNetworkMonitor` as fallback. Note: `connectivity_plus` 7.x does
**not** read Android's metered flag (transport only); it fixes the hotspot and
Wi-Fi-without-internet cases. See docs/handoff/A2-runtime.md.

- **What:** either approve `nm` and `dbus` (MPL-2.0) in `tools/ci/licence_allowlist.txt`,
  or confirm the current workaround.
- **Why:** `connectivity_plus` (BSD-3) pulls in `nm` and `dbus` for its Linux desktop
  implementation only. Their MPL-2.0 text names the "GNU Affero General Public License"
  as a possible secondary licence, so `check_licences.py` classifies them as AGPL and
  fails. I removed `connectivity_plus` and wrote `InterfaceNetworkMonitor` (pure
  `dart:io`, checks for a Wi-Fi / Ethernet interface with a routable address and polls
  every 5 s). It works, but it can't see Android's "metered Wi-Fi" flag, and on a few
  Android phones the hotspot runs on `wlan0`, which it would mistake for Wi-Fi. If a
  human approves the two MPL packages (they never ship in the Android / iOS builds),
  I1 can restore `ConnectivityNetworkMonitor` (the class is in git history at
  `9d23069:lib/engine/runtime/network.dart`) and its `onConnectivityChanged` stream.
- **Affects:** `tools/ci/licence_allowlist.txt` (W0), `pubspec.yaml`, A2's
  `network.dart`. A side note for W0: the classifier also misreads any other MPL-2.0
  package as AGPL.

## 2. Model file format for A4 (A4-models)

What `OnnxPhonemeRecognizer` loads. Please produce files in this form:

- **Quantisation:** ONNX Runtime's CPU provider has **no `ConvInteger` kernel for
  int8 (signed) activations**. The Hugging Face `onnx-community` `model_int8.onnx`
  export fails to load with `Could not find an implementation for
  ConvInteger(10) node ... conv_layers.0/conv/Conv_quant`. Use
  `quantize_dynamic(..., weight_type=QuantType.QUInt8)` (as the working
  `model_quantized.onnx` / `model_uint8.onnx` does), or quantise only `MatMul`
  (`op_types_to_quantize=["MatMul"]`) and leave the conv feature encoder in float.
- **Graph I/O:** input `input_values` float32 `[batch, samples]`, optionally
  `attention_mask` int64 `[batch, samples]` (fed as all ones), output `logits`
  float32 `[batch, frames, vocab]` (raw logits; A2 applies log-softmax). If the names
  differ, A2 falls back to the first input / output.
- **Vocab:** Hugging Face `vocab.json` (`{"symbol": index}`, indices 0..n-1, matching
  the logits columns). The CTC blank must be `<pad>` (else `<blank>`, `[PAD]`, `_`;
  else index 0).
- **Manifest (`assets/models/manifest.json`, format in `tools/ci/fetch_models.py`):**
  per tier, exactly one `*.onnx` and one `*.json` entry. The bundled light-tier
  entries (`bundle: true`) need **flat names** such as `light_model.onnx` and
  `light_vocab.json`, because `pubspec.yaml` registers only `assets/models/` and
  Flutter does not bundle subfolders. Full-tier names may have folders; A2 stores
  them by base name, so the two full-tier base names must differ.
  `assets/models/*.onnx` is already git-ignored. `light_vocab.json` is small and can
  be committed or fetched.
- **Licences:** each file named in the manifest must appear in `docs/licences.md`, or
  the licence check fails.

## 3. `docs/licences.md` rows (W0 / I1, or whoever owns the page)

Add to "Shipped in the app":

| Component | File(s) | Licence | Source | Added by |
| --- | --- | --- | --- | --- |
| ONNX Runtime (native library) | `libonnxruntime.so` (Android AAR `com.microsoft.onnxruntime:onnxruntime-android:1.23.2`), `onnxruntime-objc` / `onnxruntime-c` 1.23.0 pods (iOS) | MIT | microsoft/onnxruntime, via the `onnxruntime_v2` plug-in (MIT) | A2 |

Fill in the model rows when A4 publishes the files.

## 4. Native configuration (R1 / I1): nothing required, but unverified

- Android: the plug-in adds the ORT AAR through Gradle. minSdk 29 and the
  `INTERNET` / `ACCESS_NETWORK_STATE` permissions are already set. No `android/` change
  is expected.
- iOS: the plug-in's podspec depends on `onnxruntime-objc` 1.23.0. A2 resolves the
  C API with `DynamicLibrary.process()`, which needs the ORT symbols linked into the
  app binary. The pod is a static xcframework that the Obj-C wrapper references, so
  they should be linked. If an iOS build reports `OrtGetApiBase` not found, add
  `-Wl,-u,_OrtGetApiBase` to the Runner's other linker flags. This is not tested
  here: there is no Xcode on this machine.
