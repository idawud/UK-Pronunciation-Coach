import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fake_voice_service.dart';
import 'package:uk_pronunciation_coach/voice/piper/piper_engine.dart';
import 'package:uk_pronunciation_coach/voice/piper/piper_voice_service.dart';
import 'package:uk_pronunciation_coach/voice/piper/piper_voices.dart';

import '../contracts/voice_service_contract.dart';

class FakePiperEngine implements PiperEngine {
  FakePiperEngine({this.available = true});
  bool available;
  bool failLoad = false;
  bool failSpeak = false;
  bool failStop = false;
  final loaded = <String>[];
  final spoken = <(String, double)>[];
  int stops = 0;

  @override
  Future<bool> isAvailable(PiperVoiceCandidate voice) async => available;

  @override
  Future<void> load(PiperVoiceCandidate voice) async {
    if (failLoad) throw StateError('load');
    loaded.add(voice.id);
  }

  @override
  Future<void> speak(String text, {required double lengthScale}) async {
    if (failSpeak) throw UnsupportedError('oov');
    spoken.add((text, lengthScale));
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('stop');
  }
}

void main() {
  group('contract', () {
    runVoiceServiceContract(
      () async => PiperVoiceService(
        engine: FakePiperEngine(),
        fallback: FakeVoiceService(),
      ),
    );
  });
  group('contract, Piper unavailable', () {
    runVoiceServiceContract(
      () async => PiperVoiceService(
        engine: FakePiperEngine(available: false),
        fallback: FakeVoiceService(britishVoice: false),
      ),
    );
  });

  test('speaks with Piper, rate -> length scale 1/rate', () async {
    final engine = FakePiperEngine();
    final fallback = FakeVoiceService();
    final voice = PiperVoiceService(engine: engine, fallback: fallback);
    await voice.speak('Thursday');
    await voice.speak('Thursday', rate: 0.6);
    expect(engine.loaded, ['en_GB-cori-medium']);
    expect(engine.spoken[0].$2, 1.0);
    expect(engine.spoken[1].$2, closeTo(1 / 0.6, 1e-9));
    expect(fallback.spoken, isEmpty);
    expect(await voice.hasBritishVoice(), isTrue);
    expect(await voice.voiceName(), 'Cori (Piper)');
    expect(PiperVoiceService.lengthScaleFor(2.0), 0.5);
  });

  test(
    'falls back when unavailable, failing to load, or failing to speak',
    () async {
      for (final engine in [
        FakePiperEngine(available: false),
        FakePiperEngine()..failLoad = true,
        FakePiperEngine()..failSpeak = true,
      ]) {
        final fallback = FakeVoiceService();
        final voice = PiperVoiceService(engine: engine, fallback: fallback);
        await voice.speak('bath', rate: 0.6);
        expect(fallback.spoken, [('bath', 0.6)]);
      }
      final none = PiperVoiceService(
        engine: FakePiperEngine(available: false),
        fallback: FakeVoiceService(),
      );
      expect(await none.voiceName(), 'English (United Kingdom)');
    },
  );

  test('validates rate, skips empty text, stops both engines safely', () async {
    final engine = FakePiperEngine()..failStop = true;
    final fallback = FakeVoiceService();
    final voice = PiperVoiceService(engine: engine, fallback: fallback);
    await expectLater(voice.speak('a', rate: 0), throwsArgumentError);
    await expectLater(voice.speak('a', rate: double.nan), throwsArgumentError);
    await voice.speak(' ');
    expect(engine.spoken, isEmpty);
    await voice.stop();
    expect(fallback.stopCount, greaterThan(0));
  });

  test('refuses a voice whose licence is not approved', () {
    final vctk = piperEnGbVoices.firstWhere((v) => v.id == 'en_GB-vctk-medium');
    expect(
      () => PiperVoiceService(
        engine: FakePiperEngine(),
        fallback: FakeVoiceService(),
        voice: vctk,
      ),
      throwsArgumentError,
    );
  });

  group('licence catalogue', () {
    test('covers all 11 en_GB voices and approves only Cori', () {
      expect(piperEnGbVoices, hasLength(11));
      expect(piperEnGbVoices.map((v) => v.id).toSet(), hasLength(11));
      expect(approvedPiperVoices.map((v) => v.id), [
        'en_GB-cori-medium',
        'en_GB-cori-high',
      ]);
    });
    test('approved voices are from scratch and fully described', () {
      for (final v in approvedPiperVoices) {
        expect(v.base, 'scratch');
        expect(v.displayName, isNotEmpty);
        expect(v.modelBytes, greaterThan(0));
      }
    });
    test('every rejected voice says why', () {
      for (final v in piperEnGbVoices.where((v) => !v.approved)) {
        expect(v.reason, isNotEmpty);
        expect(v.base, isNot('scratch'));
      }
    });
  });
}
