import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/voice/voice.dart';

import 'helpers/fake_tts_engine.dart';
import 'piper_voice_service_test.dart' show FakePiperEngine;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Piper flag is off by default', () {
    expect(const VoiceFlags().piperVoice, isFalse);
    expect(VoiceFlags.fromEnvironment.piperVoice, isFalse);
  });

  test('default: system voice', () {
    expect(
      createVoiceService(ttsEngine: FakeTtsEngine()),
      isA<SystemVoiceService>(),
    );
    expect(createVoiceService(), isA<SystemVoiceService>());
  });

  test('flag on without an engine: system voice', () {
    expect(
      createVoiceService(
        flags: const VoiceFlags(piperVoice: true),
        ttsEngine: FakeTtsEngine(),
      ),
      isA<SystemVoiceService>(),
    );
  });

  test('flag off with an engine: system voice', () {
    expect(
      createVoiceService(
        ttsEngine: FakeTtsEngine(),
        piperEngine: FakePiperEngine(),
      ),
      isA<SystemVoiceService>(),
    );
  });

  test('flag on with an engine: Piper over the system voice', () {
    final service = createVoiceService(
      flags: const VoiceFlags(piperVoice: true),
      ttsEngine: FakeTtsEngine(),
      piperEngine: FakePiperEngine(),
    );
    expect(service, isA<PiperVoiceService>());
    expect((service as PiperVoiceService).fallback, isA<SystemVoiceService>());
  });
}
