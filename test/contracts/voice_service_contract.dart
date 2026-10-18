import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';

/// Shared behaviour every [VoiceService] must have. C4 runs it against its service
/// built on a fake TTS engine (unit test) and on a device (integration test).
void runVoiceServiceContract(Future<VoiceService> Function() create) {
  group('VoiceService contract', () {
    late VoiceService voice;
    setUp(() async => voice = await create());
    tearDown(() async => voice.stop());

    test('rates', () {
      expect(VoiceService.normalRate, 1.0);
      expect(VoiceService.slowRate, 0.6);
    });

    test('speaks a word and a sentence at normal and slow rates', () async {
      await voice.speak('Thursday');
      await voice.speak('Thursday', rate: VoiceService.slowRate);
      await voice.speak('We passed an old castle and a farm.');
    });

    test('empty text completes at once', () async {
      await voice.speak('');
    });

    test('invalid rates throw ArgumentError', () async {
      await expectLater(voice.speak('bath', rate: 0), throwsArgumentError);
      await expectLater(voice.speak('bath', rate: 3), throwsArgumentError);
    });

    test('stop is always safe', () async {
      await voice.stop();
      await voice.stop();
    });

    test('a British voice has a name', () async {
      if (await voice.hasBritishVoice()) {
        expect(await voice.voiceName(), isNotEmpty);
      }
    });
  });
}
