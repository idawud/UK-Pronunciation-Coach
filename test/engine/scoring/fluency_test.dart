import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

/// [n] words of 300 ms with 100 ms gaps (150 wpm).
List<WordSpan> words(int n, {Map<int, int> extraGapMs = const {}}) {
  final out = <WordSpan>[];
  var t = 0;
  for (var i = 0; i < n; i++) {
    t += extraGapMs[i] ?? 0;
    out.add((word: i, startMs: t, endMs: t + 300));
    t += 400;
  }
  return out;
}

FluencyBreakdown run(
  List<WordSpan> spoken, {
  ScoringConfig config = const ScoringConfig(),
  int? total,
  int missed = 0,
  int extra = 0,
  int repeated = 0,
  List<(int, int)> silences = const [],
  Set<int> punctuation = const {},
}) => computeFluency(
  config: config,
  spoken: spoken,
  spokenWordCount: spoken.length,
  totalWords: total ?? spoken.length + missed,
  missedWords: missed,
  extraWords: extra,
  repeatedWords: repeated,
  silencesMs: silences,
  punctuationAfter: punctuation.contains,
);

void main() {
  test('a steady read at 150 wpm is fully fluent', () {
    final f = run(words(20));
    expect(f.wordsPerMinute, closeTo(151.9, 0.5));
    expect(f.rateScore, 100);
    expect(f.pauses, isEmpty);
    expect(f.pauseScore, 100);
    expect(f.continuityScore, 100);
    expect(f.score, 100);
  });

  test('too slow and too fast reads lose rate points', () {
    final slow = <WordSpan>[
      for (var i = 0; i < 10; i++)
        (word: i, startMs: i * 900, endMs: i * 900 + 450),
    ];
    final fast = <WordSpan>[
      for (var i = 0; i < 10; i++)
        (word: i, startMs: i * 200, endMs: i * 200 + 190),
    ];
    expect(run(slow).rateScore, lessThan(90));
    expect(run(fast).rateScore, lessThan(60));
    expect(run(fast).score, lessThan(run(words(10)).score));
  });

  test('too few words: rate is not judged', () {
    final f = run(words(2));
    expect(f.wordsPerMinute, isNull);
    expect(f.rateScore, 100);
  });

  test('long pauses cost points, growing with length', () {
    final short = run(words(10, extraGapMs: {5: 500}));
    final long = run(words(10, extraGapMs: {5: 3000}));
    expect(short.pauses.single.afterWord, 4);
    expect(short.pauses.single.ms, 600);
    expect(short.pauses.single.penalty, 9); // 8 + 10 * (0.6 - 0.5)
    expect(
      long.pauses.single.penalty,
      greaterThan(short.pauses.single.penalty),
    );
    expect(long.pauseScore, lessThan(short.pauseScore));
  });

  test('pauses at punctuation are free up to the allowance', () {
    final ok = run(words(10, extraGapMs: {5: 1000}), punctuation: {4});
    expect(ok.pauses.single.atPunctuation, isTrue);
    expect(ok.pauses.single.penalty, 0);
    final tooLong = run(words(10, extraGapMs: {5: 4000}), punctuation: {4});
    expect(tooLong.pauses.single.penalty, greaterThan(0));
  });

  test('VAD silences make shorter gaps count as pauses', () {
    final gap = words(10, extraGapMs: {5: 250});
    expect(run(gap).pauses, isEmpty);
    final f = run(gap, silences: [(1900, 2200)]);
    expect(f.pauses, hasLength(1));
  });

  test('missed, extra and repeated words lower continuity', () {
    final f = run(words(18), missed: 1, extra: 1, repeated: 1, total: 20);
    expect(f.continuityScore, closeTo(100 - 250 * 3 / 20, 1e-9));
    expect(f.missedWords, 1);
    expect(f.extraWords, 1);
    expect(f.repeatedWords, 1);
    expect(f.score, lessThan(100));
  });

  test('nothing said scores 0', () {
    final f = run(const [], missed: 5);
    expect(f.score, 0);
    expect(f.wordsPerMinute, isNull);
  });

  test('zero weights give 0', () {
    const c = ScoringConfig(rateWeight: 0, pauseWeight: 0, continuityWeight: 0);
    expect(run(words(5), config: c).score, 0);
  });
}
