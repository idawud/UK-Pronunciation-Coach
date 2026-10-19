// WCAG AA contrast (4.5:1 for normal text) of the score colours on every background
// they appear on, in both themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/theme/theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    final s = theme.colorScheme;
    final c = theme.extension<ScoreColors>()!;
    final backgrounds = {
      'surface': s.surface,
      'surfaceContainerLowest': s.surfaceContainerLowest,
      'surfaceContainerLow': s.surfaceContainerLow,
      'surfaceContainer': s.surfaceContainer,
      'surfaceContainerHigh': s.surfaceContainerHigh,
      'surfaceContainerHighest': s.surfaceContainerHighest,
    };
    final tokens = {
      'good': c.good,
      'close': c.close,
      'fix': c.fix,
      'notScored': c.notScored,
    };
    for (final t in tokens.entries) {
      for (final b in backgrounds.entries) {
        test('$name ${t.key} on ${b.key} meets AA', () {
          expect(contrast(t.value, b.value), greaterThanOrEqualTo(4.5));
        });
      }
    }
  }

  test('contrast helper matches known values', () {
    expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrast(Colors.white, Colors.white), 1);
  });
}
