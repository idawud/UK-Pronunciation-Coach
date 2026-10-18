import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uk_pronunciation_coach/app.dart';
import 'package:uk_pronunciation_coach/core/contracts/navigation.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/ui/fix/fix_screen.dart';
import 'package:uk_pronunciation_coach/ui/read/read_screen.dart';
import 'package:uk_pronunciation_coach/ui/results/results_screen.dart';
import 'package:uk_pronunciation_coach/ui/shell/app_router.dart';

void main() {
  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CoachApp()),
    );
    await tester.pumpAndSettle();
    return container.read(appRouterProvider);
  }

  testWidgets('bottom navigation switches tabs', (tester) async {
    await pumpApp(tester);
    for (final tab in ['Practise', 'Progress', 'Settings']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.text('$tab (coming soon)'), findsOneWidget);
    }
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text("Start today's passage"), findsOneWidget);
  });

  testWidgets('full-screen routes open with their arguments', (tester) async {
    final router = await pumpApp(tester);
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
    expect(find.text('Welcome (coming soon)'), findsOneWidget);

    router.go(AppRoutes.licences);
    await tester.pumpAndSettle();
    expect(find.text('Licences (coming soon)'), findsOneWidget);
  });

  testWidgets('routes without arguments show a way back home', (tester) async {
    final router = await pumpApp(tester);
    for (final path in [AppRoutes.read, AppRoutes.results, AppRoutes.fix]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.byType(MissingArgumentsScreen), findsOneWidget);
    }
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text("Start today's passage"), findsOneWidget);
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
