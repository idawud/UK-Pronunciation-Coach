import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';

/// Shared behaviour every [Tips] must have.
void runTipsContract(Tips Function() create) {
  group('Tips contract', () {
    late Tips tips;
    setUp(() => tips = create());

    test('no tip when nothing is wrong', () {
      expect(tips.tipFor('θ', null), isNull);
      expect(tips.tipFor('θ', 'θ'), isNull);
    });

    test('known substitutions have advice', () {
      expect(tips.tipFor('θ', 't'), isNotEmpty);
      expect(tips.tipFor('ɑː', 'æ'), isNotEmpty);
    });

    test('never returns an empty string', () {
      for (final a in sampleVocab) {
        for (final b in [...sampleVocab, '', '${a}ɹ']) {
          final tip = tips.tipFor(a, b);
          if (tip != null) expect(tip.trim(), isNotEmpty, reason: '$a -> $b');
        }
      }
    });
  });
}
