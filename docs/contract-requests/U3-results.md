# Contract requests: U3-results

## 1. Play back the user's own recording (needed for "play" on Results / Fix a word)

**Change.** Add a small playback contract (or extend `VoiceService`), bound in
`lib/core/providers.dart` as `clipPlayerProvider`:

```dart
/// Plays back a recording made by the app (app-private WAV), offline.
abstract interface class ClipPlayer {
  /// Plays [path] (optionally only [start]..[end], e.g. one word of a passage).
  /// Stops anything already playing; completes when playback ends or is stopped.
  /// Throws [FileSystemException]-like `StateError` when the file is gone.
  Future<void> play(String path, {Duration? start, Duration? end});

  /// Stops playback. Safe to call at any time.
  Future<void> stop();
}
```

plus a `FakeClipPlayer` recording `(path, start, end)` calls and a
`runClipPlayerContract(create)` suite.

**Why.** Results and Fix a word should let the user hear themselves next to the British
voice (spec F3, and "Record and compare" in v1.1). Nothing in the contracts plays audio:
`VoiceService` only speaks text, and `AudioRecorder.stop` returns an `AudioClip` path
with no way to play it. A word span is available from `PhonemeResult.start/end` (first
and last phoneme of a `WordResult`) and `AttemptResult.audioPath` (when
`UserProfile.keepRecordings` is on), so with this contract U3 can add "Play mine" to the
word sheet and to Fix a word (the hold-to-record clip). Left out of Wave 1 for now.

**Affects.** C4-voice (natural owner: it already wraps native audio for TTS) or A1-audio,
I1 (provider binding), U3 (adds the buttons), the fakes and a new shared suite.

## 2. (Optional) Delete a retry clip

Fix a word and the Results word sheet record a new clip per try and never need it after
scoring. `AudioRecorder` has no `delete(AudioClip)`, so these clips stay in app-private
storage unless A1 cleans them up itself. Proposal: `Future<void> discard(AudioClip clip)`
on `AudioRecorder` (deletes the file; no-op if missing), or document that A1 deletes
clips older than the latest N. Affects A1, the fake and the recorder suite.
