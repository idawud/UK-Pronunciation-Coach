import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uk_pronunciation_coach/app.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/coach_hub_screen.dart';
import 'package:uk_pronunciation_coach/ui/coach/coach_routes.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/confusions_screen.dart';
import 'package:uk_pronunciation_coach/ui/coach/describe/describe_screen.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_screen.dart';
import 'package:uk_pronunciation_coach/ui/coach/record/record_compare_screen.dart';
import 'package:uk_pronunciation_coach/ui/coach/sounds/sounds_screen.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/words_screen.dart';
import 'package:uk_pronunciation_coach/ui/shell/app_router.dart';

import '../shell/harness.dart';

void main() {
  /// Pumps the real app on the Coach hub and returns its router.
  Future<GoRouter> pumpHub(
    WidgetTester tester,
    InMemoryCoachStore store,
  ) async {
    final s = await seedEmpty();
    final container = ProviderContainer(
      overrides: [...s.overrides, coachStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CoachApp()),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go(coachPath);
    await tester.pumpAndSettle();
    return router;
  }

  /// The reset action sits below the cards, so scroll it into the lazy list first.
  Future<void> scrollToReset(WidgetTester tester) => tester.scrollUntilVisible(
    find.text('Reset Coach data'),
    200,
    scrollable: find.byType(Scrollable).first,
  );

  testWidgets('the hub shows one card per section', (tester) async {
    await pumpHub(tester, InMemoryCoachStore());
    expect(find.byType(CoachScreen), findsOneWidget);
    // The list is lazy: the first five cards are on screen, the IPA card sits just
    // above the reset action.
    for (final title in [
      'Sounds',
      'Confusions',
      'Words',
      'Record & compare',
      'Describe it',
    ]) {
      // "Record & compare" is both a title and a subtitle, so match at least one.
      expect(find.widgetWithText(ListTile, title), findsWidgets);
    }
    await scrollToReset(tester);
    expect(find.widgetWithText(ListTile, 'IPA lessons'), findsWidgets);
    expect(find.text('Reset Coach data'), findsOneWidget);
  });

  testWidgets('tapping Sounds opens SoundsScreen with a back button', (
    tester,
  ) async {
    final router = await pumpHub(tester, InMemoryCoachStore());
    await tester.tap(find.widgetWithText(ListTile, 'Sounds'));
    await tester.pumpAndSettle();

    expect(find.byType(SoundsScreen), findsOneWidget);
    expect(router.state.matchedLocation, coachSoundsPath);
    // The tab bar still highlights Coach (branch index 3).
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 3);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CoachScreen), findsOneWidget);
    expect(find.byType(SoundsScreen), findsNothing);
  });

  testWidgets('section routes resolve under /coach', (tester) async {
    final router = await pumpHub(tester, InMemoryCoachStore());
    for (final (path, type) in [
      (coachConfusionsPath, ConfusionsScreen),
      (coachWordsPath, WordsScreen),
      (coachRecordPath, RecordCompareScreen),
      (coachDescribePath, DescribeScreen),
      (coachIpaPath, IpaScreen),
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.byType(type), findsOneWidget, reason: path);
    }
  });

  test('section sub-paths stay behind onboarding like the Coach tab', () async {
    final s = await seedEmpty(onboardingDone: false);
    expect(
      await onboardingRedirect(s.progress, coachWordsPath),
      AppRoutes.onboarding,
    );
  });

  testWidgets('reset asks first, then clears the store', (tester) async {
    final store = InMemoryCoachStore();
    await store.write('confusions', {'a': 1});
    await pumpHub(tester, store);

    await scrollToReset(tester);
    await tester.tap(find.text('Reset Coach data'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Coach data?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await store.read('confusions'), {'a': 1});

    await scrollToReset(tester);
    await tester.tap(find.text('Reset Coach data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(await store.read('confusions'), isNull);
    expect(find.text('Coach data cleared'), findsOneWidget);
  });
}
