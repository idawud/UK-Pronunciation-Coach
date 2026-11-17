# Contract requests: Coach Record & compare (feat/coach-record)

## 1. Playback of the user's own recording (not built)

**Need.** The Compare step should play the user's recording, then speak the model
line. Nothing in the app plays a recorded WAV today:

- `lib/ui/results/` and `lib/ui/fix/` play text through `VoiceService` only
  (`SegmentPlayer`), never the recording.
- `lib/engine/audio/` records and reports speech segments, with no playback.
- No audio playback package is in `pubspec.yaml`.

**Shipped instead.** The Record & compare section analyses each reading (pace, pauses,
rhythm) and deletes the clip. Compare shows the reading beside an estimate of the
model line and speaks the model line. No recording is played back.

**Proposed.** Use the `AudioPlayer` contract from `docs/contract-requests/coach-hub.md`
(item 3). When it is merged and implemented, the Compare button should play the
recording first (stop speech and the recorder first), then speak the model line, and
clips should be kept until the user leaves Compare.

## 2. Audio focus between recorder and TTS (device test)

The shadowing flow speaks the line and then starts the recorder. Both use the audio
session, so the recorder must not start until speech has released it. Not in any
contract. Confirm on a phone (see the handoff note).
