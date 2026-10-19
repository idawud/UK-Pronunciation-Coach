import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uk_pronunciation_coach/core/contracts/navigation.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/progress/progress_data.dart';
import 'package:uk_pronunciation_coach/ui/progress/progress_screen.dart';
import 'package:uk_pronunciation_coach/ui/progress/sound_accuracy_list.dart';
import 'package:uk_pronunciation_coach/ui/progress/streak_calendar.dart';

import 'u4_harness.dart';

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('ProgressScreen', () {
    testWidgets('shows a spinner while loading', (tester) async {
      await tester.pumpWidget(
        testApp(
          const ProgressScreen(),
          overrides: [
            ...overridesFor(repo: FakeProgressRepository(clock: testClock)),
            progressDataProvider.overrideWith((ref) => never()),
          ],
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows an error with retry', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        testApp(
          const ProgressScreen(),
          overrides: [
            ...overridesFor(repo: FakeProgressRepository(clock: testClock)),
            progressDataProvider.overrideWith((ref) async {
              calls++;
              throw StateError('db closed');
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Your progress couldn't be loaded."), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets('shows the empty state for a new user', (tester) async {
      await tester.pumpWidget(
        testApp(
          const ProgressScreen(),
          overrides: overridesFor(
            repo: FakeProgressRepository(clock: testClock),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No progress yet'), findsOneWidget);
      // No router here: the button must not throw.
      await tester.tap(find.text("Start today's passage"));
      await tester.pump();
    });

    testWidgets('empty-state button goes Home through the router', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AppRoutes.progress,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const Text('home page'),
          ),
          GoRoute(
            path: AppRoutes.progress,
            builder: (_, _) => const ProgressScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesFor(
            repo: FakeProgressRepository(clock: testClock),
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Start today's passage"));
      await tester.pumpAndSettle();
      expect(find.text('home page'), findsOneWidget);
    });

    testWidgets('shows trend, level history, sounds and calendar', (
      tester,
    ) async {
      await setSize(tester, const Size(390, 2400));
      final repo = await seededRepository();
      await tester.pumpWidget(
        testApp(const ProgressScreen(), overrides: overridesFor(repo: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('2 of 6'), findsOneWidget);
      expect(find.text('Level 1 to 2'), findsOneWidget);
      expect(find.textContaining('15 Oct 2026'), findsOneWidget);
      expect(find.byType(StreakCalendar), findsOneWidget);
      expect(find.byType(SoundAccuracyList), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('88'), findsWidgets);
      expect(find.text('4 days'), findsOneWidget);

      // Weakest sound first.
      final stats = await repo.soundStats();
      final first = find.text('/${stats.first.ipa}/');
      final last = find.text('/${stats.last.ipa}/');
      expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(last).dy));
    });

    testWidgets('uses two columns on a tablet', (tester) async {
      await setSize(tester, const Size(820, 1180));
      final repo = await seededRepository();
      await tester.pumpWidget(
        testApp(const ProgressScreen(), overrides: overridesFor(repo: repo)),
      );
      await tester.pumpAndSettle();
      final trend = tester.getTopLeft(find.text('Score trend'));
      final calendar = tester.getTopLeft(find.text('Streak calendar'));
      expect(calendar.dx, greaterThan(trend.dx + 200));
    });

    testWidgets('refreshes after a progress write', (tester) async {
      final repo = FakeProgressRepository(clock: testClock);
      await tester.pumpWidget(
        testApp(const ProgressScreen(), overrides: overridesFor(repo: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No progress yet'), findsOneWidget);
      await tester.runAsync(
        () => repo.saveAttempt(
          goodAttempt(riverPassage, id: 'x', at: testNow, score: 90),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No progress yet'), findsNothing);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('light-tier user without sound stats sees a hint', (
      tester,
    ) async {
      await setSize(tester, const Size(390, 2400));
      final repo = FakeProgressRepository(clock: testClock);
      await repo.saveAttempt(
        AttemptResult(
          id: 'l',
          passageId: riverPassage.id,
          at: testNow,
          overall: 70,
          accuracy: 70,
          fluency: 70,
          words: const [],
          tier: ModelTier.light,
        ),
      );
      await tester.pumpWidget(
        testApp(const ProgressScreen(), overrides: overridesFor(repo: repo)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Per-sound scores need the full model'),
        findsOneWidget,
      );
    });
  });

  group('ProgressData', () {
    test('formatDay and formatShortDay', () {
      expect(formatDay(DateTime(2026, 1, 5)), '5 Jan 2026');
      expect(formatShortDay(DateTime(2026, 12, 25)), '25 Dec');
    });
  });

  group('SoundAccuracyList', () {
    testWidgets('limits rows and marks bands with icons', (tester) async {
      final at = testNow;
      await tester.pumpWidget(
        testApp(
          Material(
            child: SoundAccuracyList(
              limit: 3,
              stats: [
                SoundStat(
                  ipa: 'θ',
                  accuracy: 42,
                  attempts: 1,
                  lastPractised: at,
                ),
                SoundStat(
                  ipa: 'ɑː',
                  accuracy: 66,
                  attempts: 3,
                  lastPractised: at,
                ),
                SoundStat(
                  ipa: 'r',
                  accuracy: 91,
                  attempts: 9,
                  lastPractised: at,
                ),
                SoundStat(
                  ipa: 's',
                  accuracy: 99,
                  attempts: 9,
                  lastPractised: at,
                ),
              ],
            ),
          ),
          overrides: overridesFor(
            repo: FakeProgressRepository(clock: testClock),
          ),
        ),
      );
      expect(find.text('/s/'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.change_history), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(
        find.bySemanticsLabel('Sound θ: 42, needs work, heard 1 time'),
        findsOneWidget,
      );
    });
  });

  group('StreakCalendar', () {
    testWidgets('ticks practised days in the last five weeks', (tester) async {
      final today = DateTime(2026, 10, 19);
      await tester.pumpWidget(
        testApp(
          Material(
            child: StreakCalendar(
              today: today,
              practisedDays: [
                DateTime(2026, 10, 19),
                DateTime(2026, 10, 18),
                DateTime(2026, 8, 1), // outside the window
              ],
            ),
          ),
          overrides: overridesFor(
            repo: FakeProgressRepository(clock: testClock),
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('Practised on 2 of the last 35 days'),
        findsOneWidget,
      );
    });
  });
}
