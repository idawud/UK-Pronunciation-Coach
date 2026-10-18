import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_vocab.dart';

void main() {
  group('ModelVocab', () {
    test('parses vocab.json and finds <pad> as blank', () {
      final v = ModelVocab.fromJson(
        File('test/engine/runtime/fixtures/tiny_vocab.json').readAsStringSync(),
      );
      expect(v.symbols, ['<pad>', '<s>', '</s>', '<unk>', 't', 'iː', 'ð', 'ə']);
      expect(v.blankIndex, 0);
      expect(v.length, 8);
    });

    test('blank falls back through candidates, then to 0', () {
      expect(ModelVocab.fromJson('{"a": 0, "<blank>": 1}').blankIndex, 1);
      expect(ModelVocab.fromJson('{"a": 0, "_": 1}').blankIndex, 1);
      expect(ModelVocab.fromJson('{"a": 0, "b": 1}').blankIndex, 0);
    });

    test('rejects malformed vocab', () {
      expect(() => ModelVocab.fromJson('[]'), throwsFormatException);
      expect(() => ModelVocab.fromJson('{}'), throwsFormatException);
      expect(
        () => ModelVocab.fromJson('{"a": 0, "b": 0}'),
        throwsFormatException,
      );
      expect(
        () => ModelVocab.fromJson('{"a": 0, "b": 5}'),
        throwsFormatException,
      );
      expect(() => ModelVocab.fromJson('{"a": "0"}'), throwsFormatException);
      expect(() => ModelVocab(['a'], 3), throwsFormatException);
    });
  });

  test('logSoftmaxRowsInPlace normalises each row', () {
    final v = Float32List.fromList([1, 2, 3, 1000, 1000, 1000]);
    logSoftmaxRowsInPlace(v, 3);
    for (var r = 0; r < 2; r++) {
      var sum = 0.0;
      for (var i = 0; i < 3; i++) {
        expect(v[r * 3 + i], lessThanOrEqualTo(0));
        sum += math.exp(v[r * 3 + i]);
      }
      expect(sum, closeTo(1, 1e-5));
    }
    expect(
      v[3],
      closeTo(-math.log(3), 1e-5),
      reason: 'stable for large logits',
    );
    expect(() => logSoftmaxRowsInPlace(Float32List(5), 3), throwsArgumentError);
  });

  test('splitFrames returns views per frame', () {
    final v = Float32List.fromList([0, 1, 2, 3, 4, 5]);
    final frames = splitFrames(v, 2);
    expect(frames, [
      [0, 1],
      [2, 3],
      [4, 5],
    ]);
    v[2] = 9;
    expect(frames[1][0], 9);
    expect(() => splitFrames(v, 0), throwsArgumentError);
  });

  test('greedyDecode collapses repeats and drops blanks', () {
    final vocab = ModelVocab(['<pad>', 't', 'iː'], 0);
    Float32List f(int best) =>
        Float32List.fromList([for (var i = 0; i < 3; i++) i == best ? 0 : -5]);
    expect(greedyDecode([f(1), f(1), f(0), f(1), f(2), f(2), f(0)], vocab), [
      't',
      't',
      'iː',
    ]);
  });
}
