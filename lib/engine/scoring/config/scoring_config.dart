/// Tunable scoring parameters: the GOP calibration curve, the good / close / fix
/// thresholds and the fluency rules. Pure data so I2-eval can tune it (I2 owns this
/// folder from Wave 2) and load a tuned copy from JSON with [ScoringConfig.fromJson].
library;

import 'dart:math' as math;

/// A piecewise-linear curve through [knots] (x ascending), clamped at both ends.
class PiecewiseLinear {
  /// Creates the curve. [knots] must be non-empty with strictly ascending x.
  const PiecewiseLinear(this.knots);

  /// Decodes `[[x, y], ...]`.
  factory PiecewiseLinear.fromJson(List<dynamic> json) {
    final knots = [
      for (final k in json)
        (((k as List<dynamic>)[0] as num).toDouble(), (k[1] as num).toDouble()),
    ];
    if (knots.isEmpty) throw const FormatException('curve needs a knot');
    for (var i = 1; i < knots.length; i++) {
      if (knots[i].$1 <= knots[i - 1].$1) {
        throw const FormatException('curve x values must ascend');
      }
    }
    return PiecewiseLinear(knots);
  }

  /// `(x, y)` points.
  final List<(double, double)> knots;

  /// The curve's value at [x].
  double call(double x) {
    if (x <= knots.first.$1) return knots.first.$2;
    if (x >= knots.last.$1) return knots.last.$2;
    var i = 1;
    while (x > knots[i].$1) {
      i++;
    }
    final (x0, y0) = knots[i - 1];
    final (x1, y1) = knots[i];
    return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
  }

  /// Encodes as `[[x, y], ...]`.
  List<List<double>> toJson() => [
    for (final (x, y) in knots) [x, y],
  ];
}

/// Every tunable number the scorer uses. Log values are natural logs.
class ScoringConfig {
  /// Creates a config; the defaults are A3's initial guesses (I2 tunes them).
  const ScoringConfig({
    this.calibration = defaultCalibration,
    this.goodThreshold = 80,
    this.closeThreshold = 60,
    this.stressedVowelWeight = 1.5,
    this.heardMargin = 0,
    this.skipWordPenalty = 5,
    this.missedSpeechThreshold = 0.3,
    this.wordMaxAboveWorst = 50,
    this.droppedScore = 0,
    this.intrusiveRScore = 45,
    this.intrusiveRWindowFrames = 10,
    this.speechFrameMinProb = 0.5,
    this.extraWordMinPhones = 2,
    this.phonesPerExtraWord = 4,
    this.repeatSimilarity = 0.6,
    this.pauseMinMs = 500,
    this.vadPauseMinMs = 250,
    this.freePauseAtPunctuationMs = 1500,
    this.pausePenalty = 8,
    this.pausePenaltyPerSecond = 10,
    this.rateCurve = defaultRateCurve,
    this.minWordsForRate = 3,
    this.continuityPenaltyScale = 250,
    this.rateWeight = 0.4,
    this.pauseWeight = 0.3,
    this.continuityWeight = 0.3,
    this.extraAccepted = const {},
  });

  /// Decodes a config; missing keys keep their defaults.
  factory ScoringConfig.fromJson(Map<String, dynamic> json) {
    const d = ScoringConfig();
    double n(String k, double fallback) =>
        (json[k] as num?)?.toDouble() ?? fallback;
    int i(String k, int fallback) => (json[k] as num?)?.toInt() ?? fallback;
    final cal = json['calibration'] as List<dynamic>?;
    final rate = json['rateCurve'] as List<dynamic>?;
    final extra = json['extraAccepted'] as Map<String, dynamic>?;
    return ScoringConfig(
      calibration: cal == null ? d.calibration : PiecewiseLinear.fromJson(cal),
      goodThreshold: i('goodThreshold', d.goodThreshold),
      closeThreshold: i('closeThreshold', d.closeThreshold),
      stressedVowelWeight: n('stressedVowelWeight', d.stressedVowelWeight),
      heardMargin: n('heardMargin', d.heardMargin),
      skipWordPenalty: n('skipWordPenalty', d.skipWordPenalty),
      missedSpeechThreshold: n(
        'missedSpeechThreshold',
        d.missedSpeechThreshold,
      ),
      wordMaxAboveWorst: n('wordMaxAboveWorst', d.wordMaxAboveWorst),
      droppedScore: i('droppedScore', d.droppedScore),
      intrusiveRScore: i('intrusiveRScore', d.intrusiveRScore),
      intrusiveRWindowFrames: i(
        'intrusiveRWindowFrames',
        d.intrusiveRWindowFrames,
      ),
      speechFrameMinProb: n('speechFrameMinProb', d.speechFrameMinProb),
      extraWordMinPhones: i('extraWordMinPhones', d.extraWordMinPhones),
      phonesPerExtraWord: i('phonesPerExtraWord', d.phonesPerExtraWord),
      repeatSimilarity: n('repeatSimilarity', d.repeatSimilarity),
      pauseMinMs: i('pauseMinMs', d.pauseMinMs),
      vadPauseMinMs: i('vadPauseMinMs', d.vadPauseMinMs),
      freePauseAtPunctuationMs: i(
        'freePauseAtPunctuationMs',
        d.freePauseAtPunctuationMs,
      ),
      pausePenalty: n('pausePenalty', d.pausePenalty),
      pausePenaltyPerSecond: n(
        'pausePenaltyPerSecond',
        d.pausePenaltyPerSecond,
      ),
      rateCurve: rate == null ? d.rateCurve : PiecewiseLinear.fromJson(rate),
      minWordsForRate: i('minWordsForRate', d.minWordsForRate),
      continuityPenaltyScale: n(
        'continuityPenaltyScale',
        d.continuityPenaltyScale,
      ),
      rateWeight: n('rateWeight', d.rateWeight),
      pauseWeight: n('pauseWeight', d.pauseWeight),
      continuityWeight: n('continuityWeight', d.continuityWeight),
      extraAccepted: extra == null
          ? d.extraAccepted
          : {
              for (final e in extra.entries)
                e.key: [for (final s in e.value as List<dynamic>) s as String],
            },
    );
  }

