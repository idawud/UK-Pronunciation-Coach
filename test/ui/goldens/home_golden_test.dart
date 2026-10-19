// Home in light and dark, phone and tablet (U1-home).
// Update on Linux only: flutter test --update-goldens --tags golden
import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/home/home_screen.dart';

import '../../helpers/golden.dart';
import '../shell/harness.dart';
import 'u1_golden_helpers.dart';

void main() {
  late Seeded history;
  late Seeded empty;
  setUpAll(() async {
    history = await seedHistory();
    empty = await seedEmpty();
  });

  goldenTest(
    'Home: light and dark, phone and tablet',
    fileName: 'home',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        screenScenario('phone light', history, const HomeScreen()),
        screenScenario('phone dark', history, const HomeScreen(), dark: true),
        screenScenario(
          'tablet light',
          history,
          const HomeScreen(),
          size: goldenTabletSize,
        ),
        screenScenario(
          'tablet dark',
          history,
          const HomeScreen(),
          size: goldenTabletSize,
          dark: true,
        ),
      ],
    ),
  );

  goldenTest(
    'Home: empty history',
    fileName: 'home_empty',
    builder: () => GoldenTestGroup(
      children: [screenScenario('phone light', empty, const HomeScreen())],
    ),
  );
}
