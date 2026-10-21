// Timing test: tagged `perf`, so scripts/check.sh and CI run it on its own, after
// the parallel test run, instead of next to hundreds of other tests.
@Tags(['perf'])
library;

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

/// Median time of [runs] calls of [body], in ms, after [warmUp] calls; the best of
/// [rounds] such medians, so one burst of load from other processes cannot fail the
/// gate while a consistently slow scorer still does.
double bestMedianMs(
  void Function() body, {
  int warmUp = 3,
  int runs = 7,
  int rounds = 3,
}) {
  // Warm up the JIT (the app runs AOT-compiled code, which needs none).
  for (var i = 0; i < warmUp; i++) {
    body();
  }
  var best = double.infinity;
  for (var round = 0; round < rounds; round++) {
    final times = <int>[];
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      body();
      times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    final median = times[times.length ~/ 2] / 1000;
    if (median < best) best = median;
  }
  return best;
}

({PhonemePosteriors post, List<Segment> speech}) readAloud(Passage p) {
  // ~150 wpm: 5 frames per phoneme plus 3-frame gaps, a few substitutions.
  final s = Synth()..blank(10);
  for (final w in p.words) {
    s.say(w, frames: 5, gap: 3, subs: w.index % 17 == 0 ? {0: 't'} : const {});
  }
  s.blank(10);
  final post = s.build();
  return (post: post, speech: [frameSegment(5, post.frames.length - 5)]);
}

void main() {
  const scorer = GopPronunciationScorer();

  test('scoring 200 words takes < 100 ms (real 392-symbol vocab)', () {
    final p = longPassage();
    final (:post, :speech) = readAloud(p);
    late AttemptResult r;
    final ms = bestMedianMs(() => r = scorer.score(p, post, speech));
    // ignore: avoid_print
    print(
      'benchmark: 200 words, ${post.frames.length} frames x '
      '${post.vocab.length} symbols: median ${ms.toStringAsFixed(1)} ms',
    );
    expect(r.words, hasLength(200));
    expect(r.accuracy, greaterThan(80));
    expect(ms, lessThan(100));
  });

  test('200 words with alternatives on every 4th word take < 100 ms', () {
    final base = longPassage();
    final p = base.copyWith(
      words: [
        for (final w in base.words)
          w.index % 4 == 0
              ? w.copyWith(
                  // Says "Thursday" as /di/, "we" as /wɪ/: a plausible variant.
                  alternatives: [
                    [
                      for (final ph in w.phonemes)
                        ph.ipa == 'eɪ' || ph.ipa == 'iː'
                            ? ph.copyWith(ipa: 'ɪ')
                            : ph,
                    ],
                  ],
                )
              : w,
      ],
    );
    final (:post, :speech) = readAloud(base);
    late AttemptResult r;
    final ms = bestMedianMs(() => r = scorer.score(p, post, speech));
    // ignore: avoid_print
    print('benchmark with alternatives: median ${ms.toStringAsFixed(1)} ms');
    expect(r.words, hasLength(200));
    expect(r.accuracy, greaterThan(80));
    expect(ms, lessThan(100));
  });
}
