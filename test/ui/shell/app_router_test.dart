import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uk_pronunciation_coach/app.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/fix/fix_screen.dart';
import 'package:uk_pronunciation_coach/ui/home/home_screen.dart';
import 'package:uk_pronunciation_coach/ui/onboarding/onboarding_screen.dart';
import 'package:uk_pronunciation_coach/ui/practise/practise_screen.dart';
import 'package:uk_pronunciation_coach/ui/progress/progress_screen.dart';
import 'package:uk_pronunciation_coach/ui/read/read_screen.dart';
import 'package:uk_pronunciation_coach/ui/results/results_screen.dart';
import 'package:uk_pronunciation_coach/ui/settings/licences_screen.dart';
import 'package:uk_pronunciation_coach/ui/settings/settings_screen.dart';
import 'package:uk_pronunciation_coach/ui/shell/app_router.dart';

import 'harness.dart';

class _MockProgress extends Mock implements ProgressRepository {}

void main() {
  Future<GoRouter> pumpApp(WidgetTester tester, Seeded s) async {
    final container = ProviderContainer(overrides: s.overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CoachApp()),
    );
    await tester.pumpAndSettle();
    return container.read(appRouterProvider);
  }

  testWidgets('bottom navigation switches tabs', (tester) async {
    final s = await seedEmpty();
    await pumpApp(tester, s);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final (tab, type) in [
      ('Practise', PractiseScreen),
      ('Progress', ProgressScreen),
      ('Settings', SettingsScreen),
    ]) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.byType(type), findsOneWidget);
    }
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text("Start today's passage"), findsOneWidget);
  });

  testWidgets('wide windows use a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await seedEmpty();
    await pumpApp(tester, s);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();
    expect(find.byType(PractiseScreen), findsOneWidget);
  });

  testWidgets('first run redirects to onboarding, then Home', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    final router = await pumpApp(tester, s);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Tabs stay gated until onboarding is done.
    router.go(AppRoutes.progress);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // Read is not gated (placement uses it).
    unawaited(
      router.push(
        AppRoutes.read,
        extra: ReadArgs(passageId: teaPassage.id, mode: ReadMode.placement),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReadScreen), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sounds good'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip and start at level 1'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Practise query opens a section', (tester) async {
    final s = await seedHistory();
    final router = await pumpApp(tester, s);
    router.go('${AppRoutes.practise}?tab=review');
    await tester.pumpAndSettle();
    expect(find.text('Thursday'), findsOneWidget);
  });

  testWidgets('full-screen routes open with their arguments', (tester) async {
    final s = await seedEmpty();
    final router = await pumpApp(tester, s);
    unawaited(
      router.push(AppRoutes.read, extra: ReadArgs(passageId: riverPassage.id)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReadScreen), findsOneWidget);

    unawaited(
      router.push(
        AppRoutes.results,
        extra: ResultsArgs(result: cannedRiverAttempt),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);

    unawaited(
      router.push(AppRoutes.fix, extra: FixArgs(result: cannedRiverAttempt)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FixScreen), findsOneWidget);

    router.go(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    router.go(AppRoutes.licences);
    await tester.pumpAndSettle();
    expect(find.byType(LicencesScreen), findsOneWidget);
  });

  testWidgets('routes without arguments show a way back home', (tester) async {
    final s = await seedEmpty();
    final router = await pumpApp(tester, s);
    for (final path in [AppRoutes.read, AppRoutes.results, AppRoutes.fix]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.byType(MissingArgumentsScreen), findsOneWidget);
    }
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text("Start today's passage"), findsOneWidget);
  });

  group('onboardingRedirect', () {
    test('gates only the tabs', () async {
      final s = await seedEmpty(onboardingDone: false);
      expect(
        await onboardingRedirect(s.progress, AppRoutes.home),
        AppRoutes.onboarding,
      );
      expect(
        await onboardingRedirect(s.progress, AppRoutes.licences),
        AppRoutes.onboarding,
      );
      for (final path in [
        AppRoutes.onboarding,
        AppRoutes.read,
        AppRoutes.results,
        AppRoutes.fix,
      ]) {
        expect(await onboardingRedirect(s.progress, path), isNull);
      }
      await s.progress.saveProfile(const UserProfile(onboardingDone: true));
      expect(await onboardingRedirect(s.progress, AppRoutes.home), isNull);
    });

    test('opens the app if the profile cannot be read', () async {
      final progress = _MockProgress();
      when(progress.profile).thenThrow(StateError('db'));
      expect(await onboardingRedirect(progress, AppRoutes.home), isNull);
    });
  });

  test('ReadArgs needs a word index for sentence and word modes', () {
    expect(
      () => ReadArgs(passageId: 'x', mode: ReadMode.word),
      throwsAssertionError,
    );
    expect(
      const ReadArgs(
        passageId: 'x',
        mode: ReadMode.sentence,
        wordIndex: 3,
      ).wordIndex,
      3,
    );
    expect(FixArgs(result: cannedRiverAttempt).wordIndexes, isNull);
    expect(ResultsArgs(result: cannedRiverAttempt).levelChange, isNull);
  });
}
