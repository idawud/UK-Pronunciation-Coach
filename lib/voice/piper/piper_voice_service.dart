import 'package:flutter/foundation.dart';

import '../../core/contracts/voice_service.dart';
import 'piper_engine.dart';
import 'piper_voices.dart';

/// [VoiceService] that speaks with a Piper voice and falls back to [fallback]
/// (the system voice) whenever Piper is unavailable or fails.
class PiperVoiceService implements VoiceService {
  /// Creates the service. [voice] must be an approved voice.
  PiperVoiceService({
    required this.engine,
    required this.fallback,
    PiperVoiceCandidate? voice,
  }) : voice = voice ?? approvedPiperVoices.first {
    if (!this.voice.approved) {
      throw ArgumentError.value(this.voice.id, 'voice', 'licence not approved');
    }
  }

  /// The Piper engine.
  final PiperEngine engine;

  /// System voice used when Piper cannot speak.
  final VoiceService fallback;

  /// The Piper voice in use.
  final PiperVoiceCandidate voice;

  Future<bool>? _ready;

  /// Piper's length scale for a contract rate: 1 / rate (0.6 -> 1.67, slower).
  static double lengthScaleFor(double rate) => 1.0 / rate;

  Future<bool> _ensureReady() => _ready ??= () async {
    try {
      if (!await engine.isAvailable(voice)) return false;
      await engine.load(voice);
      return true;
    } catch (e) {
      debugPrint('PiperVoiceService: load failed: $e');
      return false;
    }
  }();

  @override
  Future<void> speak(
    String text, {
    double rate = VoiceService.normalRate,
  }) async {
    if (rate.isNaN || rate < 0.1 || rate > 2.0) {
      throw ArgumentError.value(rate, 'rate', 'must be 0.1-2.0');
    }
    await stop();
    if (text.trim().isEmpty) return;
    if (await _ensureReady()) {
      try {
        await engine.speak(text, lengthScale: lengthScaleFor(rate));
        return;
      } catch (e) {
        debugPrint('PiperVoiceService: speak failed, using system voice: $e');
      }
    }
    await fallback.speak(text, rate: rate);
  }

  @override
  Future<void> stop() async {
    try {
      await engine.stop();
    } catch (e) {
      debugPrint('PiperVoiceService: stop failed: $e');
    }
    await fallback.stop();
  }

  @override
  Future<bool> hasBritishVoice() async =>
      await _ensureReady() || await fallback.hasBritishVoice();

  @override
  Future<String?> voiceName() async => await _ensureReady()
      ? voice.displayName ?? voice.id
      : fallback.voiceName();
}
