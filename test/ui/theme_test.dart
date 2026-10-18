// Seeded by W0-scaffold for U1-home (theme tokens); extend when the theme changes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/enums.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';
import 'package:uk_pronunciation_coach/ui/theme/score_colors.dart';

void main() {
  test('both themes carry ScoreColors', () {
    expect(AppTheme.light().extension<ScoreColors>(), ScoreColors.light);
    expect(AppTheme.dark().extension<ScoreColors>(), ScoreColors.dark);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  test('ScoreColors maps statuses, copies and lerps', () {
    const c = ScoreColors.light;
    expect(c.forStatus(WordStatus.good), c.good);
    expect(c.forStatus(WordStatus.close), c.close);
    expect(c.forStatus(WordStatus.fix), c.fix);
    expect(c.forStatus(WordStatus.missed), c.fix);
    expect(c.forStatus(WordStatus.notScored), c.notScored);
    expect(c.copyWith(good: Colors.black).good, Colors.black);
    expect(c.copyWith(), isA<ScoreColors>());
    expect(c.lerp(null, 0.5), c);
    expect(c.lerp(ScoreColors.dark, 1).fix, ScoreColors.dark.fix);
  });

  testWidgets('ScoreColors.of falls back to light values', (tester) async {
    late ScoreColors found;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            found = ScoreColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, ScoreColors.light);
  });
}
