import 'dart:math' as math;

import 'package:uk_pronunciation_coach/core/models/models.dart';

/// How far a live (piecewise) result is from the whole-clip result of the same
/// recording.
class ResultComparison {
  /// Creates the comparison.
  const ResultComparison({
    required this.words,
    required this.maxWordDiff,
    required this.meanWordDiff,
    required this.statusAgreement,
    required this.overallDiff,
    required this.accuracyDiff,
    required this.fluencyDiff,
    required this.wholeNotGood,
    required this.liveNotGood,
  });

  /// Words that are not green (close, fix or missed) in each result: on a clean
  /// read these are false alarms.
  final int wholeNotGood, liveNotGood;

  /// Words compared.
  final int words;

  /// Largest absolute word-score difference.
  final int maxWordDiff;

  /// Mean absolute word-score difference.
  final double meanWordDiff;

  /// Share of words with the same status (good / close / fix / missed).
  final double statusAgreement;

  /// Absolute differences of the attempt scores.
  final int overallDiff, accuracyDiff, fluencyDiff;

  /// For logs and JSON.
  Map<String, Object?> toJson() => {
    'words': words,
    'maxWordDiff': maxWordDiff,
    'meanWordDiff': double.parse(meanWordDiff.toStringAsFixed(2)),
    'statusAgreement': double.parse(statusAgreement.toStringAsFixed(4)),
    'overallDiff': overallDiff,
    'accuracyDiff': accuracyDiff,
    'fluencyDiff': fluencyDiff,
    'wholeNotGood': wholeNotGood,
    'liveNotGood': liveNotGood,
  };

  @override
  String toString() => toJson().toString();
}

/// Compares [live] with [whole] word by word (same passage, same order).
ResultComparison compareResults(AttemptResult whole, AttemptResult live) {
  if (whole.words.length != live.words.length) {
    throw ArgumentError('different passages');
  }
  var maxDiff = 0;
  var sum = 0;
  var same = 0;
  for (var i = 0; i < whole.words.length; i++) {
    final d = (whole.words[i].score - live.words[i].score).abs();
    maxDiff = math.max(maxDiff, d);
    sum += d;
    if (whole.words[i].status == live.words[i].status) same++;
  }
  final n = whole.words.length;
  return ResultComparison(
    words: n,
    maxWordDiff: maxDiff,
    meanWordDiff: n == 0 ? 0 : sum / n,
    statusAgreement: n == 0 ? 1 : same / n,
    overallDiff: (whole.overall - live.overall).abs(),
    accuracyDiff: (whole.accuracy - live.accuracy).abs(),
    fluencyDiff: (whole.fluency - live.fluency).abs(),
    wholeNotGood: whole.words.where((w) => w.status != WordStatus.good).length,
    liveNotGood: live.words.where((w) => w.status != WordStatus.good).length,
  );
}
