import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/audio/silero_vad.dart';
import 'package:uk_pronunciation_coach/engine/audio/vad.dart';

import 'helpers/host.dart';

void main() {
  final lib = hostOrtLibraryPath();
  final skipOrt = lib == null
      ? 'needs the onnxruntime_v2 Linux library (Linux hosts only)'
      : null;

  group('SileroVadModel on the tiny stand-in', skip: skipOrt, () {
    late SileroVadModel model;
    setUp(
      () => model = SileroVadModel.fromBytes(tinyVadBytes(), libraryPath: lib),
    );
    tearDown(() => model.close());

    test('scores loud chunks high and silence low', () {
      expect(model.chunkSamples, 512);
      expect(model.outputNames, ['output', 'stateN']);
      final loud = Float32List(512)..fillRange(0, 512, 0.1); // -20 dBFS
      expect(model.process(Float32List(512)), lessThan(0.01));
      // The first loud chunk still has 64 samples of silent context.
      expect(model.process(loud), greaterThan(0.99));
      model.reset();
      expect(model.process(Float32List(512)), lessThan(0.01));
    });

    test('rejects a wrong chunk size and use after close', () {
      expect(() => model.process(Float32List(100)), throwsArgumentError);
      model.close();
      model.close();
      expect(() => model.process(Float32List(512)), throwsStateError);
    });

    test('backend analyse in an isolate matches streaming', () async {
      final backend = SileroVadBackend(tinyVadBytes(), libraryPath: lib);
      expect(backend.name, 'silero');
      expect(backend.chunkSamples, 512);
      final samples = fixture('clean_read.wav').samples;
      final streamed = probabilitiesOf(backend.open(), samples);
      expect(await backend.analyse(samples), streamed);
      expect(streamed.length, (samples.length / 512).ceil());
    });
  });

  test('a model without Silero inputs is rejected', skip: skipOrt, () {
    final bad = File('test/engine/audio/fixtures/not_vad.onnx')
        .readAsBytesSync();
    expect(
      () => SileroVadModel.fromBytes(bad, libraryPath: lib),
      throwsA(isA<VadRuntimeException>()),
    );
    expect(
      () => SileroVadBackend(Uint8List.fromList([1, 2, 3]), libraryPath: lib),
      throwsA(
        isA<VadRuntimeException>().having(
          (e) => e.toString(),
          'toString',
          startsWith('VadRuntimeException: '),
        ),
      ),
    );
  });

  test('openVadOnnxRuntime with a bad path throws', () {
    expect(
      () => openVadOnnxRuntime('/nonexistent/libonnxruntime.so'),
      throwsArgumentError,
    );
  });

  // The real model: run when a developer fetched it (see docs/handoff/A1-audio.md).
  final real = cachedSileroModel();
  group(
    'real Silero VAD on the shared fixtures',
    skip: skipOrt ?? (real == null ? 'Silero model not cached' : null),
    () {
      final manifest = jsonDecode(
        File('test/fixtures/audio/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      test(
        'speech segments match the manifest; noise and silence are empty',
        () async {
          final backend = SileroVadBackend(
            real!.readAsBytesSync(),
            libraryPath: lib,
          );
          for (final name in [
            'clean_read.wav',
            'mispronounced_thursday.wav',
            'read_then_silence.wav',
            'noisy_read.wav',
            'silence.wav',
            'noise.wav',
          ]) {
            final a = fixture(name);
            final segs = speechSegmentsFromProbabilities(
              await backend.analyse(a.samples),
              clipDuration: a.duration,
            );
            final m = manifest[name] as Map<String, dynamic>;
            final expected = (m['approxSpeechMs'] as List<dynamic>)
                .cast<List<dynamic>>();
            if (name == 'silence.wav' || name == 'noise.wav') {
              expect(segs, isEmpty, reason: name);
            } else {
              final ref = expected.isEmpty ? [300, 2320] : expected.first;
              expect(segs, hasLength(1), reason: name);
              // 150 ms padding around the manifest's rough region (+-150 ms slack).
              expect(
                segs.first.start.inMilliseconds,
                inInclusiveRange((ref[0] as int) - 300, ref[0] as int),
                reason: name,
              );
              expect(
                segs.first.end.inMilliseconds,
                inInclusiveRange(ref[1] as int, (ref[1] as int) + 450),
                reason: name,
              );
            }
          }
        },
      );

      test('streaming cost per 32 ms chunk', () {
        final model = SileroVadModel.fromBytes(
          real!.readAsBytesSync(),
          libraryPath: lib,
        );
        final samples = fixture('read_then_silence.wav').samples;
        probabilitiesOf(model, samples); // warm up
        final watch = Stopwatch()..start();
        final n = probabilitiesOf(model, samples).length;
        final perChunkUs = watch.elapsedMicroseconds / n;
        model.close();
        // ignore: avoid_print
        print(
          'Silero VAD: ${(perChunkUs / 1000).toStringAsFixed(3)} ms per '
          '32 ms chunk on this host',
        );
        expect(
          perChunkUs,
          lessThan(16000),
          reason: 'must keep up in real time',
        );
      });
    },
  );
}
