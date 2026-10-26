# Contract request: perf-speed (live recognition)

Status: implemented additively (2026-10-26). Nothing existing changed; nothing has to
implement the new interfaces.

## What

New file `lib/core/contracts/live_recognition.dart`, exported from `contracts.dart`:

- `LiveAudioSource` (implemented by the real `CoachAudioRecorder`): a `liveAudio`
  stream of `LiveAudioBlock`s (samples plus the VAD probabilities each block completed),
  delivered synchronously from the mic callback, so every block of a recording has been
  delivered by the time `stop()` returns.
- `IncrementalPhonemeRecognizer` (implemented by the real `OnnxPhonemeRecognizer`):
  `startLiveRecognition()` returns a `LiveRecognition` with `add`, `pendingAudio`,
  `finish(clip)` and `cancel`.

## Why

To recognise each completed stretch of speech while the user is still reading, so
that only the last stretch is left when they press stop (stop-to-Results latency).

## Compatibility

`AudioRecorder` and `PhonemeRecognizer` are untouched. The Read screen checks
`recorder is LiveAudioSource && recognizer is IncrementalPhonemeRecognizer`; fakes and
other implementations keep working (whole-clip recognition). `finish` falls back to
`PhonemeRecognizer.recognise(clip)` itself whenever anything is off.

## Files outside perf-speed's folders that changed

`lib/engine/audio/coach_audio_recorder.dart` (A1): publishes the `liveAudio` stream
(about 20 lines). `lib/core/contracts/` (W0): the new file above.
