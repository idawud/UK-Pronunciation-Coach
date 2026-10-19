import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/voice_service.dart';
import 'package:uk_pronunciation_coach/voice/system_voice_service.dart';
import 'package:uk_pronunciation_coach/voice/tts_engine.dart';

import '../contracts/voice_service_contract.dart';
import 'helpers/fake_tts_engine.dart';

void main() {
  final daniel = iosVoice('Daniel');
  final kate = iosVoice('Kate', quality: 'enhanced');

  group('contract, British voice installed', () {
    runVoiceServiceContract(
      () async => SystemVoiceService(
        engine: FakeTtsEngine(voices: [daniel, kate]),
        platform: TargetPlatform.iOS,
      ),
    );
  });

  group('contract, no British voice', () {
    runVoiceServiceContract(
      () async => SystemVoiceService(
        engine: FakeTtsEngine(voices: [iosVoice('Samantha', locale: 'en-US')]),
        platform: TargetPlatform.android,
      ),
    );
  });

  group('voice selection', () {
    test('selects and applies the best en-GB voice', () async {
      final engine = FakeTtsEngine(voices: [daniel, kate]);
      final voice = SystemVoiceService(engine: engine);
      expect(await voice.hasBritishVoice(), isTrue);
      expect(await voice.voiceName(), 'Kate (Enhanced)');
      expect(voice.selectedVoice, same(kate));
      await voice.speak('bath');
      await voice.speak('path');
      expect(engine.voicesSet, [kate], reason: 'voice applied once');
      expect(engine.languages, isEmpty);
    });

    test(
      'no en-GB voice: false, null name, still speaks with en-GB language',
      () async {
        final engine = FakeTtsEngine(
          voices: [iosVoice('Samantha', locale: 'en-US')],
        );
        final voice = SystemVoiceService(engine: engine);
        expect(await voice.hasBritishVoice(), isFalse);
        expect(await voice.voiceName(), isNull);
        await voice.speak('bath');
        await voice.speak('path');
        expect(engine.spoken, ['bath', 'path']);
        expect(engine.languages, ['en-GB'], reason: 'fallback applied once');
      },
    );

    test('getVoices failure counts as no voice', () async {
      final engine = FakeTtsEngine()..throwOnVoices = true;
      final voice = SystemVoiceService(engine: engine);
      expect(await voice.hasBritishVoice(), isFalse);
      await voice.speak('bath');
      expect(engine.spoken, ['bath']);
    });

    test('rejected or failing setVoice falls back to the language', () async {
      final engine = FakeTtsEngine(voices: [daniel])..acceptVoice = false;
      await SystemVoiceService(engine: engine).speak('bath');
      expect(engine.languages, ['en-GB']);

      final throwing = FakeTtsEngine(voices: [daniel])
        ..throwOnSetVoice = true
        ..throwOnSetLanguage = true;
      await SystemVoiceService(engine: throwing).speak('bath');
      expect(throwing.spoken, ['bath']);
    });

    test('rescan picks up a newly installed voice', () async {
      final engine = FakeTtsEngine();
      final voice = SystemVoiceService(engine: engine);
      expect(await voice.hasBritishVoice(), isFalse);
      engine.installed = [daniel];
      expect(await voice.hasBritishVoice(), isTrue);
      await voice.speak('bath');
      expect(engine.voicesSet, [daniel]);
    });

    test('the first speak scans voices once', () async {
      final engine = FakeTtsEngine(voices: [daniel]);
      final voice = SystemVoiceService(engine: engine);
      await voice.speak('a');
      await voice.speak('b');
      expect(engine.voicesCalls, 1);
    });
  });

  group('rates', () {
    test('Android: 1.0 -> 0.5 and 0.6 -> 0.3', () async {
      final engine = FakeTtsEngine(voices: [daniel]);
      final voice = SystemVoiceService(
        engine: engine,
        platform: TargetPlatform.android,
      );
      await voice.speak('Thursday');
      await voice.speak('Thursday', rate: VoiceService.slowRate);
      expect(engine.rates[0], 0.5);
      expect(engine.rates[1], closeTo(0.3, 1e-9));
    });

    test('iOS: 1.0 -> 0.5 and 0.6 -> 0.35', () async {
      final engine = FakeTtsEngine(voices: [daniel]);
      final voice = SystemVoiceService(
        engine: engine,
        platform: TargetPlatform.iOS,
      );
      await voice.speak('Thursday');
      await voice.speak('Thursday', rate: VoiceService.slowRate);
      expect(engine.rates[0], 0.5);
      expect(engine.rates[1], closeTo(0.35, 1e-9));
    });

    test('invalid rates throw before anything is spoken', () async {
      final engine = FakeTtsEngine(voices: [daniel]);
      final voice = SystemVoiceService(engine: engine);
      for (final r in [0.0, 0.09, 2.01, double.nan, -1.0]) {
        await expectLater(voice.speak('bath', rate: r), throwsArgumentError);
      }
      expect(engine.spoken, isEmpty);
      await voice.speak('bath', rate: 0.1);
      await voice.speak('bath', rate: 2.0);
      expect(engine.spoken, hasLength(2));
    });
  });

  group('speaking', () {
    test('word and sentence are passed through unchanged', () async {
      final engine = FakeTtsEngine(voices: [daniel]);
      final voice = SystemVoiceService(engine: engine);
      await voice.speak('Thursday');
      await voice.speak('We passed an old castle and a farm.');
      expect(engine.spoken, [
        'Thursday',
        'We passed an old castle and a farm.',
      ]);
    });

    test('empty and whitespace text complete without speaking', () async {
      final engine = FakeTtsEngine(voices: [daniel]);
      final voice = SystemVoiceService(engine: engine);
      await voice.speak('');
      await voice.speak('  \n');
      expect(engine.spoken, isEmpty);
    });

    test('speak waits for the completion event', () async {
      final engine = FakeTtsEngine(voices: [daniel], autoComplete: false);
      final voice = SystemVoiceService(engine: engine);
      var done = false;
      final f = voice.speak('bath').then((_) => done = true);
      await pumpEventQueue();
      expect(engine.spoken, ['bath']);
      expect(done, isFalse);
      engine.emit(TtsEvent.completed);
      await f;
      expect(done, isTrue);
    });

    test('an error event also completes speak', () async {
      final engine = FakeTtsEngine(voices: [daniel], autoComplete: false);
      final voice = SystemVoiceService(engine: engine);
      final f = voice.speak('bath');
      await pumpEventQueue();
      engine.emit(TtsEvent.error);
      await f;
    });

    test('an outside cancel (e.g. audio focus loss) completes speak', () async {
      final engine = FakeTtsEngine(voices: [daniel], autoComplete: false);
      final voice = SystemVoiceService(engine: engine);
      final f = voice.speak('bath');
      await pumpEventQueue();
      engine.emit(TtsEvent.cancelled);
      await f;
    });

    test('stop completes a pending speak', () async {
      final engine = FakeTtsEngine(voices: [daniel], autoComplete: false);
      final voice = SystemVoiceService(engine: engine);
      final f = voice.speak('bath');
      await pumpEventQueue();
      await voice.stop();
      await f;
      expect(engine.stopCount, greaterThanOrEqualTo(2));
    });

    test(
      'a new speak stops the old one and is not ended by its late cancel',
      () async {
        final engine = FakeTtsEngine(voices: [daniel], autoComplete: false);
        final voice = SystemVoiceService(engine: engine);
        final first = voice.speak('bath');
        await pumpEventQueue();
        var secondDone = false;
        final second = voice.speak('path').then((_) => secondDone = true);
        await first;
        await pumpEventQueue(); // the stale cancel arrives here
        expect(engine.spoken, ['bath', 'path']);
        expect(secondDone, isFalse);
        engine.emit(TtsEvent.completed);
        await second;
      },
    );

    test('stop during voice set-up cancels the utterance', () async {
      final engine = _SlowVoicesEngine([daniel]);
      final voice = SystemVoiceService(engine: engine);
      final f = voice.speak('bath');
      await voice.stop();
      engine.release.complete();
      await f;
      expect(engine.spoken, isEmpty);
    });

    test('engine refusing to speak completes at once', () async {
      final engine = FakeTtsEngine(voices: [daniel])..acceptSpeak = false;
      await SystemVoiceService(engine: engine).speak('bath');
      expect(engine.spoken, isEmpty);
    });

    test('engine throwing on speak completes at once', () async {
      final engine = FakeTtsEngine(voices: [daniel])..throwOnSpeak = true;
      await SystemVoiceService(engine: engine).speak('bath');
    });

    test('stop is safe when the engine throws', () async {
      final engine = FakeTtsEngine(voices: [daniel])..throwOnStop = true;
      final voice = SystemVoiceService(engine: engine);
      await voice.stop();
      await voice.speak('bath');
      expect(engine.spoken, ['bath']);
    });

    test('a lost completion event times out', () {
      fakeAsync((async) {
        final engine = FakeTtsEngine(voices: [daniel], autoComplete: false);
        final voice = SystemVoiceService(
          engine: engine,
          timeout: (text, rate) => const Duration(seconds: 2),
        );
        var done = false;
        unawaited(voice.speak('bath').then((_) => done = true));
        async.elapse(const Duration(seconds: 1));
        expect(done, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(done, isTrue);
      });
    });

    test('default timeout grows with text length and slowness', () {
      expect(defaultSpeechTimeout('', 1.0), const Duration(seconds: 5));
      expect(
        defaultSpeechTimeout('x' * 100, 0.5),
        const Duration(milliseconds: 5000 + 30000),
      );
    });

    test('dispose stops and detaches', () async {
      final engine = FakeTtsEngine(voices: [daniel]);
      final voice = SystemVoiceService(engine: engine);
      await voice.dispose();
      expect(engine.stopCount, 1);
    });
  });
}

/// Holds getVoices until [release] completes.
class _SlowVoicesEngine extends FakeTtsEngine {
  _SlowVoicesEngine(List<TtsVoice> voices) : super(voices: voices);
  final release = Completer<void>();

  @override
  Future<List<TtsVoice>> voices() async {
    await release.future;
    return super.voices();
  }
}
