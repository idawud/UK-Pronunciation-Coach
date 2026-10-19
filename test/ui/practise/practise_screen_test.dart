import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/practise/practise_data.dart';
import 'package:uk_pronunciation_coach/ui/practise/practise_screen.dart';

import '../shell/harness.dart';

class _MockEngine extends Mock implements PracticeEngine {}

void main() {
  Future<List<Pushed>> pump(
    WidgetTester tester,
    Seeded s, {
    PractiseTab tab = PractiseTab.library,
  }) async {
    final log = <Pushed>[];
    await tester.pumpWidget(
      routerHarness(
        PractiseScreen(initialTab: tab),
        overrides: s.overrides,
        log: log,
      ),
    );
    await tester.pumpAndSettle();
    return log;
  }

  test('PractiseTab parses the query', () {
    expect(PractiseTab.fromQuery('sounds'), PractiseTab.sounds);
    expect(PractiseTab.fromQuery('review'), PractiseTab.review);
    expect(PractiseTab.fromQuery(null), PractiseTab.library);
    expect(PractiseTab.fromQuery('nope'), PractiseTab.library);
  });

  testWidgets('library locks levels above current + 1 and opens passages', (
    tester,
  ) async {
    final s = await seedEmpty(level: 1);
    final log = await pump(tester, s);
    expect(find.text('Level 1 (your level)'), findsOneWidget);
    expect(find.text('Unlocks at level 2'), findsOneWidget); // level 3
    expect(find.text('Unlocks at level 4'), findsOneWidget); // level 5

    await tester.tap(find.text('A walk by the river'));
    await tester.pumpAndSettle();
    expect(log, isEmpty, reason: 'locked passages do not open');

    await tester.tap(find.text('Morning tea'));
    await tester.pumpAndSettle();
    expect(log.single.path, AppRoutes.read);
    expect((log.single.extra! as ReadArgs).passageId, teaPassage.id);
  });

  testWidgets('empty library, sounds and review show empty states', (
    tester,
  ) async {
    final s = Seeded(library: FakeContentRepository(passages: []));
    final log = <Pushed>[];
    await tester.pumpWidget(
      routerHarness(const PractiseScreen(), overrides: s.overrides, log: log),
    );
    await tester.pumpAndSettle();
    expect(find.text('No passages yet'), findsOneWidget);
    await tester.tap(find.text('Weak sounds'));
    await tester.pumpAndSettle();
    expect(find.text('No weak sounds yet'), findsOneWidget);
    await tester.tap(find.text('Words due'));
    await tester.pumpAndSettle();
    expect(find.text('No words due'), findsOneWidget);
  });

  testWidgets('weak sound opens a passage tagged with it', (tester) async {
    final s = await seedHistory();
    final log = await pump(tester, s, tab: PractiseTab.sounds);
    expect(find.textContaining('times heard'), findsWidgets);
    final first = (await s.engine.weakestSounds(count: 1)).single;
    await tester.tap(find.text('Practise /${first.ipa}/'));
    await tester.pumpAndSettle();
    expect(log.single.path, AppRoutes.read);
    expect((log.single.extra! as ReadArgs).mode, ReadMode.passage);
  });

  testWidgets('weak sound with no passage shows a message', (tester) async {
    final s = await seedHistory();
    final engine = _MockEngine();
    when(engine.currentLevel).thenAnswer((_) async => 3);
    when(() => engine.weakestSounds(count: practiseSoundCount))
        .thenAnswer((_) => s.engine.weakestSounds(count: practiseSoundCount));
    when(engine.dueReviews).thenAnswer((_) async => []);
    when(() => engine.nextPassage(soundTag: any(named: 'soundTag')))
        .thenThrow(StateError('none'));
    s.engineOverride = engine;
    final log = await pump(tester, s, tab: PractiseTab.sounds);
    await tester.tap(find.textContaining('Practise /').first);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text('No passage found for this sound.'), findsOneWidget);
  });

  testWidgets('due word opens Fix a word on its latest attempt', (
    tester,
  ) async {
    final s = await seedHistory();
    final log = await pump(tester, s, tab: PractiseTab.review);
    expect(find.text('Thursday'), findsOneWidget);
    expect(find.text('castle'), findsOneWidget);
    await tester.tap(find.text('castle'));
    await tester.pumpAndSettle();
    expect(log.single.path, AppRoutes.fix);
    final args = log.single.extra! as FixArgs;
    expect(args.result.id, cannedRiverAttempt.id);
    expect(args.result.words[args.wordIndexes!.single].text, 'castle');
  });

  testWidgets('error state retries', (tester) async {
    final s = await seedEmpty();
    final engine = _MockEngine();
    var fail = true;
    when(engine.currentLevel).thenAnswer((_) async {
      if (fail) throw StateError('x');
      return 1;
    });
    when(() => engine.weakestSounds(count: practiseSoundCount))
        .thenAnswer((_) async => []);
    when(engine.dueReviews).thenAnswer((_) async => []);
    s.engineOverride = engine;
    await pump(tester, s);
    expect(find.text('Something went wrong'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Level 1 (your level)'), findsOneWidget);
  });

  testWidgets('a new initial tab switches section', (tester) async {
    final s = await seedEmpty();
    final tab = ValueNotifier(PractiseTab.library);
    await tester.pumpWidget(
      harness(
        ValueListenableBuilder(
          valueListenable: tab,
          builder: (context, t, _) => PractiseScreen(initialTab: t),
        ),
        overrides: s.overrides,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No weak sounds yet'), findsNothing);
    tab.value = PractiseTab.sounds;
    await tester.pumpAndSettle();
    expect(find.text('No weak sounds yet'), findsOneWidget);
  });

  group('reviewTargetFor', () {
    test('falls back to a word retry when no attempt has the word', () async {
      final s = await seedEmpty();
      final item = ReviewItem.enqueue(
        word: 'castle',
        now: fixedNow(),
        passageId: riverPassage.id,
      );
      final target = await reviewTargetFor(
        item,
        progress: s.progress,
        content: s.content,
      );
      expect(target!.path, AppRoutes.read);
      final args = target.extra as ReadArgs;
      expect(args.mode, ReadMode.word);
      expect(riverPassage.words[args.wordIndex!].text, 'castle');
    });

    test('returns null without passage or attempt', () async {
      final s = await seedEmpty();
      expect(
        await reviewTargetFor(
          ReviewItem.enqueue(word: 'zebra', now: fixedNow()),
          progress: s.progress,
          content: s.content,
        ),
        isNull,
      );
      expect(
        await reviewTargetFor(
          ReviewItem.enqueue(word: 'zebra', now: fixedNow(), passageId: 'gone'),
          progress: s.progress,
          content: s.content,
        ),
        isNull,
      );
      expect(
        await reviewTargetFor(
          ReviewItem.enqueue(
            word: 'zebra',
            now: fixedNow(),
            passageId: riverPassage.id,
          ),
          progress: s.progress,
          content: s.content,
        ),
        isNull,
      );
    });

    test('searches recent attempts when the passage is unknown', () async {
      final s = await seedHistory();
      final target = await reviewTargetFor(
        ReviewItem.enqueue(word: 'Bath', now: fixedNow()),
        progress: s.progress,
        content: s.content,
      );
      expect(target!.path, AppRoutes.fix);
    });
  });

  test('PractiseData locks above level + 1', () {
    const d = PractiseData(level: 2, passages: [], sounds: [], due: []);
    expect(d.isLocked(3), isFalse);
    expect(d.isLocked(4), isTrue);
  });
}
