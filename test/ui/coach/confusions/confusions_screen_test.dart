import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/confusions_providers.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/confusions_screen.dart';
import 'package:uk_pronunciation_coach/ui/shell/state_views.dart';

import '../../shell/harness.dart';
import 'confusion_fixtures.dart';

Future<InMemoryCoachStore> _pump(
  WidgetTester tester, {
  required Seeded seeded,
  InMemoryCoachStore? store,
}) async {
  final coach = store ?? InMemoryCoachStore();
  final overrides = <Override>[
    ...seeded.overrides,
    coachStoreProvider.overrideWithValue(coach),
  ];
  await tester.pumpWidget(
    harness(const ConfusionsScreen(), overrides: overrides),
  );
  await tester.pumpAndSettle();
  return coach;
}

void main() {
  testWidgets('shows a loading view first', (tester) async {
    final seeded = await seedEmpty();
    final never = Completer<ConfusionsData>();
    await tester.pumpWidget(
      harness(
        const ConfusionsScreen(),
        overrides: [
          ...seeded.overrides,
          coachStoreProvider.overrideWithValue(InMemoryCoachStore()),
          confusionsDataProvider.overrideWith((ref) => never.future),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
    // The spinner never stops, so drop the tree instead of settling.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the empty state explains how confusions appear', (tester) async {
    final seeded = await seedEmpty();
    await _pump(tester, seeded: seeded);
    expect(find.text('No confusions yet'), findsOneWidget);
    expect(find.textContaining('twice or more'), findsOneWidget);
    expect(find.text("Start today's session"), findsOneWidget);
    expect(find.text('No streak yet'), findsOneWidget);
  });

  testWidgets('lists the top confusion with IPA, examples and average', (
    tester,
  ) async {
    final seeded = await seedEmpty();
    for (final a in threeUncleAttempts(fixedNow())) {
      await seeded.progress.saveAttempt(a);
    }
    await _pump(tester, seeded: seeded);

    expect(find.text('Sounds you swap'), findsOneWidget);
    expect(find.text('/ʌ/'), findsOneWidget);
    expect(find.text('/æ/'), findsOneWidget);
    expect(find.text('Examples: cut'), findsOneWidget);
    expect(find.text('Average 40'), findsOneWidget);
    expect(find.text('3 times'), findsOneWidget);
    expect(find.text("Start today's session"), findsOneWidget);
    expect(find.text('No confusions yet'), findsNothing);
  });

  testWidgets('a streak from yesterday shows as the current streak', (
    tester,
  ) async {
    final seeded = await seedEmpty();
    final store = InMemoryCoachStore();
    await store.write('confusions', {
      'lastSessionDate': '2026-10-18',
      'streak': 4,
    });
    await _pump(tester, seeded: seeded, store: store);
    expect(find.text('4-day streak'), findsOneWidget);
  });

  testWidgets('a streak older than yesterday is not shown', (tester) async {
    final seeded = await seedEmpty();
    final store = InMemoryCoachStore();
    await store.write('confusions', {
      'lastSessionDate': '2026-10-10',
      'streak': 4,
    });
    await _pump(tester, seeded: seeded, store: store);
    expect(find.text('No streak yet'), findsOneWidget);
  });
}
