import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/scoring/config/scoring_config.dart';

void main() {
  group('PiecewiseLinear', () {
    const c = PiecewiseLinear([(0, 0), (10, 100), (20, 50)]);

    test('interpolates and clamps', () {
      expect(c(-5), 0);
      expect(c(0), 0);
      expect(c(5), 50);
      expect(c(10), 100);
      expect(c(15), 75);
      expect(c(30), 50);
      expect(c(double.infinity), 50);
    });

    test('round-trips JSON and validates knots', () {
      final back = PiecewiseLinear.fromJson(
        jsonDecode(jsonEncode(c.toJson())) as List<dynamic>,
      );
      expect(back.knots, c.knots);
      expect(() => PiecewiseLinear.fromJson(const []), throwsFormatException);
      expect(
        () => PiecewiseLinear.fromJson(const [
          [1, 0],
          [1, 2],
        ]),
        throwsFormatException,
      );
    });
  });

  group('ScoringConfig', () {
    const d = ScoringConfig();

    test('defaults follow the spec', () {
      expect(d.goodThreshold, 80);
      expect(d.closeThreshold, 60);
      expect(d.stressedVowelWeight, 1.5);
      expect(d.rateScore(150), 100);
      expect(d.rateScore(130), 100);
      expect(d.rateScore(170), 100);
      expect(d.rateScore(20), 0);
      expect(d.rateScore(400), 0);
      expect(d.rateScore(100), lessThan(100));
    });

    test('calibration is monotonic from 0 to 100', () {
      var last = -1;
      for (var g = -10.0; g <= 10; g += 0.25) {
        final s = d.phonemeScore(g);
        expect(s, greaterThanOrEqualTo(last));
        last = s;
      }
      expect(d.phonemeScore(-10), 0);
      expect(d.phonemeScore(10), 100);
      expect(d.phonemeScore(-1), 50); // accuracy pass curve (no phoneme offset)
      expect(ScoringConfig.i2Calibration(-2), 50);
      // A phoneme with a positive offset needs a larger margin for the same score.
      expect(d.phonemeScore(0, 'ɹ'), lessThan(d.phonemeScore(0)));
      expect(ScoringConfig.a3Calibration(0), 50);
    });

    test('round-trips through JSON', () {
      const custom = ScoringConfig(
        goodThreshold: 75,
        skipWordPenalty: 7,
        calibration: PiecewiseLinear([(-1, 0), (1, 100)]),
        rateCurve: PiecewiseLinear([(100, 0), (150, 100)]),
        extraAccepted: {
          'ɒ': ['ɑ'],
        },
      );
      final json =
          jsonDecode(jsonEncode(custom.toJson())) as Map<String, dynamic>;
      final back = ScoringConfig.fromJson(json);
      expect(back.toJson(), custom.toJson());
      expect(back.extraAccepted, {
        'ɒ': ['ɑ'],
      });
    });

    test('missing keys keep defaults', () {
      final c = ScoringConfig.fromJson(const {'goodThreshold': 85});
      expect(c.goodThreshold, 85);
      expect(
        c.toJson()..remove('goodThreshold'),
        d.toJson()..remove('goodThreshold'),
      );
    });
  });
}
