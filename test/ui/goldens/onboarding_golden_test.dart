// First-run steps on a phone (light; dark for two), and the welcome on a tablet
// (U1-home).
import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/onboarding/onboarding_screen.dart';

import '../../helpers/golden.dart';
import '../shell/harness.dart';
import 'u1_golden_helpers.dart';

void main() {
  late Seeded granted;
  late Seeded denied;
  late Seeded blocked;
  late Seeded noVoice;
  late Seeded placed;
  setUpAll(() async {
    granted = await seedEmpty(onboardingDone: false);
    denied = await seedEmpty(onboardingDone: false)
      ..recorder.permission = MicPermission.denied;
    blocked = await seedEmpty(onboardingDone: false)
      ..recorder.permission = MicPermission.permanentlyDenied;
    noVoice = await seedEmpty(onboardingDone: false)
      ..voice.britishVoice = false;
    placed = await seedEmpty(level: 3, onboardingDone: false);
  });

  OnboardingScreen at(OnboardingStep step) =>
      OnboardingScreen(initialStep: step);

  goldenTest(
    'Onboarding steps',
    fileName: 'onboarding',
    builder: () => GoldenTestGroup(
      columns: 4,
      children: [
        screenScenario('welcome', granted, at(OnboardingStep.welcome)),
        screenScenario(
          'microphone denied',
          denied,
          at(OnboardingStep.microphone),
        ),
        screenScenario(
          'microphone blocked dark',
          blocked,
          at(OnboardingStep.microphone),
          dark: true,
        ),
        screenScenario('voice ready', granted, at(OnboardingStep.voice)),
        screenScenario('no British voice', noVoice, at(OnboardingStep.voice)),
        screenScenario('placement', granted, at(OnboardingStep.placement)),
        screenScenario(
          'result dark',
          placed,
          at(OnboardingStep.result),
          dark: true,
        ),
        screenScenario(
          'welcome tablet',
          granted,
          at(OnboardingStep.welcome),
          size: goldenTabletSize,
        ),
      ],
    ),
  );
}
