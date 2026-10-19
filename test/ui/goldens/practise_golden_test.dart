// Practise tab sections, phone and tablet, light and dark (U1-home).
import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/practise/practise_screen.dart';

import '../../helpers/golden.dart';
import '../shell/harness.dart';
import 'u1_golden_helpers.dart';

void main() {
  late Seeded history;
  setUpAll(() async => history = await seedHistory());

  goldenTest(
    'Practise: library, weak sounds and words due',
    fileName: 'practise',
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        screenScenario('library phone light', history, const PractiseScreen()),
        screenScenario(
          'sounds phone light',
          history,
          const PractiseScreen(initialTab: PractiseTab.sounds),
        ),
        screenScenario(
          'review phone dark',
          history,
          const PractiseScreen(initialTab: PractiseTab.review),
          dark: true,
        ),
        screenScenario(
          'library tablet dark',
          history,
          const PractiseScreen(),
          size: goldenTabletSize,
          dark: true,
        ),
      ],
    ),
  );
}
