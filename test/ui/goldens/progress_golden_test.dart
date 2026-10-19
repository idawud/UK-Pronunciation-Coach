// Progress screen goldens (U4-progress): phone and tablet, light and dark, plus the
// empty state. Update on Linux: flutter test --update-goldens --tags golden
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/ui/progress/progress_screen.dart';

import '../../helpers/golden.dart';
import '../progress/u4_harness.dart';

Widget _scenario(
  FakeProgressRepository repo,
  Size size,
  Brightness brightness,
) => SizedBox.fromSize(
  size: size,
  child: testApp(
    const ProgressScreen(),
    overrides: overridesFor(repo: repo),
    brightness: brightness,
    wrapTheme: withTestFonts,
  ),
);

void main() {
  late FakeProgressRepository seeded;
  final empty = FakeProgressRepository(clock: testClock);

  setUpAll(() async => seeded = await seededRepository());

  goldenTest(
    'Progress on a phone',
    fileName: 'progress_phone',
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _scenario(seeded, goldenPhoneSize, Brightness.light),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _scenario(seeded, goldenPhoneSize, Brightness.dark),
        ),
        GoldenTestScenario(
          name: 'empty',
          child: _scenario(empty, goldenPhoneSize, Brightness.light),
        ),
      ],
    ),
  );

  goldenTest(
    'Progress on a tablet',
    fileName: 'progress_tablet',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _scenario(seeded, goldenTabletSize, Brightness.light),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _scenario(seeded, goldenTabletSize, Brightness.dark),
        ),
      ],
    ),
  );
}
