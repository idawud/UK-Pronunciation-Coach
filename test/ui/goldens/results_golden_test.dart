// Goldens for Results, its word sheet and Fix a word (U3-results): light and dark,
// phone and tablet, with the canned river attempt (Thursday, castle, bath red).
//
// Update images on Linux only:  flutter test --update-goldens --tags golden
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/fix/fix_screen.dart';
import 'package:uk_pronunciation_coach/ui/results/results_screen.dart';
import 'package:uk_pronunciation_coach/ui/results/word_sheet.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';

import '../../helpers/golden.dart';
import '../results/harness.dart';

Widget _app(Widget screen, {required bool dark}) => ProviderScope(
  overrides: Fakes().overrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: withTestFonts(dark ? AppTheme.dark() : AppTheme.light()),
    home: screen,
  ),
);

GoldenTestGroup _sizes(Widget Function() screen, {required bool dark}) =>
    GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(
          name: 'phone',
          constraints: BoxConstraints.tight(goldenPhoneSize),
          child: _app(screen(), dark: dark),
        ),
        GoldenTestScenario(
          name: 'tablet',
          constraints: BoxConstraints.tight(goldenTabletSize),
          child: _app(screen(), dark: dark),
        ),
      ],
    );

final _levelUp = LevelChange(
  from: 3,
  to: 4,
  reason: 'Three passages in a row at 85 or more: welcome to level 4.',
  at: DateTime(2026, 10, 15),
);

Widget _sheet() => Scaffold(
  body: Align(
    alignment: Alignment.bottomCenter,
    child: Material(
      elevation: 2,
      child: WordSheet(
        result: cannedRiverAttempt.words[1],
        word: riverPassage.words[1],
        onRetried: (_) {},
      ),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    goldenTest(
      'Results matches the sketch ($theme)',
      fileName: 'results_$theme',
      builder: () => _sizes(
        () => ResultsScreen(
          args: ResultsArgs(result: cannedRiverAttempt, levelChange: _levelUp),
        ),
        dark: dark,
      ),
    );
    goldenTest(
      'Results word sheet ($theme)',
      fileName: 'results_word_sheet_$theme',
      builder: () => GoldenTestGroup(
        children: [
          GoldenTestScenario(
            name: 'phone',
            constraints: BoxConstraints.tight(goldenPhoneSize),
            child: _app(_sheet(), dark: dark),
          ),
        ],
      ),
    );
    goldenTest(
      'Fix a word matches the sketch ($theme)',
      fileName: 'fix_$theme',
      builder: () => _sizes(
        () => FixScreen(args: FixArgs(result: cannedRiverAttempt)),
        dark: dark,
      ),
    );
  }
  goldenTest(
    'Results light tier',
    fileName: 'results_light_tier',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'phone',
          constraints: BoxConstraints.tight(goldenPhoneSize),
          child: _app(
            ResultsScreen(
              args: ResultsArgs(
                result: cannedRiverAttempt.copyWith(tier: ModelTier.light),
              ),
            ),
            dark: false,
          ),
        ),
      ],
    ),
  );
}
