import '../models/audio_clip.dart';
import '../models/enums.dart';
import '../models/segment.dart';

/// Records the user reading aloud (A1). One recording at a time.
///
/// Passage reading (U2): call [start], show [level] as a waveform, call [stop] on tap or
/// when [silenceDetected] fires. Hold-to-record (U3 Fix a word): call [start] on press
/// and [stop] on release, ignoring [silenceDetected]. Call [cancel] when leaving a screen
/// mid-recording.
abstract interface class AudioRecorder {
  /// Current microphone permission without prompting the user.
  Future<MicPermission> checkPermission();

  /// Shows the system permission prompt if allowed and returns the resulting state.
  /// Returns [MicPermission.permanentlyDenied] without prompting when the OS will no
  /// longer show the prompt.
  Future<MicPermission> requestPermission();

  /// Opens the app's page in the system settings (for the permanently-denied state).
  /// Returns false if it could not be opened.
  Future<bool> openPermissionSettings();

  /// True between a successful [start] and the following [stop] or [cancel].
  bool get isRecording;

  /// Starts recording 16 kHz mono 16-bit PCM WAV into app-private storage.
  ///
  /// Completes once audio is being captured (target < 300 ms after the tap).
  /// Throws [MicPermissionException] when permission is not granted, and [StateError]
  /// if already recording.
  Future<void> start();

  /// Stops recording and returns the finished clip, including its [AudioQuality]
  /// check (too quiet: peak < -30 dBFS; too noisy: estimated SNR < 15 dB).
  ///
  /// Throws [StateError] if not recording.
  Future<AudioClip> stop();

  /// Stops recording, if any, and deletes the partial file. Safe to call at any time.
  Future<void> cancel();

  /// Input level while recording, about 20 values per second, each in 0.0 (silence)
  /// to 1.0 (full scale), linear in dBFS between -60 dB and 0 dB.
  ///
  /// Broadcast stream; emits nothing while not recording.
  Stream<double> get level;

  /// Fires once per recording after 2 s of silence that follows detected speech.
  /// Does not stop the recording: the caller decides (passage reading stops on it).
  ///
  /// Broadcast stream.
  Stream<void> get silenceDetected;

  /// Speech regions of [clip] found by the voice-activity detector (Silero VAD), each
  /// padded by 150 ms, merged where they overlap, clamped to the clip, sorted by start.
  /// Returns an empty list for a clip with no speech.
  Future<List<Segment>> speechSegments(AudioClip clip);

  /// Releases native resources. The recorder must not be used afterwards.
  Future<void> dispose();
}
