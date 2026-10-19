import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uk_pronunciation_coach/voice/flutter_tts_engine.dart';
import 'package:uk_pronunciation_coach/voice/tts_engine.dart';

/// Drives FlutterTtsEngine through flutter_tts's real MethodChannel with a mock
/// platform side, so the adapter's argument shapes are checked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  late List<MethodCall> calls;
  late Object? Function(MethodCall) reply;

  setUp(() {
    calls = [];
    reply = (_) => 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply(call);
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> platformSends(String method) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, true),
          ),
          (_) {},
        );
  }

  test('Android: parses voices and sets up without iOS calls', () async {
    reply = (call) => call.method == 'getVoices'
        ? [
            {
              'name': 'en-gb-x-rjs-local',
              'locale': 'en-GB',
              'quality': 'high',
              'latency': 'normal',
              'network_required': '0',
              'features': '',
            },
            'junk',
          ]
        : 1;
    final engine = FlutterTtsEngine(
      tts: FlutterTts(),
      platform: TargetPlatform.android,
    );
    final voices = await engine.voices();
    expect(voices.single.name, 'en-gb-x-rjs-local');
    expect(voices.single.quality, 'high');
    final methods = calls.map((c) => c.method).toList();
    expect(methods, ['awaitSpeakCompletion', 'getVoices']);
    expect(calls.first.arguments, false);
  });

  test('null voice list -> empty', () async {
    reply = (call) => call.method == 'getVoices' ? null : 1;
    final engine = FlutterTtsEngine(platform: TargetPlatform.android);
    expect(await engine.voices(), isEmpty);
  });

  test('iOS: shared session and playback category, once', () async {
    final engine = FlutterTtsEngine(platform: TargetPlatform.iOS);
    await engine.setRate(0.35);
    await engine.speak('bath');
    // flutter_tts skips setIosAudioCategory itself unless dart:io says iOS, so
    // on the test host it never reaches the channel.
    final methods = calls
        .map((c) => c.method)
        .where((m) => m != 'setIosAudioCategory')
        .toList();
    expect(methods, [
      'awaitSpeakCompletion',
      'setSharedInstance',
      'setSpeechRate',
      'speak',
    ]);
    expect(
      calls.firstWhere((c) => c.method == 'setSpeechRate').arguments,
      0.35,
    );
    expect(calls.last.arguments.toString(), contains('bath'));
  });

  test('setup failure is tolerated', () async {
    reply = (call) => call.method == 'awaitSpeakCompletion'
        ? throw PlatformException(code: 'x')
        : 1;
    final engine = FlutterTtsEngine(platform: TargetPlatform.android);
    expect(await engine.speak('bath'), isTrue);
  });

  test('setVoice sends the original map; results map to bools', () async {
    final engine = FlutterTtsEngine(platform: TargetPlatform.android);
    final voice = TtsVoice.fromMap({
      'name': 'Daniel',
      'locale': 'en-GB',
      'identifier': 'id',
    });
    expect(await engine.setVoice(voice), isTrue);
    final sent = calls.last.arguments as Map;
    expect(sent['identifier'], 'id');
    expect(
      await engine.setVoice(const TtsVoice(name: 'n', locale: 'en-GB')),
      isTrue,
    );
    expect(calls.last.arguments, {'name': 'n', 'locale': 'en-GB'});

    reply = (_) => 0;
    expect(await engine.setLanguage('en-GB'), isFalse);
    expect(await engine.speak('bath'), isFalse);
    reply = (_) => true;
    expect(await engine.setLanguage('en-GB'), isTrue);
    await engine.stop();
    expect(calls.last.method, 'stop');
  });

  test('platform events become TtsEvents', () async {
    final engine = FlutterTtsEngine(platform: TargetPlatform.android);
    final events = <TtsEvent>[];
    final sub = engine.events.listen(events.add);
    await platformSends('speak.onComplete');
    await platformSends('speak.onCancel');
    await platformSends('speak.onError');
    await pumpEventQueue();
    expect(events, [TtsEvent.completed, TtsEvent.cancelled, TtsEvent.error]);
    await sub.cancel();
  });
}
