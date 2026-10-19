// On-device tests for A1: the real recorder with fixture audio in place of the
// microphone, the plug-in's native ONNX Runtime running the VAD, and app-private
// storage. Never records from the real microphone and never touches the network.
//
//   flutter test integration_test/A1-audio -d <device>
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as rec;
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/audio/audio.dart';

import '../../test/contracts/audio_recorder_contract.dart';
import 'fixture_audio_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final cleanRead = base64Decode(cleanReadWavBase64);
  final tinyVad = base64Decode(tinyVadBase64);

  CoachAudioRecorder recorder(
    Uint8List wav, {
    Future<VadBackend> Function()? vad,
    bool realTime = true,
  }) => CoachAudioRecorder(
    mic: FixtureMicSource.wav(wav, realTime: realTime, silenceAfter: realTime),
    permissions: FixedMicPermissions(),
    loadVad: vad ?? loadBundledVad,
  );

  group('contract, bundled VAD (Silero if the asset was fetched)', () {
    runAudioRecorderContract(() async => recorder(cleanRead));
  });

  group('contract, Silero-shaped model on the native ONNX Runtime', () {
    runAudioRecorderContract(
      () async =>
          recorder(cleanRead, vad: () async => SileroVadBackend(tinyVad)),
    );
  });

  test('records the fixture into app support storage with quality ok', () async {
    final r = recorder(cleanRead, realTime: false);
    final watch = Stopwatch()..start();
    await r.vadName;
    final warm = watch.elapsedMilliseconds;
    watch.reset();
    await r.start();
    final startMs = watch.elapsedMilliseconds;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final clip = await r.stop();
    final support = await getApplicationSupportDirectory();
    expect(clip.path, startsWith(support.path));
    expect(clip.quality, AudioQuality.ok);
    expect(clip.duration.inMilliseconds, closeTo(3211, 1));
    watch.reset();
    final segments = await r.speechSegments(clip);
    final cachedMs = watch.elapsedMilliseconds;
    expect(segments, isNotEmpty);
    // ignore: avoid_print
    print(
      'A1 device: vad=${await r.vadName} warm-up ${warm}ms, start ${startMs}ms, '
      'segments (cached) ${cachedMs}ms: $segments',
    );
    expect(startMs, lessThan(300));
    File(clip.path).deleteSync();
    await r.dispose();
  });

  test('a quiet copy is flagged tooQuiet', () async {
    final audio = decodeWav(cleanRead);
    final quiet = Float32List.fromList([
      for (final s in audio.samples) s * 0.01,
    ]);
    final r = recorder(encodeWav(quiet), realTime: false);
    await r.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final clip = await r.stop();
    expect(clip.quality, AudioQuality.tooQuiet);
    File(clip.path).deleteSync();
    await r.dispose();
  });

  test('the record plug-in supports raw 16-bit PCM streaming', () async {
    final plugin = rec.AudioRecorder();
    expect(await plugin.isEncoderSupported(rec.AudioEncoder.pcm16bits), isTrue);
    await plugin.dispose();
  });

  test('reading the microphone permission does not prompt', () async {
    final state = await PermissionHandlerMicPermissions().status();
    expect(MicPermission.values, contains(state));
  });
}
