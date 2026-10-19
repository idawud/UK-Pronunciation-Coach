import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/segment.dart';
import 'package:uk_pronunciation_coach/engine/audio/vad.dart';

import 'helpers/host.dart';

/// 32 ms chunks: [speech] chunks become 0.9, others 0.05.
List<double> _probs(int n, Set<int> speech) => [
  for (var i = 0; i < n; i++) speech.contains(i) ? 0.9 : 0.05,
];

Set<int> _range(int from, int to) => {for (var i = from; i < to; i++) i};

Duration _ms(int ms) => Duration(milliseconds: ms);

/// Replays fixed probabilities.
class _ScriptedModel implements SpeechProbabilityModel {
  _ScriptedModel(this.values);
  final List<double> values;
  int calls = 0;
  int resets = 0;
  final chunks = <Float32List>[];

  @override
  int get chunkSamples => 4;

  @override
  double process(Float32List chunk) {
    chunks.add(Float32List.fromList(chunk));
    return values[calls++ % values.length];
  }

  @override
  void reset() => resets++;

  @override
  void close() {}
}

void main() {
  group('speechSegmentsFromProbabilities', () {
    const clip = Duration(seconds: 5);

    test('no speech gives no segments', () {
      expect(speechSegmentsFromProbabilities([], clipDuration: clip), isEmpty);
      expect(
        speechSegmentsFromProbabilities(_probs(100, {}), clipDuration: clip),
        isEmpty,
      );
    });

    test('one region is padded by 150 ms', () {
      // Chunks 20..49 = 640..1600 ms.
      final s = speechSegmentsFromProbabilities(
        _probs(100, _range(20, 50)),
        clipDuration: clip,
      );
      expect(s, [Segment(start: _ms(490), end: _ms(1750))]);
    });

    test('padding is clamped to the clip', () {
      final s = speechSegmentsFromProbabilities(
        _probs(40, _range(0, 40)),
        clipDuration: const Duration(milliseconds: 1250),
      );
      expect(s, [Segment(start: Duration.zero, end: _ms(1250))]);
    });

    test('regions closer than twice the pad merge; far ones do not', () {
      final s = speechSegmentsFromProbabilities(
        _probs(150, {
          ..._range(10, 20),
          ..._range(28, 40),
          ..._range(100, 120),
        }),
        clipDuration: clip,
      );
      expect(s, [
        Segment(start: _ms(170), end: _ms(1430)),
        Segment(start: _ms(3050), end: _ms(3990)),
      ]);
    });

    test('short blips are dropped; short dips do not split', () {
      final s = speechSegmentsFromProbabilities(
        _probs(100, {5, 6, ..._range(30, 45), ..._range(47, 60)}),
        clipDuration: clip,
      );
      // Dip at 45..46 is 64 ms < 100 ms min silence; 5..6 is 64 ms < 250 ms.
      expect(s, [Segment(start: _ms(810), end: _ms(2070))]);
    });

    test('ambiguous chunks keep speech going; speech to the end closes', () {
      final p = _probs(60, _range(10, 60));
      for (var i = 20; i < 30; i++) {
        p[i] = 0.4;
      }
      final s = speechSegmentsFromProbabilities(p, clipDuration: _ms(1920));
      expect(s, [Segment(start: _ms(170), end: _ms(1920))]);
    });

    test('custom settings', () {
      final s = speechSegmentsFromProbabilities(
        _probs(50, _range(10, 20)),
        clipDuration: clip,
        chunkSamples: 160,
        settings: const VadSettings(
          pad: Duration.zero,
          minSpeech: Duration.zero,
        ),
      );
      expect(s, [Segment(start: _ms(100), end: _ms(200))]);
    });
  });

  group('SilenceTimer', () {
    test('fires once after 2 s of silence that follows speech', () {
      final t = SilenceTimer();
      for (var i = 0; i < 100; i++) {
        expect(t.add(0.01), isFalse, reason: 'no speech yet');
      }
      for (var i = 0; i < 8; i++) {
        t.add(0.9);
      }
      expect(t.heardSpeech, isTrue);
      var firedAt = -1;
      for (var i = 0; i < 200; i++) {
        if (t.add(0.01)) {
          expect(firedAt, -1);
          firedAt = i;
        }
      }
      // 63 chunks * 32 ms = 2016 ms.
      expect(firedAt, 62);
      expect(t.fired, isTrue);
      expect(t.add(0.9), isFalse);
      t.reset();
      expect(t.fired, isFalse);
      expect(t.heardSpeech, isFalse);
    });

    test('needs 250 ms of speech; ambiguous chunks restart the count', () {
      final t = SilenceTimer();
      for (var i = 0; i < 7; i++) {
        t.add(0.9);
      }
      expect(t.heardSpeech, isFalse);
      t.add(0.9);
      for (var i = 0; i < 60; i++) {
        expect(t.add(0.01), isFalse);
      }
      t.add(0.4);
      for (var i = 0; i < 62; i++) {
        expect(t.add(0.01), isFalse);
      }
      expect(t.add(0.01), isTrue);
    });
  });

  group('ChunkedVad', () {
    test('buffers arbitrary blocks into model chunks and flushes', () {
      final m = _ScriptedModel([0.1, 0.9]);
      final v = ChunkedVad(m);
      expect(v.add(Float32List.fromList([1, 2, 3])), isEmpty);
      expect(v.add(Float32List.fromList([4, 5, 6, 7, 8, 9])), [0.1, 0.9]);
      expect(m.chunks[1], [5, 6, 7, 8]);
      expect(v.flush(), [0.1]);
      expect(m.chunks[2], [9, 0, 0, 0]);
      expect(v.flush(), isEmpty);
      expect(v.probabilities, [0.1, 0.9, 0.1]);
      v.reset();
      expect(v.probabilities, isEmpty);
      expect(m.resets, 1);
    });

    test('probabilitiesOf resets and zero-pads the last chunk', () {
      final m = _ScriptedModel([0.3]);
      expect(probabilitiesOf(m, Float32List(9)), [0.3, 0.3, 0.3]);
      expect(m.resets, 1);
      expect(m.chunks.last.length, 4);
    });
  });

  group('energy fallback', () {
    test(
      'finds the read in the clean fixture and nothing in silence/noise',
      () async {
        const backend = EnergyVadBackend();
        expect(backend.name, 'energy');
        Future<List<Segment>> seg(String name) async {
          final a = fixture(name);
          return speechSegmentsFromProbabilities(
            await backend.analyse(a.samples),
            clipDuration: a.duration,
            chunkSamples: backend.chunkSamples,
          );
        }

        final clean = await seg('clean_read.wav');
        expect(clean, isNotEmpty);
        // Manifest: speech ~300-2320 ms.
        expect(clean.first.start.inMilliseconds, inInclusiveRange(0, 400));
        expect(clean.last.end.inMilliseconds, inInclusiveRange(2200, 2700));
        expect(await seg('silence.wav'), isEmpty);
        expect(await seg('noise.wav'), isEmpty);
      },
    );

    test('model resets and closes', () {
      final m = EnergySpeechModel();
      expect(m.process(Float32List(512)), 0);
      m
        ..reset()
        ..close();
      final loud = Float32List(512)..fillRange(0, 512, 0.3);
      expect(m.process(loud), lessThan(0.5), reason: 'floor starts at it');
    });
  });
}
