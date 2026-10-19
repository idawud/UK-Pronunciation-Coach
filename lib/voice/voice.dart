/// British model voice (C4). I1 binds [createVoiceService] in
/// `lib/core/providers.dart`:
///
/// ```dart
/// final voiceServiceProvider = Provider<VoiceService>((ref) {
///   final service = createVoiceService();
///   ref.onDispose(service.stop);
///   return service;
/// });
/// ```
library;

import '../core/contracts/voice_service.dart';
import 'flutter_tts_engine.dart';
import 'piper/piper_engine.dart';
import 'piper/piper_voice_service.dart';
import 'system_voice_service.dart';
import 'tts_engine.dart';

export 'flutter_tts_engine.dart';
export 'piper/piper_engine.dart';
export 'piper/piper_voice_service.dart';
export 'piper/piper_voices.dart';
export 'rate_mapping.dart';
export 'system_voice_service.dart';
export 'tts_engine.dart';
export 'voice_selection.dart';

/// Feature flags for the voice.
class VoiceFlags {
  /// Creates flags; everything is off by default.
  const VoiceFlags({this.piperVoice = false});

  /// Flags from `--dart-define=PIPER_VOICE=true` (off unless set).
  static const VoiceFlags fromEnvironment = VoiceFlags(
    piperVoice: bool.fromEnvironment('PIPER_VOICE'),
  );

  /// Use the optional Piper neural voice (falls back to the system voice).
  final bool piperVoice;
}

/// Builds the app's [VoiceService]: the system en-GB voice, or Piper over it when
/// [flags] enable Piper and a [piperEngine] is supplied.
VoiceService createVoiceService({
  VoiceFlags flags = VoiceFlags.fromEnvironment,
  TtsEngine? ttsEngine,
  PiperEngine? piperEngine,
}) {
  final system = SystemVoiceService(engine: ttsEngine ?? FlutterTtsEngine());
  if (flags.piperVoice && piperEngine != null) {
    return PiperVoiceService(engine: piperEngine, fallback: system);
  }
  return system;
}
