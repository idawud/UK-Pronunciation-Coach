// On-device tests for C4: the real flutter_tts plug-in (Android TextToSpeech, iOS
// AVSpeechSynthesizer) behind SystemVoiceService. Offline: only installed voices,
// network voices are never selected. No microphone.
//
//   flutter test integration_test/C4-voice -d <device>
//
// The emulator may have no en-GB voice installed; the tests then check the
// fallback path (hasBritishVoice false, speak still completes).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/voice/voice.dart';

import '../../test/contracts/voice_service_contract.dart';

/// Short cap so a silent emulator (no audio output) cannot hang a test.
Duration _cap(String text, double rate) => const Duration(seconds: 15);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('real flutter_tts', () {
    runVoiceServiceContract(
      () async => SystemVoiceService(engine: FlutterTtsEngine(), timeout: _cap),
    );
  });

  testWidgets('lists voices and picks only an offline en-GB one', (_) async {
    final engine = FlutterTtsEngine();
    final voices = await engine.voices();
    final best = VoiceSelection.best(voices);
    if (best != null) {
      expect(VoiceSelection.isBritish(best.locale), isTrue);
      expect(VoiceSelection.isOffline(best), isTrue);
    }
    final service = SystemVoiceService(engine: engine, timeout: _cap);
    expect(await service.hasBritishVoice(), best != null);
    expect(await service.voiceName(), best == null ? isNull : isNotEmpty);
  });

  testWidgets('word and sentence at normal and slow rates complete', (_) async {
    final service = SystemVoiceService(
      engine: FlutterTtsEngine(),
      timeout: _cap,
    );
    final watch = Stopwatch()..start();
    await service.speak('Thursday');
    await service.speak('Thursday', rate: VoiceService.slowRate);
    await service.speak('We passed an old castle and a farm.');
    expect(watch.elapsed, lessThan(const Duration(seconds: 45)));
    await service.dispose();
  });

  testWidgets('stop ends a long sentence early', (_) async {
    final service = SystemVoiceService(
      engine: FlutterTtsEngine(),
      timeout: _cap,
    );
    final speaking = service.speak(
      'On Thursday we walked by the river, past an old castle and a farm, '
      'and stopped for a long chat about the weather in the bath.',
      rate: VoiceService.slowRate,
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final watch = Stopwatch()..start();
    await service.stop();
    await speaking;
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
