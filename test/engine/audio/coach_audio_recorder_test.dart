import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/errors.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/audio/audio.dart';

import '../../contracts/audio_recorder_contract.dart';
import 'helpers/host.dart';

Uint8List _fixtureBytes(String name) =>
    File('test/fixtures/audio/$name').readAsBytesSync();

/// A mic whose start fails.
class _BrokenMic implements MicSource {
  bool disposed = false;
  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async =>
      throw Exception('mic busy');
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => disposed = true;
}

/// A mic driven by the test.
class _ManualMic implements MicSource {
  StreamController<Uint8List>? controller;
  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async =>
      (controller = StreamController<Uint8List>()).stream;
  @override
  Future<void> stop() async => controller?.close();
  @override
  Future<void> dispose() async {}
}

class _Bundle extends CachingAssetBundle {
  _Bundle(this.bytes);
  final Uint8List? bytes;
  @override
  Future<ByteData> load(String key) async {
    final b = bytes;
    if (b == null) throw Exception('missing $key');
    return ByteData.sublistView(b);
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('a1_rec'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  CoachAudioRecorder recorder(
    MicSource mic, {
    MicPermissions? permissions,
    Future<VadBackend> Function()? vad,
  }) => CoachAudioRecorder(
    mic: mic,
    permissions: permissions ?? FixedMicPermissions(),
    recordingsDirectory: () async => dir,
    loadVad: vad ?? () async => const EnergyVadBackend(),
    clock: () => DateTime.utc(2026, 10, 19, 9, 30),
  );

  /// Records the whole of [name] (delivered at once) and stops.
  Future<(CoachAudioRecorder, AudioClip)> recordFixture(
    String name, {
    Future<VadBackend> Function()? vad,
  }) async {
    final r = recorder(
      FixtureMicSource.wav(
        _fixtureBytes(name),
        realTime: false,
        silenceAfter: false,
      ),
      vad: vad,
    );
    await r.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return (r, await r.stop());
  }

  group('contract (energy VAD)', () {
    runAudioRecorderContract(
      () async =>
          recorder(FixtureMicSource.wav(_fixtureBytes('clean_read.wav'))),
    );
  });

  final lib = hostOrtLibraryPath();
  group(
    'contract (Silero-shaped model on ONNX Runtime)',
    skip: lib == null,
    () {
      runAudioRecorderContract(
        () async => recorder(
          FixtureMicSource.wav(_fixtureBytes('clean_read.wav')),
          vad: () async => SileroVadBackend(tinyVadBytes(), libraryPath: lib),
        ),
      );
    },
  );

  group('permissions', () {
    test('start throws MicPermissionException when not granted', () async {
      for (final state in [
        MicPermission.denied,
        MicPermission.permanentlyDenied,
      ]) {
        final mic = FixtureMicSource(Uint8List(0));
        final r = recorder(mic, permissions: FixedMicPermissions(state));
        await expectLater(
          r.start(),
          throwsA(
            isA<MicPermissionException>().having(
              (e) => e.state,
              'state',
              state,
            ),
          ),
        );
        expect(r.isRecording, isFalse);
        expect(mic.starts, 0);
        await expectLater(r.stop(), throwsStateError);
        await r.dispose();
      }
    });

    test('check, request and settings go to the adapter', () async {
      final p = FixedMicPermissions(
        MicPermission.denied,
        MicPermission.granted,
      );
      final r = recorder(FixtureMicSource(Uint8List(0)), permissions: p);
      expect(await r.checkPermission(), MicPermission.denied);
      expect(await r.requestPermission(), MicPermission.granted);
      expect(await r.openPermissionSettings(), isTrue);
      expect(p.settingsOpened, 1);
      await r.dispose();
    });
  });

  group('recording', () {
    test('discard deletes the clip file and forgets its VAD cache', () async {
      final (r, clip) = await recordFixture('clean_read.wav');
      expect(File(clip.path).existsSync(), isTrue);
      await r.discard(clip);
      expect(File(clip.path).existsSync(), isFalse);
      await r.discard(clip); // already gone: no-op
      // The cached probabilities are gone too, so speechSegments re-reads the file.
      await expectLater(
        r.speechSegments(clip),
        throwsA(isA<FileSystemException>()),
      );
      await r.dispose();
    });

    test('discard ignores a file it cannot delete', () async {
      final (r, clip) = await recordFixture('clean_read.wav');
      // A file in a read-only folder: delete() throws FileSystemException.
      final locked = Directory('${dir.path}/locked')..createSync();
      final file = File('${locked.path}/a.wav')..writeAsStringSync('x');
      Process.runSync('chmod', ['555', locked.path]);
      addTearDown(() => Process.runSync('chmod', ['755', locked.path]));
      await r.discard(AudioClip(path: file.path, duration: Duration.zero));
      await r.discard(clip);
      await r.dispose();
    }, testOn: 'linux || mac-os');

    test('writes a 16 kHz WAV identical to the input', () async {
      final (r, clip) = await recordFixture('clean_read.wav');
      expect(clip.path, startsWith(dir.path));
      expect(clip.path, endsWith('.wav'));
      expect(clip.path, contains('rec_20261019093000'));
      expect(clip.sampleRate, 16000);
      expect(clip.duration.inMilliseconds, closeTo(3211, 1));
      final written = decodeWav(File(clip.path).readAsBytesSync());
      expect(written.samples, fixture('clean_read.wav').samples);
      await r.dispose();
    });

    for (final (name, quality) in [
      ('clean_read.wav', AudioQuality.ok),
      ('quiet_read.wav', AudioQuality.tooQuiet),
      ('noisy_read.wav', AudioQuality.tooNoisy),
      ('silence.wav', AudioQuality.tooQuiet),
      ('noise.wav', AudioQuality.tooNoisy),
    ]) {
      test('quality of $name is $quality', () async {
        final (r, clip) = await recordFixture(name);
        expect(clip.quality, quality);
        expect(clip.peakDbfs, lessThanOrEqualTo(0));
        expect(clip.snrDb, isNotNull);
        await r.dispose();
      });
    }

    test('level: about 20 values per second, all within 0..1', () async {
      final (r, _) = (
        recorder(
          FixtureMicSource.wav(
            _fixtureBytes('clean_read.wav'),
            realTime: false,
            silenceAfter: false,
          ),
        ),
        null,
      );
      final values = <double>[];
      final sub = r.level.listen(values.add);
      await r.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await r.stop();
      await sub.cancel();
      // 3.211 s of audio -> 64 values.
      expect(values.length, 64);
      expect(values.every((v) => v >= 0 && v <= 1), isTrue);
      expect(values.reduce((a, b) => a > b ? a : b), greaterThan(0.5));
      expect(values.first, 0, reason: 'leading silence');
      await r.dispose();
    });

    test('silenceDetected fires once, 2 s after the read ends', () async {
      final r = recorder(
        FixtureMicSource.wav(
          _fixtureBytes('read_then_silence.wav'),
          realTime: false,
          silenceAfter: false,
        ),
      );
      var fired = 0;
      final sub = r.silenceDetected.listen((_) => fired++);
      await r.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(fired, 1);
      expect(r.isRecording, isTrue, reason: 'the caller decides to stop');
      await r.stop();
      await sub.cancel();
      await r.dispose();
    });

    test(
      'silenceDetected does not fire for silence alone or a short read',
      () async {
        for (final name in ['silence.wav', 'clean_read.wav']) {
          final r = recorder(
            FixtureMicSource.wav(
              _fixtureBytes(name),
              realTime: false,
              silenceAfter: false,
            ),
          );
          var fired = 0;
          final sub = r.silenceDetected.listen((_) => fired++);
          await r.start();
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await r.stop();
          await sub.cancel();
          expect(fired, 0, reason: name);
          await r.dispose();
        }
      },
    );

    test('start latency is well under 300 ms', () async {
      final r = recorder(FixtureMicSource.wav(_fixtureBytes('clean_read.wav')));
      await r.vadName; // the app warms the VAD up at construction
      final watch = Stopwatch()..start();
      await r.start();
      watch.stop();
      expect(watch.elapsedMilliseconds, lessThan(300));
      expect(r.lastStartLatency!.inMilliseconds, lessThan(300));
      await r.cancel();
      await r.dispose();
    });

    test('odd-sized blocks are stitched back into samples', () async {
      final mic = _ManualMic();
      final r = recorder(mic);
      await r.start();
      final pcm = encodeWav(Float32List.fromList([0.25, -0.5, 0.75]))
          .sublist(44);
      mic.controller!
        ..add(Uint8List.sublistView(pcm, 0, 3))
        ..add(Uint8List(0))
        ..add(Uint8List.sublistView(pcm, 3, 4))
        ..add(Uint8List.sublistView(pcm, 4, 6))
        ..addError(Exception('glitch'));
      await Future<void>.delayed(Duration.zero);
      final clip = await r.stop();
      final back = decodeWav(File(clip.path).readAsBytesSync()).samples;
      expect(back, [0.25, -0.5, 0.75]);
      expect(clip.snrDb, isNull, reason: 'too short to estimate');
      await r.dispose();
    });

    test(
      'cancel deletes the partial file; mic failure leaves nothing',
      () async {
        final r = recorder(
          FixtureMicSource.wav(_fixtureBytes('clean_read.wav')),
        );
        await r.start();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await r.cancel();
        expect(r.isRecording, isFalse);
        expect(dir.listSync(), isEmpty);
        await r.dispose();

        final broken = _BrokenMic();
        final b = recorder(broken);
        await expectLater(b.start(), throwsException);
        expect(b.isRecording, isFalse);
        expect(dir.listSync(), isEmpty);
        await b.dispose();
        expect(broken.disposed, isTrue);
      },
    );

    test('stop while start is in flight waits for it', () async {
      final r = recorder(
        FixtureMicSource(
          Uint8List(3200),
          startDelay: const Duration(milliseconds: 30),
        ),
      );
      final starting = r.start();
      await expectLater(r.start(), throwsStateError);
      final clip = await r.stop();
      await starting;
      expect(r.isRecording, isFalse);
      expect(File(clip.path).existsSync(), isTrue);
      await r.dispose();
    });

    test('a disposed recorder refuses to work', () async {
      final r = recorder(FixtureMicSource(Uint8List(0)));
      await r.dispose();
      await r.dispose();
      await r.cancel();
      await expectLater(r.start(), throwsStateError);
      await expectLater(r.stop(), throwsStateError);
      await expectLater(
        r.speechSegments(
          const AudioClip(path: '/x.wav', duration: Duration(seconds: 1)),
        ),
        throwsStateError,
      );
    });
  });

  group('speechSegments', () {
    test('reuses the live VAD for the clip it recorded', () async {
      final (r, clip) = await recordFixture('clean_read.wav');
      final live = await r.speechSegments(clip);
      expect(live, hasLength(1));
      // A second recorder has no cache and analyses the file: same answer.
      final other = recorder(FixtureMicSource(Uint8List(0)));
      expect(await other.speechSegments(clip), live);
      await r.dispose();
      await other.dispose();
    });

    test('clamps to the clip duration and is empty for silence', () async {
      final (r, clip) = await recordFixture('clean_read.wav');
      final short = clip.copyWith(duration: const Duration(seconds: 1));
      final segs = await r.speechSegments(short);
      expect(segs.single.end, const Duration(seconds: 1));
      final (s, silent) = await recordFixture('silence.wav');
      expect(await s.speechSegments(silent), isEmpty);
      await r.dispose();
      await s.dispose();
    });

    test('analyses fixture files and rejects other sample rates', () async {
      final r = recorder(FixtureMicSource(Uint8List(0)));
      final path = File('test/fixtures/audio/read_then_silence.wav')
          .absolute
          .path;
      final segs = await r.speechSegments(
        AudioClip(path: path, duration: const Duration(milliseconds: 5711)),
      );
      expect(segs, hasLength(1));
      final eight = File('${dir.path}/8k.wav')
        ..writeAsBytesSync(encodeWav(Float32List(800), sampleRate: 8000));
      await expectLater(
        r.speechSegments(
          AudioClip(
            path: eight.path,
            duration: const Duration(milliseconds: 100),
          ),
        ),
        throwsFormatException,
      );
      await r.dispose();
    });

    test('keeps only the last few clips in the cache', () async {
      final r = recorder(
        FixtureMicSource(
          Uint8List(32000),
          realTime: false,
          silenceAfter: false,
        ),
      );
      for (var i = 0; i < 6; i++) {
        await r.start();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await r.stop();
      }
      expect(dir.listSync().length, 6);
      await r.dispose();
    });
  });

  group('loadBundledVad', () {
    test('falls back to the energy VAD when the asset is missing', () async {
      final vad = await loadBundledVad(bundle: _Bundle(null));
      expect(vad.name, 'energy');
    });

    test('falls back when the model does not load', () async {
      final vad = await loadBundledVad(
        bundle: _Bundle(Uint8List(4)),
        open: (_) => throw const VadRuntimeException('bad model'),
      );
      expect(vad.name, 'energy');
    });

    test('loads Silero from the bundle', skip: lib == null, () async {
      final vad = await loadBundledVad(
        bundle: _Bundle(tinyVadBytes()),
        open: (b) => SileroVadBackend(b, libraryPath: lib),
      );
      expect(vad.name, 'silero');
      final r = recorder(FixtureMicSource(Uint8List(0)), vad: () async => vad);
      expect(await r.vadName, 'silero');
      await r.dispose();
    });

    test('the platform factory builds without touching the plug-ins', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(CoachAudioRecorder.platform(), isA<CoachAudioRecorder>());
    });
  });
}
