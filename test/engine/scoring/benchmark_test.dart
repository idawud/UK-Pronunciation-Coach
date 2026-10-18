import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import 'support/synth.dart';

/// A 200-word passage built from the river sample's words.
Passage longPassage() {
  final words = <WordSpec>[
    for (var i = 0; i < 200; i++)
      riverPassage.words[i % riverPassage.words.length].copyWith(
        index: i,
        offset: null,
      ),
  ];
  return Passage(
    id: 'bench-200',
    level: 6,
    title: 'Benchmark',
    text: words.map((w) => w.text).join(' '),
    words: words,
  );
}

void main() {
  test('scoring 200 words takes < 100 ms (real 392-symbol vocab)', () {
    final p = longPassage();
    // ~150 wpm: 5 frames per phoneme plus 3-frame gaps, a few substitutions.
    final s = Synth()..blank(10);
    for (final w in p.words) {
      s.say(
        w,
        frames: 5,
        gap: 3,
        subs: w.index % 17 == 0 ? {0: 't'} : const {},
      );
    }
    s.blank(10);
    final post = s.build();
    final speech = [frameSegment(5, post.frames.length - 5)];
    const scorer = GopPronunciationScorer();

    // Warm up the JIT (the app runs AOT-compiled code, which needs none).
    for (var i = 0; i < 3; i++) {
      scorer.score(p, post, speech);
    }
    final times = <int>[];
    late AttemptResult r;
    for (var i = 0; i < 7; i++) {
      final sw = Stopwatch()..start();
      r = scorer.score(p, post, speech);
      times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    final median = times[times.length ~/ 2] / 1000;
    // ignore: avoid_print
    print(
      'benchmark: 200 words, ${post.frames.length} frames x '
      '${post.vocab.length} symbols: median ${median.toStringAsFixed(1)} ms '
      '(min ${(times.first / 1000).toStringAsFixed(1)} ms)',
    );
    expect(r.words, hasLength(200));
    expect(r.accuracy, greaterThan(80));
    expect(median, lessThan(100));
  });
}
