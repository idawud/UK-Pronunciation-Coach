import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/home/home_data.dart';
import 'package:uk_pronunciation_coach/ui/home/home_screen.dart';
import 'package:uk_pronunciation_coach/ui/home/level_info.dart';
import 'package:uk_pronunciation_coach/ui/theme/theme.dart';

import '../shell/harness.dart';

class _MockEngine extends Mock implements PracticeEngine {}

void main() {
  testWidgets('shows level, streak, minutes, weak sounds and due words', (
    tester,
  ) async {
    final s = await seedHistory();
    await tester.pumpWidget(
      harness(const HomeScreen(), overrides: s.overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.textContaining('2 of 3 passages at 85+'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('6 of 10 min'), findsOneWidget);
    expect(find.text('3 words due for review'), findsOneWidget);
    expect(find.byType(ScoreBadge), findsNWidgets(3));
    expect(find.text("Start today's passage"), findsOneWidget);
  });

  testWidgets('empty history shows friendly empty states', (tester) async {
    final s = await seedEmpty();
    await tester.pumpWidget(
      harness(const HomeScreen(), overrides: s.overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0 days'), findsOneWidget);
    expect(
      find.text('Read a passage to find the sounds to work on.'),
      findsOneWidget,
    );
    expect(find.text('No words due for review. Nice work!'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    final s = await seedEmpty();
    await tester.pumpWidget(
      harness(const HomeScreen(), overrides: s.overrides),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error state retries', (tester) async {
    final s = await seedEmpty();
    final engine = _MockEngine();
    var fail = true;
    when(engine.currentLevel).thenAnswer((_) async {
      if (fail) throw StateError('db closed');
      return 2;
    });
    when(engine.dailyProgress).thenAnswer(
      (_) async => const DailyProgress(
        streak: 1,
        minutesToday: 10,
        dailyGoalMinutes: 10,
      ),
    );
    when(() => engine.weakestSounds(count: 3)).thenAnswer((_) async => []);
    when(engine.dueReviewWords).thenAnswer((_) async => ['castle']);
    await tester.pumpWidget(
      harness(
        const HomeScreen(),
        overrides: (s..engineOverride = engine).overrides,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text("Today's goal met"), findsOneWidget);
    expect(find.text('1 word due for review'), findsOneWidget);
  });

  testWidgets('start opens Read with the next passage', (tester) async {
    final s = await seedHistory();
    final log = <Pushed>[];
    await tester.pumpWidget(
      routerHarness(const HomeScreen(), overrides: s.overrides, log: log),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Start today's passage"));
    await tester.pumpAndSettle();
    expect(log.single.path, AppRoutes.read);
    final args = log.single.extra! as ReadArgs;
    expect(args.mode, ReadMode.passage);
    expect(args.passageId, isNotEmpty);
  });

  testWidgets('start shows a message when no passage is available', (
    tester,
  ) async {
    final s = await seedEmpty();
    final engine = _MockEngine();
    when(engine.currentLevel).thenAnswer((_) async => 1);
    when(engine.dailyProgress).thenAnswer(
      (_) async =>
          const DailyProgress(streak: 0, minutesToday: 0, dailyGoalMinutes: 10),
    );
    when(() => engine.weakestSounds(count: 3)).thenAnswer((_) async => []);
    when(engine.dueReviewWords).thenAnswer((_) async => []);
    when(engine.nextPassage).thenThrow(StateError('none'));
    final log = <Pushed>[];
    await tester.pumpWidget(
      routerHarness(
        const HomeScreen(),
        overrides: (s..engineOverride = engine).overrides,
        log: log,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Start today's passage"));
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.textContaining('Could not open a passage'), findsOneWidget);
  });

  testWidgets('weak sounds and review cards open the Practise sections', (
    tester,
  ) async {
    final s = await seedHistory();
    final log = <Pushed>[];
    await tester.pumpWidget(
      routerHarness(const HomeScreen(), overrides: s.overrides, log: log),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weak sounds'));
    await tester.pumpAndSettle();
    expect(find.text('stub /practise?tab=sounds'), findsOneWidget);
  });

  testWidgets('review card opens the words-due section', (tester) async {
    final s = await seedHistory();
    final log = <Pushed>[];
    await tester.pumpWidget(
      routerHarness(const HomeScreen(), overrides: s.overrides, log: log),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Review'), 100);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('stub /practise?tab=review'), findsOneWidget);
  });

  testWidgets('tablet width puts the two cards side by side', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await seedHistory();
    await tester.pumpWidget(
      harness(const HomeScreen(), overrides: s.overrides),
    );
    await tester.pumpAndSettle();
    final weak = tester.getTopLeft(find.text('Weak sounds'));
    final review = tester.getTopLeft(find.text('Review'));
    expect(weak.dy, review.dy);
    expect(review.dx, greaterThan(weak.dx));
  });

  test('greeting follows the hour', () {
    expect(greetingFor(DateTime(2026, 1, 1, 7)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 1, 1, 21)), 'Good evening');
  });

  group('levelUpRunOf', () {
    AttemptResult a(int overall, int day) => AttemptResult(
      id: '$day',
      passageId: 'p',
      at: DateTime(2026, 10, day),
      overall: overall,
      accuracy: overall,
      fluency: overall,
      words: const [],
    );

    test('counts the newest attempts at 85+', () {
      expect(levelUpRunOf([a(90, 3), a(88, 2), a(50, 1)], null), 2);
      expect(levelUpRunOf([a(70, 3), a(90, 2)], null), 0);
      expect(levelUpRunOf([], null), 0);
    });

    test('ignores attempts before the last level change', () {
      expect(levelUpRunOf([a(90, 3), a(90, 2)], DateTime(2026, 10, 2, 12)), 1);
    });

    test('progress is full at the top level', () {
      const d = DailyProgress(streak: 0, minutesToday: 0, dailyGoalMinutes: 5);
      expect(
        const HomeData(
          level: LevelInfo.maxLevel,
          daily: d,
          weakSounds: [],
          dueWords: [],
          levelUpRun: 0,
        ).levelProgress,
        1,
      );
      expect(
        const HomeData(
          level: 2,
          daily: d,
          weakSounds: [],
          dueWords: [],
          levelUpRun: 1,
        ).levelProgress,
        closeTo(1 / 3, 1e-9),
      );
    });
  });

  test('LevelInfo describes every level and clamps', () {
    for (var l = 1; l <= 6; l++) {
      expect(LevelInfo.length(l), isNotEmpty);
      expect(LevelInfo.focus(l), isNotEmpty);
    }
    expect(LevelInfo.focus(9), LevelInfo.focus(6));
  });
}
