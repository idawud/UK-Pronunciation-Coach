import '../contracts/voice_service.dart';

/// [VoiceService] that records what it was asked to say instead of speaking.
class FakeVoiceService implements VoiceService {
  /// Creates the fake; [britishVoice] controls [hasBritishVoice].
  FakeVoiceService({this.britishVoice = true});

  /// Value of [hasBritishVoice].
  bool britishVoice;

  /// Every (text, rate) passed to [speak], in order.
  final List<(String, double)> spoken = [];

  /// Number of [stop] calls.
  int stopCount = 0;

  @override
  Future<void> speak(String text, {double rate = 1.0}) async {
    if (rate < 0.1 || rate > 2.0) {
      throw ArgumentError.value(rate, 'rate', 'must be 0.1-2.0');
    }
    if (text.trim().isEmpty) return;
    spoken.add((text, rate));
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<bool> hasBritishVoice() async => britishVoice;

  @override
  Future<String?> voiceName() async =>
      britishVoice ? 'English (United Kingdom)' : null;
}
