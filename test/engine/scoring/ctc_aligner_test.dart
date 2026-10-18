import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

/// Frames over vocab [blank, a, b, c] where frame t is (almost surely) ids[t].
List<Float32List> framesOf(List<int> ids) => [
  for (final id in ids)
    Float32List.fromList([
      for (var k = 0; k < 4; k++) math.log(k == id ? 0.97 : 0.01),
    ]),
];

void main() {
  const a = PhonemeUnit([1]);
  const b = PhonemeUnit([2]);
  const c = PhonemeUnit([3]);

  CtcAlignment? run(
    List<int> ids,
    List<PhonemeUnit> units,
    List<int> words, {
    double penalty = 2,
  }) => alignCtc(
    frames: framesOf(ids),
    blankIndex: 0,
    units: units,
    wordUnitCounts: words,
    skipPenalty: penalty,
  );

  test('aligns each unit to its frames, blanks optional', () {
    final r = run([0, 1, 1, 2, 2, 0, 3, 0], [a, b, c], [2, 1])!;
    expect(r.unitStart, [1, 3, 6]);
    expect(r.unitEnd, [3, 5, 7]);
    expect(r.skipped, [false, false]);
    expect(r.stateOfFrame, [0, 1, 1, 3, 3, 4, 5, 6]);
    expect(r.logScore, lessThan(0));
  });

  test('ends on the last unit when there is no trailing blank', () {
    final r = run([1, 2], [a, b], [2])!;
    expect(r.unitStart, [0, 1]);
    expect(r.stateOfFrame, [1, 3]);
  });

  test('a repeated unit needs a blank in between', () {
    final r = run([1, 1, 0, 1], [a, a], [2])!;
    expect(r.unitStart, [0, 3]);
    expect(r.stateOfFrame[2], 2);
    // Without a blank frame the repeat cannot be split: the word is skipped.
    expect(run([1, 1], [a, a], [2])!.skipped, [true]);
  });

  test('skips a word that was not said', () {
    final r = run([0, 1, 0, 0, 3, 0], [a, b, c], [1, 1, 1])!;
    expect(r.skipped, [false, true, false]);
    expect(r.unitStart, [1, -1, 4]);
    expect(r.unitEnd[1], -1);
  });

  test('skips the first and last words', () {
    final r = run([0, 0, 2, 0, 0], [a, b, c], [1, 1, 1])!;
    expect(r.skipped, [true, false, true]);
    expect(r.unitStart[1], 2);
  });

  test('skips several words in a row and right after a unit', () {
    final r = run([1, 0, 0, 0], [a, b, c], [1, 1, 1])!;
    expect(r.skipped, [false, true, true]);
  });

  test('skips from the end of the previous word without a blank frame', () {
    final r = run([1, 0, 3], [a, b, c], [1, 1, 1], penalty: 1)!;
    expect(r.skipped, [false, true, false]);
  });

  test('a high skip penalty forces a weak alignment instead', () {
    final r = run([0, 1, 0, 0, 3, 0], [a, b, c], [1, 1, 1], penalty: 100)!;
    expect(r.skipped, [false, false, false]);
    expect(r.unitStart[1], isNot(-1));
  });

  test('returns null when nothing fits', () {
    expect(run([], [a], [1]), isNull);
    expect(run([1], [], []), isNull);
  });

  test('every word can be skipped, one frame per skipped word', () {
    expect(run([0, 0], [a, b], [1, 1])!.skipped, [true, true]);
    expect(run([0], [a, b], [1, 1]), isNull);
  });
}
