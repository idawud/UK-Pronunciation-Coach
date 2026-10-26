import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import 'support/synth.dart';

/// The light tier keeps the pre-accuracy-pass calibration; the full tier gets the
/// new defaults.
void main() {
  group('ScoringConfig.forTier', () {
    test('light is the old curve with no offsets or syllabic forms', () {
      final c = ScoringConfig.forTier(ModelTier.light);
      expect(c.calibration.knots, ScoringConfig.i2Calibration.knots);
      expect(c.phonemeGopOffset, isEmpty);
      expect(c.syllabicConsonants, isFalse);
    });

    test('full is the new defaults', () {
      final c = ScoringConfig.forTier(ModelTier.full);
      expect(c.calibration.knots, ScoringConfig.defaultCalibration.knots);
      expect(c.phonemeGopOffset, isNotEmpty);
      expect(c.syllabicConsonants, isTrue);
    });

    test('both configs round-trip through JSON', () {
      for (final t in ModelTier.values) {
        final c = ScoringConfig.forTier(t);
        final back = ScoringConfig.fromJson(
          jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>,
        );
        expect(back.toJson(), c.toJson(), reason: t.name);
        expect(back.syllabicConsonants, c.syllabicConsonants);
        expect(back.phonemeGopOffset, c.phonemeGopOffset);
      }
    });
  });

  group('GopPronunciationScorer picks a config per tier', () {
    test('defaults', () {
      const s = GopPronunciationScorer();
      expect(
        s.configFor(ModelTier.light).calibration.knots,
        ScoringConfig.i2Calibration.knots,
      );
      expect(
        s.configFor(ModelTier.full).calibration.knots,
        ScoringConfig.defaultCalibration.knots,
      );
    });

    test('an explicit config applies to every tier', () {
      const custom = ScoringConfig(goodThreshold: 90);
      const s = GopPronunciationScorer(config: custom);
      expect(s.configFor(ModelTier.light), same(custom));
      expect(s.configFor(ModelTier.full), same(custom));
      const both = GopPronunciationScorer(
        config: custom,
        lightConfig: ScoringConfig.light,
      );
      expect(both.configFor(ModelTier.light), same(ScoringConfig.light));
    });

    test('the same audio is scored with the tier config', () {
      // "people" said as one əl token: only the full config (syllabic forms)
      // matches it without a dropped sound.
      final word = WordSpec(
        text: 'people',
        index: 0,
        offset: 0,
        phonemes: [
          for (final t in ['p', 'iː', 'p', 'ə', 'l'])
            PhonemeSpec(ipa: t, stress: t == 'iː' ? 1 : 0),
        ],
      );
      final passage = Passage(
        id: 'p',
        level: 1,
        title: 'people',
        text: 'people',
        words: [word],
      );
      PhonemePosteriors said(ModelTier tier) {
        final s = Synth()..blank(10);
        for (final sym in ['p', 'iː', 'p']) {
          s
            ..phone(sym, 2)
            ..blank(2);
        }
        s
          ..phone('əl', 1)
          ..blank(12);
        return s.build(tier: tier);
      }

      const scorer = GopPronunciationScorer();
      final full = scorer.analyse(passage, said(ModelTier.full), const []);
      final light = scorer.analyse(passage, said(ModelTier.light), const []);
      expect(full.words.single.phonemes.last.expected, 'l̩');
      expect(light.words.single.phonemes.last.expected, 'l');
      expect(
        scorer.score(passage, said(ModelTier.light), const []).tier,
        ModelTier.light,
      );
    });
  });
}
