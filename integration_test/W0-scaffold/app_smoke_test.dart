import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uk_pronunciation_coach/app.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // main() runs against the real database, whose contents survive between runs on
  // a device, so this only checks that the app boots and settles on a screen.
  testWidgets('main() starts the app', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.byType(CoachApp), findsOneWidget);
    // main() owns its ProviderScope, so the test cannot dispose it. Let the
    // start-up reads (router redirect, profile, reminder restore) finish before
    // the binding tears the database down under them.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a profile that has not onboarded starts on onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
        ],
        child: const CoachApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('app starts on Home once onboarding is done and switches tabs', (
    tester,
  ) async {
    final progress = FakeProgressRepository();
    await progress.saveProfile(const UserProfile(onboardingDone: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [progressRepositoryProvider.overrideWithValue(progress)],
        child: const CoachApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Start today's passage"), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