  /// Initial guess: GOP margin (expected minus best competitor, mean log-posterior
  /// over the phoneme's frames, renormalised without the blank) -> 0-100.
  static const PiecewiseLinear defaultCalibration = PiecewiseLinear([
    (-6, 0),
    (-3, 10),
    (-1, 30),
    (0, 50),
    (1, 65),
    (2, 78),
    (3, 86),
    (5, 95),
    (8, 100),
  ]);

  /// Speaking rate (words per minute) -> 0-100; 130-170 wpm is the target.
  static const PiecewiseLinear defaultRateCurve = PiecewiseLinear([
    (40, 0),
    (100, 70),
    (130, 100),
    (170, 100),
    (220, 70),
    (320, 0),
  ]);

  /// GOP -> phoneme score.
  final PiecewiseLinear calibration;

  /// Word score at or above this is good (green).
  final int goodThreshold;

  /// Word score at or above this (and below [goodThreshold]) is close (amber).
  final int closeThreshold;

  /// Weight of primary-stressed vowels in the word score (others weigh 1).
  final double stressedVowelWeight;

  /// A competitor is reported as `heard` when it beats the expected phoneme's mean
  /// log-posterior by more than this.
  final double heardMargin;

  /// Log-score cost of skipping an expected word in the alignment.
  final double skipWordPenalty;

  /// A word whose mean speech probability (1 - P(blank)) over its aligned phoneme
  /// frames is below this is marked missed.
  final double missedSpeechThreshold;

  /// A word scores at most its worst phoneme plus this, so one clearly wrong
  /// sound keeps the word out of green (100 disables the cap).
  final double wordMaxAboveWorst;

  /// Score of a dropped phoneme (no speech of its own in its aligned frames).
  final int droppedScore;

  /// Highest score a vowel gets when an r is sounded after it (non-rhotic English).
  final int intrusiveRScore;

  /// Frames after a vowel searched for an intrusive r.
  final int intrusiveRWindowFrames;

  /// A frame counts as speech when 1 - P(blank) is at least this.
  final double speechFrameMinProb;

  /// Inserted speech between words needs this many phones to count as an extra word.
  final int extraWordMinPhones;

  /// Phones per extra word when estimating how many words were inserted.
  final int phonesPerExtraWord;

  /// Inserted speech this similar (0-1) to a neighbouring word counts as a repeat.
  final double repeatSimilarity;

  /// A gap between words this long (ms) is a pause.
  final int pauseMinMs;

  /// A silence between VAD segments this long (ms) inside a word gap is a pause.
  final int vadPauseMinMs;

  /// Pauses at punctuation up to this long (ms) are free.
  final int freePauseAtPunctuationMs;

  /// Fluency points lost per pause.
  final double pausePenalty;

  /// Extra points lost per second of pause beyond half a second.
  final double pausePenaltyPerSecond;

  /// Words per minute -> rate score.
  final PiecewiseLinear rateCurve;

  /// With fewer spoken words than this the rate is not judged (rate score 100).
  final int minWordsForRate;

  /// Continuity score = 100 - scale * (missed + extra + repeated) / words.
  final double continuityPenaltyScale;

  /// Weight of the rate score in fluency.
  final double rateWeight;

  /// Weight of the pause score in fluency.
  final double pauseWeight;

  /// Weight of the continuity score in fluency.
  final double continuityWeight;

  /// Extra model symbols accepted as correct for a British phoneme, added to the
  /// built-in mapping table (e.g. `{"ɒ": ["ɑ"]}`).
  final Map<String, List<String>> extraAccepted;

  /// Encodes every field.
  Map<String, dynamic> toJson() => {
    'calibration': calibration.toJson(),
    'goodThreshold': goodThreshold,
    'closeThreshold': closeThreshold,
    'stressedVowelWeight': stressedVowelWeight,
    'heardMargin': heardMargin,
    'skipWordPenalty': skipWordPenalty,
    'missedSpeechThreshold': missedSpeechThreshold,
    'wordMaxAboveWorst': wordMaxAboveWorst,
    'droppedScore': droppedScore,
    'intrusiveRScore': intrusiveRScore,
    'intrusiveRWindowFrames': intrusiveRWindowFrames,
    'speechFrameMinProb': speechFrameMinProb,
    'extraWordMinPhones': extraWordMinPhones,
    'phonesPerExtraWord': phonesPerExtraWord,
    'repeatSimilarity': repeatSimilarity,
    'pauseMinMs': pauseMinMs,
    'vadPauseMinMs': vadPauseMinMs,
    'freePauseAtPunctuationMs': freePauseAtPunctuationMs,
    'pausePenalty': pausePenalty,
    'pausePenaltyPerSecond': pausePenaltyPerSecond,
    'rateCurve': rateCurve.toJson(),
    'minWordsForRate': minWordsForRate,
    'continuityPenaltyScale': continuityPenaltyScale,
    'rateWeight': rateWeight,
    'pauseWeight': pauseWeight,
    'continuityWeight': continuityWeight,
    'extraAccepted': extraAccepted,
  };

  /// Phoneme score for a GOP margin, 0-100.
  int phonemeScore(double gop) =>
      calibration(gop).round().clamp(0, 100).toInt();

  /// Rate score for [wpm], 0-100.
  double rateScore(double wpm) => math.max(0, math.min(100, rateCurve(wpm)));
}
