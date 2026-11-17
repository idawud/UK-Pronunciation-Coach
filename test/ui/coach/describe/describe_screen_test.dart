import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/voice_service.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/describe/describe_content.dart';
import 'package:uk_pronunciation_coach/ui/coach/describe/describe_providers.dart';
import 'package:uk_pronunciation_coach/ui/coach/describe/describe_screen.dart';
import 'package:uk_pronunciation_coach/ui/shell/state_views.dart';

/// A timer the test fires by hand. [fire] runs the callback once, as a real periodic
/// timer would after one interval.
class _FakeTimer implements Timer {
  _FakeTimer(this._onTick);

  final void Function(Timer timer) _onTick;
  bool cancelled = false;
  int _ticks = 0;

  void fire() {
    _ticks++;
    _onTick(this);
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => _ticks;
}

/// A store whose reads always fail, to reach the error state.
class _FailingStore implements CoachStore {
  @override
  Future<Map<String, Object?>?> read(String key) async =>
      throw StateError('disk');

  @override
  Future<void> write(String key, Map<String, Object?> value) async {}

  @override
  Future<void> clear() async {}
}

/// Every prompt except [undone] is already done, so the prompt is deterministic.
Future<InMemoryCoachStore> _storeWithOnlyUndone(String undone) async {
  final store = InMemoryCoachStore();
  final done = [
    for (final p in circumlocutionPrompts)
      if (p.id != undone) p.id,
  ];
  await store.write(describeCircKey, {
    'doneIds': done,
    'lastDay': '2026-11-16',
  });
  return store;
}

Widget _app({
  required CoachStore store,
  required FakeVoiceService voice,
  CountdownTicker? ticker,
}) => ProviderScope(
  overrides: [
    coachStoreProvider.overrideWithValue(store),
    voiceServiceProvider.overrideWithValue(voice),
    clockProvider.overrideWithValue(() => DateTime(2026, 11, 17, 9, 30)),
    if (ticker != null) describeTimerProvider.overrideWithValue(ticker),
  ],
  child: const MaterialApp(home: DescribeScreen()),
);

Future<void> _pump(
  WidgetTester tester, {
  required CoachStore store,
  required FakeVoiceService voice,
  CountdownTicker? ticker,
}) async {
  await tester.pumpWidget(_app(store: store, voice: voice, ticker: ticker));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a loading view before the saved round loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(store: InMemoryCoachStore(), voice: FakeVoiceService()),
    );
    expect(find.byType(LoadingView), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(LoadingView), findsNothing);
  });

  testWidgets('a failed read shows an error view and retries', (tester) async {
    await _pump(tester, store: _FailingStore(), voice: FakeVoiceService());
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('the picked prompt avoids done prompts and shows hints', (
    tester,
  ) async {
    final store = await _storeWithOnlyUndone('stapler');
    await _pump(tester, store: store, voice: FakeVoiceService());

    expect(find.text('stapler'), findsOneWidget);
    expect(find.text('Hint 1'), findsOneWidget);
    expect(find.text('papers'), findsNothing);

    await tester.tap(find.text('Hint 1'));
    await tester.pump();
    expect(find.text('papers'), findsOneWidget);
    expect(find.text('Hint 2'), findsOneWidget);
  });

  testWidgets('Hear the word speaks the target at normal rate', (tester) async {
    final voice = FakeVoiceService();
    await _pump(
      tester,
      store: await _storeWithOnlyUndone('stapler'),
      voice: voice,
    );
    await tester.tap(find.text('Hear the word'));
    await tester.pumpAndSettle();
    expect(voice.spoken.last, ('stapler', VoiceService.normalRate));
  });

  testWidgets('Done saves progress, moves on and updates the counter', (
    tester,
  ) async {
    final store = await _storeWithOnlyUndone('stapler');
    // Leave one more prompt undone so Done has somewhere to go.
    await store.write(describeCircKey, {
      'doneIds': [
        for (final p in circumlocutionPrompts)
          if (p.id != 'stapler' && p.id != 'umbrella') p.id,
      ],
      'lastDay': '2026-11-16',
    });
    await _pump(tester, store: store, voice: FakeVoiceService());

    final total = circumlocutionPrompts.length;
    expect(find.text('${total - 2} of $total done this round'), findsOneWidget);

    // Stapler and umbrella are the two undone prompts, picked at random: whichever
    // is on screen is marked done, and the other one must come next.
    final shown = find.text('stapler').evaluate().isNotEmpty
        ? 'stapler'
        : 'umbrella';
    final next = shown == 'stapler' ? 'umbrella' : 'stapler';

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text(next), findsOneWidget);
    expect(find.text('${total - 1} of $total done this round'), findsOneWidget);
    final saved = await store.read(describeCircKey);
    expect(saved?['lastDay'], '2026-11-17');
    expect((saved?['doneIds'] as List), contains(shown));
  });

  testWidgets('completing the round resets it and says so', (tester) async {
    final store = await _storeWithOnlyUndone('stapler');
    await _pump(tester, store: store, voice: FakeVoiceService());

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final total = circumlocutionPrompts.length;
    expect(find.text('Round complete. Starting again.'), findsOneWidget);
    expect(find.text('0 of $total done this round'), findsOneWidget);
    expect((await store.read(describeCircKey))?['doneIds'], isEmpty);
  });

  testWidgets('the countdown ticks, ends at zero and is cancelled on dispose', (
    tester,
  ) async {
    final timers = <_FakeTimer>[];
    final voice = FakeVoiceService();
    await _pump(
      tester,
      store: await _storeWithOnlyUndone('stapler'),
      voice: voice,
      ticker: (interval, tick) {
        expect(interval, const Duration(seconds: 1));
        final timer = _FakeTimer(tick);
        timers.add(timer);
        return timer;
      },
    );

    await tester.tap(find.text('${describeTimerSeconds}s timer'));
    await tester.pump();
    expect(find.text('30 s left'), findsOneWidget);

    timers.single.fire();
    await tester.pump();
    expect(find.text('29 s left'), findsOneWidget);

    for (var i = 0; i < 29; i++) {
      timers.single.fire();
    }
    await tester.pump();
    expect(find.text("Time's up"), findsOneWidget);
    expect(timers.single.isActive, isFalse);

    // A timer started and left running is cancelled when the screen goes away.
    await tester.tap(find.text('${describeTimerSeconds}s timer'));
    await tester.pump();
    final running = timers.last;
    expect(running.isActive, isTrue);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(running.cancelled, isTrue);
  });

  testWidgets(
    'the Phrases tab switches tabs and plays at normal and slow rate',
    (tester) async {
      final voice = FakeVoiceService();
      await _pump(
        tester,
        store: await _storeWithOnlyUndone('stapler'),
        voice: voice,
      );
      expect(find.text('Hear the word'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Phrases'));
      await tester.pumpAndSettle();
      expect(find.text('Hear the word'), findsNothing);

      final first = phraseChunks.first.text;
      await tester.tap(find.byTooltip('Play phrase').first);
      await tester.pumpAndSettle();
      expect(voice.spoken.last, (first, VoiceService.normalRate));

      await tester.tap(find.byTooltip('Play slowly').first);
      await tester.pumpAndSettle();
      expect(voice.spoken.last, (first, VoiceService.slowRate));
    },
  );

  testWidgets('Phrases filters by group', (tester) async {
    await _pump(
      tester,
      store: await _storeWithOnlyUndone('stapler'),
      voice: FakeVoiceService(),
    );
    await tester.tap(find.widgetWithText(Tab, 'Phrases'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Hedging'));
    await tester.pumpAndSettle();
    expect(find.text('To be honest'), findsOneWidget);
    expect(find.text('To begin with'), findsNothing);
  });

  testWidgets('Practised counts a phrase and shows it as most practised', (
    tester,
  ) async {
    final store = await _storeWithOnlyUndone('stapler');
    await _pump(tester, store: store, voice: FakeVoiceService());
    await tester.tap(find.widgetWithText(Tab, 'Phrases'));
    await tester.pumpAndSettle();

    expect(find.text('Most practised'), findsNothing);
    await tester.tap(find.text('Practised').first);
    await tester.pumpAndSettle();

    final first = phraseChunks.first.text;
    expect(find.text('Most practised'), findsOneWidget);
    expect(find.text('$first · 1×'), findsWidgets);
    expect(await store.read(describeChunksKey), {
      'counts': {phraseChunks.first.id: 1},
    });
  });

  testWidgets('a failing phrase count read shows an error view', (
    tester,
  ) async {
    await _pump(tester, store: _FailingStore(), voice: FakeVoiceService());
    await tester.tap(find.widgetWithText(Tab, 'Phrases'));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('stops speech when the screen is disposed', (tester) async {
    final voice = FakeVoiceService();
    await _pump(
      tester,
      store: await _storeWithOnlyUndone('stapler'),
      voice: voice,
    );
    final before = voice.stopCount;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(voice.stopCount, greaterThan(before));
  });
}
