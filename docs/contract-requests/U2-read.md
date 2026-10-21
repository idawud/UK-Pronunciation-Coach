# Contract requests: U2-read

## Status (I1-integration, 2026-10-21)

1. Shared record widget: **deferred** (v1.1 UI tidy-up; both controls work, and the Fix a word one is covered by the e2e journey).
2. `AudioRecorder.discard`: **done**; `recordingDeleterProvider` is gone and the controller calls `discard`.
3. Recognition progress / cancel: **deferred** to v1.1 (needs A2 isolate changes).

Nothing here blocks U2. All are optional and small.

## 1. Share the record button and waveform (optional)

**What.** Move `RecordButton` and `LevelWaveform` (plus `formatElapsed`) from
`lib/ui/read/widgets/record_controls.dart` to a shared UI folder, e.g.
`lib/ui/shared/record_controls.dart` (owner: U1 or I1), and have U2 and U3 import it
from there.

- `RecordButton({required bool recording, VoidCallback? onTap, VoidCallback?
  onHoldStart, VoidCallback? onHoldEnd, double size = 88, bool enabled = true})`:
  tap mode (Read) or hold-to-record mode (Fix a word: down = `AudioRecorder.start`,
  up/cancel = `stop`). Theme colours only (primary idle, error recording), semantics
  labels "Start recording" / "Stop recording" / "Hold to record".
- `LevelWaveform({required List<double> levels, double height = 56, int barCount =
  48})`: bars of recent `AudioRecorder.level` values, newest on the right.

**Why.** The U3 prompt says Fix a word should reuse U2's recorder widget, but screen
agents may not import each other's folders. U3 built its own hold-to-record control
in Wave 1, so there are now two. One shared widget keeps the look and semantics
consistent.

**Affects.** U2 (`read_screen.dart` import), U3 (swap its control), widget tests that
find by the semantics labels above. No contract, model or fake changes.

## 2. Delete an unsaved recording through `AudioRecorder` (optional)

**What.** `Future<void> AudioRecorder.discard(AudioClip clip)`: deletes a finished
clip's file (no-op if missing).

**Why.** Recordings that are never saved (too quiet / noisy / no speech, cancelled
scoring, sentence / word / placement retries) must be deleted to honour "recordings
are deleted after scoring". `ProgressRepository.saveAttempt` handles saved passage
attempts, but nothing in the contracts deletes the others. U2 deletes them with
`dart:io` through its own `recordingDeleterProvider` (lib/ui/read/), which works but
puts file handling in the UI layer; U3's hold-to-record has the same gap.

**Affects.** A1 (implement), `FakeAudioRecorder` (count calls), the audio-recorder
suite, U2 (replace `recordingDeleterProvider`), U3.

## 3. Progress for recognition (optional, later)

**What.** Either `PhonemeRecognizer.recognise(clip, {void Function(double)?
onProgress})` or a cancel token.

**Why.** A2 measured ~7 s for 20 s of audio on a desktop CPU. U2 shows an estimated
progress bar (clip length x 0.5 real-time factor) and lets the user cancel, but the
model call keeps running in its isolate and its result is dropped. Real progress and
cancellation would free the CPU sooner.

**Affects.** A2, `FakePhonemeRecognizer`, the recognizer suite, U2, U3.
