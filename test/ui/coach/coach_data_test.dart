import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/tips.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/coach/coach_data.dart';

/// Tips keyed by 'expected|heard' so a test controls exactly which pair has advice.
class _StubTips implements Tips {
  _StubTips(this.table);

  final Map<String, String> table;

  @override
  String? tipFor(String expected, String? heard) =>
      table['$expected|${heard ?? ''}'];
}

SoundStat _stat(String ipa, double accuracy, {int attempts = 3}) => SoundStat(
  ipa: ipa,
  accuracy: accuracy,
  attempts: attempts,
  lastPractised: DateTime(2026, 11, 1),
);

const _shipSheep = MinimalPair(contrast: 'ɪ-iː', wordA: 'ship', wordB: 'sheep');
const _bitBeat = MinimalPair(contrast: 'ɪ-iː', wordA: 'bit', wordB: 'beat');
const _pullPool = MinimalPair(contrast: 'ʊ-uː', wordA: 'pull', wordB: 'pool');
const _cotCaught = MinimalPair(contrast: 'ɒ-ɔː', wordA: 'cot', wordB: 'caught');

void main() {
  final tips = FakeTips();

  test('orders the weakest sounds first and keeps count', () {
    final out = buildGuidedExercises(
      stats: [_stat('ɪ', 60), _stat('ʌ', 20), _stat('iː', 40)],
      pairs: const [],
      tips: tips,
    );
    expect(out.map((g) => g.stat.ipa), ['ʌ', 'iː', 'ɪ']);

    final two = buildGuidedExercises(
      stats: [_stat('ɪ', 60), _stat('ʌ', 20), _stat('iː', 40)],
      pairs: const [],
      tips: tips,
      count: 2,
    );
    expect(two.map((g) => g.stat.ipa), ['ʌ', 'iː']);
  });

  test('ties in accuracy are ordered by ipa', () {
    final out = buildGuidedExercises(
      stats: [_stat('ɪ', 50), _stat('ʌ', 50)],
      pairs: const [],
      tips: tips,
    );
    // 'ɪ' (U+026A) sorts before 'ʌ' (U+028C) by code point.
    expect(out.map((g) => g.stat.ipa), ['ɪ', 'ʌ']);
  });

  test('skips sounds without attempts', () {
    final out = buildGuidedExercises(
      stats: [_stat('θ', 1, attempts: 0), _stat('ɪ', 70)],
      pairs: const [],
      tips: tips,
    );
    expect(out.map((g) => g.stat.ipa), ['ɪ']);
  });

  test('empty stats give no exercises', () {
    expect(
      buildGuidedExercises(stats: const [], pairs: [_shipSheep], tips: tips),
      isEmpty,
    );
  });

  test('pairs are filtered by contrast and capped at three', () {
    final out = buildGuidedExercises(
      stats: [_stat('ɪ', 30)],
      pairs: const [_cotCaught, _shipSheep, _pullPool, _bitBeat],
      tips: tips,
    );
    expect(out.single.pairs, [_shipSheep, _bitBeat]);

    final many = buildGuidedExercises(
      stats: [_stat('ɪ', 30)],
      pairs: const [
        _shipSheep,
        _bitBeat,
        MinimalPair(contrast: 'ɪ-ɛ', wordA: 'bet', wordB: 'bit'),
        MinimalPair(contrast: 'ʌ-ɪ', wordA: 'hut', wordB: 'hit'),
      ],
      tips: tips,
    );
    expect(many.single.pairs.length, coachPairsPerExercise);
    expect(many.single.pairs.length, 3);
  });

  test('a sound with no matching pairs gets no pairs and no tip', () {
    final out = buildGuidedExercises(
      stats: [_stat('θ', 30)],
      pairs: const [_shipSheep],
      tips: tips,
    );
    expect(out.single.pairs, isEmpty);
    expect(out.single.tip, isNull);
  });

  test('no pairs at all still gives the sound with no tip', () {
    final out = buildGuidedExercises(
      stats: [_stat('iː', 30)],
      pairs: const [],
      tips: tips,
    );
    expect(out.single.stat.ipa, 'iː');
    expect(out.single.pairs, isEmpty);
    expect(out.single.tip, isNull);
  });

  test('the tip is the first non-null advice over the pairs', () {
    final stub = _StubTips({'ɪ|ʊ': 'Second pair advice.'});
    final out = buildGuidedExercises(
      stats: [_stat('ɪ', 30)],
      pairs: const [
        _shipSheep,
        MinimalPair(contrast: 'ɪ-ʊ', wordA: 'bit', wordB: 'book'),
      ],
      tips: stub,
    );
    expect(out.single.tip, 'Second pair advice.');
  });

  test('the tip comes from the counterpart of the first matching pair', () {
    final out = buildGuidedExercises(
      stats: [_stat('iː', 30)],
      pairs: const [_shipSheep],
      tips: tips,
    );
    // FakeTips knows iː heard as ɪ.
    expect(out.single.tip, contains('sheep'));
  });

  test('a tip is null when no pair has advice', () {
    final out = buildGuidedExercises(
      stats: [_stat('ɪ', 30)],
      pairs: const [_shipSheep],
      tips: _StubTips(const {}),
    );
    expect(out.single.tip, isNull);
    expect(out.single.pairs, [_shipSheep]);
  });
}
