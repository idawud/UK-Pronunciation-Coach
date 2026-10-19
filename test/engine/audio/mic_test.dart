import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart' as rec;
import 'package:uk_pronunciation_coach/core/models/enums.dart';
import 'package:uk_pronunciation_coach/engine/audio/fixture_mic.dart';
import 'package:uk_pronunciation_coach/engine/audio/mic.dart';
import 'package:uk_pronunciation_coach/engine/audio/wav.dart';

class _MockRecord extends Mock implements rec.AudioRecorder {}

void main() {
  setUpAll(() => registerFallbackValue(const rec.RecordConfig()));

  test('micPermissionFrom maps every status', () {
    expect(
      micPermissionFrom(ph.PermissionStatus.granted),
      MicPermission.granted,
    );
    expect(
      micPermissionFrom(ph.PermissionStatus.limited),
      MicPermission.granted,
    );
    expect(
      micPermissionFrom(ph.PermissionStatus.provisional),
      MicPermission.granted,
    );
    expect(micPermissionFrom(ph.PermissionStatus.denied), MicPermission.denied);
    expect(
      micPermissionFrom(ph.PermissionStatus.permanentlyDenied),
      MicPermission.permanentlyDenied,
    );
    expect(
      micPermissionFrom(ph.PermissionStatus.restricted),
      MicPermission.permanentlyDenied,
    );
  });

  group('PermissionHandlerMicPermissions', () {
    test('prompts only from denied', () async {
      var status = ph.PermissionStatus.denied;
      var prompts = 0;
      final p = PermissionHandlerMicPermissions(
        readStatus: () async => status,
        requestStatus: () async {
          prompts++;
          return status = ph.PermissionStatus.granted;
        },
        openAppSettings: () async => true,
      );
      expect(await p.status(), MicPermission.denied);
      expect(await p.request(), MicPermission.granted);
      expect(await p.request(), MicPermission.granted);
      expect(prompts, 1);
      status = ph.PermissionStatus.permanentlyDenied;
      expect(await p.request(), MicPermission.permanentlyDenied);
      expect(prompts, 1);
      expect(await p.openSettings(), isTrue);
    });

    test('a denied prompt and a failing settings call', () async {
      final p = PermissionHandlerMicPermissions(
        readStatus: () async => ph.PermissionStatus.denied,
        requestStatus: () async => ph.PermissionStatus.permanentlyDenied,
        openAppSettings: () async => throw Exception('no settings app'),
      );
      expect(await p.request(), MicPermission.permanentlyDenied);
      expect(await p.openSettings(), isFalse);
    });

    test('defaults to the plug-in', () {
      expect(PermissionHandlerMicPermissions(), isA<MicPermissions>());
    });
  });

  group('RecordMicSource', () {
    test('streams 16 kHz mono PCM16 with processing off', () async {
      final r = _MockRecord();
      final data = Stream<Uint8List>.value(Uint8List(4));
      when(() => r.startStream(any())).thenAnswer((_) async => data);
      when(r.stop).thenAnswer((_) async => null);
      when(r.dispose).thenAnswer((_) async {});
      final mic = RecordMicSource(r);
      expect(await mic.start(sampleRate: 16000), same(data));
      final config =
          verify(() => r.startStream(captureAny())).captured.single
              as rec.RecordConfig;
      expect(config.encoder, rec.AudioEncoder.pcm16bits);
      expect(config.sampleRate, 16000);
      expect(config.numChannels, 1);
      expect(config.autoGain, isFalse);
      expect(config.echoCancel, isFalse);
      expect(config.noiseSuppress, isFalse);
      expect(
        config.androidConfig.audioSource,
        rec.AndroidAudioSource.voiceRecognition,
      );
      await mic.stop();
      await mic.dispose();
      verify(r.stop).called(1);
      verify(r.dispose).called(1);
    });
  });

  group('FixtureMicSource', () {
    test('delivers the whole clip at once when not real time', () async {
      final mic = FixtureMicSource(
        Uint8List(1000),
        realTime: false,
        block: const Duration(milliseconds: 10),
      );
      final stream = await mic.start(sampleRate: 16000);
      final sizes = <int>[];
      final done = stream.listen((b) => sizes.add(b.length)).asFuture<void>();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await expectLater(mic.start(sampleRate: 16000), throwsStateError);
      await mic.stop();
      await done;
      expect(sizes, [320, 320, 320, 40]);
      expect(mic.starts, 1);
      await mic.dispose();
      expect(mic.disposed, isTrue);
    });

    test('paces blocks in real time, then silence', () async {
      final mic = FixtureMicSource(
        Uint8List.fromList(List.filled(640, 1)),
        startDelay: const Duration(milliseconds: 1),
      );
      final blocks = <Uint8List>[];
      final sub = (await mic.start(sampleRate: 16000)).listen(blocks.add);
      await Future<void>.delayed(const Duration(milliseconds: 130));
      await mic.stop();
      await sub.cancel();
      expect(blocks.length, greaterThanOrEqualTo(3));
      expect(blocks.first.every((b) => b == 1), isTrue);
      expect(blocks.last.every((b) => b == 0), isTrue);
    });

    test('wav factory decodes and rejects other rates', () {
      final wav = encodeWav(Float32List.fromList([0.5, -0.5]));
      expect(FixtureMicSource.wav(wav).pcm, wav.sublist(44));
      final eight = encodeWav(Float32List(2), sampleRate: 8000);
      expect(() => FixtureMicSource.wav(eight), throwsFormatException);
    });
  });

  test('FixedMicPermissions', () async {
    final p = FixedMicPermissions(MicPermission.denied, MicPermission.granted);
    expect(await p.status(), MicPermission.denied);
    expect(await p.request(), MicPermission.granted);
    expect(await p.request(), MicPermission.granted);
    expect(p.prompts, 1);
    expect(await p.openSettings(), isTrue);
    expect(p.settingsOpened, 1);
    expect(await FixedMicPermissions().status(), MicPermission.granted);
  });
}
