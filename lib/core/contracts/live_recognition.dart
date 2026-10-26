import 'dart:typed_data';

import '../models/audio_clip.dart';
import '../models/phoneme_posteriors.dart';

// Optional capabilities for scoring while the user reads (perf-speed, 2026-10-26).
// Additive and backward compatible: nothing has to implement them. The Read screen
// uses them only when the bound AudioRecorder is a [LiveAudioSource] and the bound
// PhonemeRecognizer is an [IncrementalPhonemeRecognizer]; otherwise it recognises the
// finished clip as before. See docs/contract-requests/perf-speed.md.

/// One block of audio captured while recording, as it arrives from the microphone.
class LiveAudioBlock {
  /// Creates the block.
  const LiveAudioBlock(
    this.samples, {
    this.speechProbabilities = const [],
    this.speechChunkSamples = 512,
  });

  /// 16 kHz mono samples in [-1, 1], exactly the samples written to the clip's file,
  /// in order. The first block of a recording starts at the clip's first sample.
  final Float32List samples;

  /// Voice-activity probabilities (0-1) of the detector chunks this block completed,
  /// in order. Chunk k of a recording covers samples `[k * speechChunkSamples,
  /// (k + 1) * speechChunkSamples)`. Empty when no detector runs.
  final List<double> speechProbabilities;

  /// Samples per voice-activity chunk (512 for Silero VAD at 16 kHz).
  final int speechChunkSamples;
}

/// An [AudioRecorder] that also streams the audio of the current recording.
abstract interface class LiveAudioSource {
  /// Audio of the current recording, block by block, from `start` until `stop`
  /// returns (every block is delivered before `stop` completes). Broadcast; emits
  /// nothing while not recording.
  Stream<LiveAudioBlock> get liveAudio;
}

/// A [PhonemeRecognizer] that can recognise a recording while it is being made.
abstract interface class IncrementalPhonemeRecognizer {
  /// Starts recognising a new recording. Feed every [LiveAudioBlock] to
  /// [LiveRecognition.add], then call [LiveRecognition.finish] with the clip.
  LiveRecognition startLiveRecognition();
}

/// Recognition of one recording in progress.
abstract interface class LiveRecognition {
  /// Adds the next block of the recording. Completed stretches of speech are
  /// recognised in the background.
  void add(LiveAudioBlock block);

  /// Audio not recognised yet (what [finish] still has to run).
  Duration get pendingAudio;

  /// Recognises what is left and returns the posteriors of the whole [clip], as
  /// `PhonemeRecognizer.recognise(clip)` would (same frame count, `tier` = the
  /// loaded tier). Falls back to recognising [clip] in one piece when the live audio
  /// does not match it or a background step failed.
  Future<PhonemePosteriors> finish(AudioClip clip);

  /// Drops the recording: pending background work is skipped and results ignored.
  void cancel();
}
