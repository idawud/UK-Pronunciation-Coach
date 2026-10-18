/// Speaks words and sentences in a British voice (C4), offline.
abstract interface class VoiceService {
  /// Normal speaking rate.
  static const double normalRate = 1.0;

  /// "Play slowly" rate.
  static const double slowRate = 0.6;

  /// Speaks [text] with the best installed en-GB voice at [rate] (1.0 normal, 0.6 slow;
  /// valid range 0.1-2.0, else [ArgumentError]). Stops anything already speaking.
  /// Completes when speech finishes or is stopped. Empty text completes immediately.
  Future<void> speak(String text, {double rate = 1.0});

  /// Stops speaking. Safe to call at any time.
  Future<void> stop();

  /// Whether an offline en-GB voice is installed. When false the UI explains how to
  /// download one in the system settings.
  Future<bool> hasBritishVoice();

  /// Display name of the voice in use, or null when none is available.
  Future<String?> voiceName();
}
