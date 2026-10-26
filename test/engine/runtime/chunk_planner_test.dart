import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/runtime/chunk_planner.dart';

/// Voice-activity probabilities, one per 512-sample chunk (32 ms): [speechMs] of
/// speech then [pauseMs] of silence, repeated.
List<double> pattern(List<(int speechMs, int pauseMs)> parts) => [
  for (final (speech, pause) in parts) ...[
    for (var i = 0; i < speech ~/ 32; i++) 0.9,
    for (var i = 0; i < pause ~/ 32; i++) 0.05,
  ],
];

/// Feeds [probabilities] as blocks of [perBlock] chunks; returns all cuts.
List<int> feed(
  ChunkPlanner planner,
  List<double> probabilities, {
  int perBlock = 3,
}) {
  final cuts = <int>[];
  for (var i = 0; i < probabilities.length; i += perBlock) {
    final end = (i + perBlock).clamp(0, probabilities.length);
    final block = probabilities.sublist(i, end);
    cuts.addAll(planner.add(block.length * 512, block));
  }
  return cuts;
}

void main() {
  test('framesForSamples matches wav2vec2 frame maths', () {
    expect(framesForSamples(0), 1);
    expect(framesForSamples(399), 1);
    expect(framesForSamples(400), 1);
    expect(framesForSamples(16000), 49);
    expect(framesForSamples(20 * 16000), 999);
  });

  test('LiveChunking context is whole frames, at least one', () {
    expect(const LiveChunking().contextSamples, 2560);
    expect(const LiveChunking(context: Duration.zero).contextSamples, 320);
    expect(const LiveChunking().samples(const Duration(seconds: 1)), 16000);
  });

  test('cuts half-way into the first 300 ms of each pause after speech', () {
    final planner = ChunkPlanner();
    // 2 s speech, 600 ms pause, 2 s speech, 600 ms pause.
    final cuts = feed(planner, pattern([(2016, 608), (2016, 608)]));
    expect(cuts, hasLength(2));
    // Pause starts at chunk 63 (2016 ms = 32256 samples); cut at +150 ms.
    expect(cuts.first, (32256 + 2400) ~/ 320 * 320);
    for (final c in cuts) {
      expect(c % frameSamples, 0);
    }
    expect(planner.lastCut, cuts.last);
    expect(
      planner.totalSamples,
      pattern([(2016, 608), (2016, 608)]).length * 512,
    );
  });

  test('no cut for short pauses, leading silence or pieces under minChunk', () {
    final planner = ChunkPlanner();
    expect(feed(planner, pattern([(0, 2000)])), isEmpty, reason: 'no speech');
    expect(
      feed(planner, pattern([(1504, 256), (1504, 256)])),
      isEmpty,
      reason: 'pauses under 300 ms',
    );
    final short = ChunkPlanner(
      const LiveChunking(minChunk: Duration(seconds: 3)),
    );
    // A pause after 1 s of speech is too early; the next one (after 3.6 s) cuts.
    final cuts = feed(short, pattern([(992, 416), (2016, 416)]));
    expect(cuts, hasLength(1));
    expect(cuts.single, greaterThan(48000));
  });

  test('forces a cut at the quietest point of a long piece', () {
    final planner = ChunkPlanner(
      const LiveChunking(maxChunk: Duration(seconds: 4)),
    );
    final probs = [for (var i = 0; i < 200; i++) i == 110 ? 0.4 : 0.9];
    final cuts = feed(planner, probs, perBlock: 7);
    expect(cuts, isNotEmpty);
    // Chunk 110 is the quietest within 2 s before the 4 s mark (chunk 125).
    expect(cuts.first, (110 * 512 + 256) ~/ 320 * 320);
    expect(planner.speechFrom(cuts.first), isTrue);
    for (var i = 1; i < cuts.length; i++) {
      expect(cuts[i] - cuts[i - 1], lessThanOrEqualTo(4 * 16000 + 512));
    }
  });

  test('a forced cut with no quieter point lands at the current chunk', () {
    final planner = ChunkPlanner(
      const LiveChunking(
        maxChunk: Duration(seconds: 1),
        forcedCutWindow: Duration(milliseconds: 32),
      ),
    );
    final cuts = feed(planner, [for (var i = 0; i < 40; i++) 0.9]);
    expect(cuts, isNotEmpty);
    expect(cuts.first % frameSamples, 0);
  });

  test('blocks without probabilities only count samples', () {
    final planner = ChunkPlanner();
    expect(planner.add(1000, const []), isEmpty);
    expect(planner.totalSamples, 1000);
    expect(planner.speechFrom(0), isTrue, reason: 'unknown counts as speech');
  });

  test('speechFrom looks at analysed chunks only', () {
    final planner = ChunkPlanner();
    feed(planner, pattern([(1024, 1024)]));
    expect(planner.speechFrom(0), isTrue);
    expect(planner.speechFrom(1024 * 16 + 512), isFalse);
    expect(planner.speechFrom(10 * 16000), isFalse);
  });
}
