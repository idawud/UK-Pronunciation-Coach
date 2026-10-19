import 'piper_voices.dart';

/// Neural Piper (VITS) voice engine, used only when `VoiceFlags.piperVoice` is on.
///
/// **No implementation ships yet** (documented next step in
/// docs/handoff/C4-voice.md). Constraints for whoever writes it:
/// * Do not add sherpa_onnx: it bundles a second ONNX Runtime next to A2's
///   onnxruntime_v2 (native symbol clashes) and links eSpeak NG (GPL-3.0) for
///   Piper phonemisation, which the licence rules forbid in the app.
/// * Instead run the voice `.onnx` with A2's ONNX Runtime and build phoneme ids in
///   Dart from Britfone IPA (MIT, C1) using the voice's `phoneme_id_map`, so no
///   eSpeak code ships. Words Britfone lacks fall back to the system voice.
/// * Only voices in [approvedPiperVoices]; model files go to Release assets with
///   SHA-256 (never in git) and are listed in docs/licences.md.
abstract interface class PiperEngine {
  /// Whether [voice]'s model files are present and the engine can run.
  Future<bool> isAvailable(PiperVoiceCandidate voice);

  /// Loads [voice]; throws when it is unavailable.
  Future<void> load(PiperVoiceCandidate voice);

  /// Synthesises and plays [text]; completes when playback ends or is stopped.
  /// [lengthScale] is Piper's duration factor (1.0 normal, larger is slower).
  /// Throws [UnsupportedError] when the text cannot be phonemised.
  Future<void> speak(String text, {required double lengthScale});

  /// Stops playback. Safe to call at any time.
  Future<void> stop();
}
