import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

/// Shared behaviour every [AudioRecorder] must have.
///
/// [create] must return a fresh recorder whose microphone permission is already
/// granted (A1 runs this on a device/emulator in integration_test/A1-audio/ with fixture
/// audio injected; the fake runs it in test/contracts/fakes_contract_test.dart).
/// [recordFor] is how long each test recording lasts.
void runAudioRecorderContract(
  Future<AudioRecorder> Function() create, {
  Duration recordFor = const Duration(milliseconds: 300),
}) {
  group('AudioRecorder contract', () {
    late AudioRecorder recorder;

    setUp(() async => recorder = await create());
    tearDown(() async {
      await recorder.cancel();
      await recorder.dispose();
    });

    test('permission is granted for the suite', () async {
      expect(await recorder.checkPermission(), MicPermission.granted);
      expect(await recorder.requestPermission(), MicPermission.granted);
    });

    test('streams are broadcast', () {
      expect(recorder.level.isBroadcast, isTrue);
      expect(recorder.silenceDetected.isBroadcast, isTrue);
    });

    test('start then stop returns a 16 kHz clip', () async {
      expect(recorder.isRecording, isFalse);
      await recorder.start();
      expect(recorder.isRecording, isTrue);
      await Future<void>.delayed(recordFor);
      final clip = await recorder.stop();
      expect(recorder.isRecording, isFalse);
      expect(clip.path, isNotEmpty);
      expect(clip.sampleRate, 16000);
      expect(clip.duration, greaterThanOrEqualTo(Duration.zero));
      if (clip.peakDbfs != null) {
        expect(clip.peakDbfs, lessThanOrEqualTo(0));
      }
    });

    test('level values stay within 0..1 while recording', () async {
      final values = <double>[];
      final sub = recorder.level.listen(values.add);
      await recorder.start();
      await Future<void>.delayed(recordFor);
      await recorder.stop();
      await sub.cancel();
      for (final v in values) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });

    test('stop without start throws StateError', () async {
      await expectLater(recorder.stop(), throwsStateError);
    });

    test('start twice throws StateError', () async {
      await recorder.start();
      await expectLater(recorder.start(), throwsStateError);
      await recorder.cancel();
    });

    test('cancel is safe when idle and stops a recording', () async {
      await recorder.cancel();
      expect(recorder.isRecording, isFalse);
      await recorder.start();
      await recorder.cancel();
      expect(recorder.isRecording, isFalse);
    });

    test('can record again after stop', () async {
      await recorder.start();
      await recorder.stop();
      await recorder.start();
      expect(recorder.isRecording, isTrue);
      await recorder.stop();
    });

    test('speechSegments are sorted, disjoint and inside the clip', () async {
      await recorder.start();
      await Future<void>.delayed(recordFor);
      final clip = await recorder.stop();
      final segments = await recorder.speechSegments(clip);
      Duration? previousEnd;
      for (final s in segments) {
        expect(s.start, greaterThanOrEqualTo(Duration.zero));
        expect(s.start, lessThan(s.end));
        expect(s.end, lessThanOrEqualTo(clip.duration));
        if (previousEnd != null) {
          expect(s.start, greaterThanOrEqualTo(previousEnd));
        }
        previousEnd = s.end;
      }
    });
  });
}
