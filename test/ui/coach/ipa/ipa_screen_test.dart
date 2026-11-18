import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/voice_service.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_content.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_providers.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_quiz.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_screen.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_sound_screen.dart';

Widget _app({
  required Widget home,
  required InMemoryCoachStore store,
  required FakeVoiceService voice,
  Random? random,
}) => ProviderScope(
  overrides: [
    coachStoreProvider.overrideWithValue(store),
    voiceServiceProvider.overrideWithValue(voice),
    ipaRandomProvider.overrideWithValue(random ?? Random(1)),
  ],
  child: MaterialApp(home: home),
);

Future<void> _pumpHub(
  WidgetTester tester, {
  required InMemoryCoachStore store,
  required FakeVoiceService voice,
  Random? random,
}) async {
  await tester.pumpWidget(
    _app(home: const IpaScreen(), store: store, voice: voice, random: random),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the widget under [key] into view, then taps it.
Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openSound(WidgetTester tester, String symbol) async {
  await tester.tap(find.text('Full chart'));
  await tester.pumpAndSettle();
  await _tapKey(tester, ValueKey('chip-$symbol'));
}

void main() {
  testWidgets('the hub shows 0 of 44 learned and a card per group', (
    tester,
  ) async {
    await _pumpHub(
      tester,
      store: InMemoryCoachStore(),
      voice: FakeVoiceService(),
    );
    expect(find.text('0 / 44 learned'), findsOneWidget);
    expect(find.text('Vowels'), findsOneWidget);
    expect(find.text('Diphthongs'), findsOneWidget);
    expect(find.text('Consonants'), findsOneWidget);
    expect(find.text('12 sounds · 0 learned'), findsOneWidget);
    expect(find.text('8 sounds · 0 learned'), findsOneWidget);
    expect(find.text('24 sounds · 0 learned'), findsOneWidget);
  });

  testWidgets('the full chart shows 44 symbol chips across the groups', (
    tester,
  ) async {
    // Tall viewport so the whole chart is built, not only the visible part.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await _pumpHub(
      tester,
      store: InMemoryCoachStore(),
      voice: FakeVoiceService(),
    );
    await tester.tap(find.text('Full chart'));
    await tester.pumpAndSettle();
    expect(find.byType(IpaSymbolChip), findsNWidgets(44));
    expect(find.byKey(const ValueKey('chip-ɡ')), findsOneWidget);
    expect(find.byKey(const ValueKey('chip-ɹ')), findsOneWidget);
  });

  testWidgets('each group page shows its own chips', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await _pumpHub(
      tester,
      store: InMemoryCoachStore(),
      voice: FakeVoiceService(),
    );
    for (final (title, count) in [
      ('Vowels', 12),
      ('Diphthongs', 8),
      ('Consonants', 24),
    ]) {
      await tester.tap(find.widgetWithText(ListTile, title));
      await tester.pumpAndSettle();
      expect(find.byType(IpaSymbolChip), findsNWidgets(count), reason: title);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the intro lesson opens from the hub', (tester) async {
    await _pumpHub(
      tester,
      store: InMemoryCoachStore(),
      voice: FakeVoiceService(),
    );
    await tester.tap(find.text('What is the IPA?'));
    await tester.pumpAndSettle();
    expect(find.text('Sounds, not spelling'), findsOneWidget);
  });

  testWidgets('a sound page shows the symbol, three examples and contrast', (
    tester,
  ) async {
    await _pumpHub(
      tester,
      store: InMemoryCoachStore(),
      voice: FakeVoiceService(),
    );
    await _openSound(tester, 'iː');
    expect(find.byType(IpaSoundScreen), findsOneWidget);
    expect(find.text('FLEECE'), findsOneWidget);
    expect(find.text('as in "see"'), findsOneWidget);
    expect(find.byKey(const ValueKey('ex-normal-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('ex-normal-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('ex-normal-2')), findsOneWidget);
    expect(find.text('Often confused with'), findsOneWidget);
    // 'sheep' is both an example and the contrast word.
    expect(find.text('sheep'), findsWidgets);
    expect(find.text('ship'), findsOneWidget);
  });

  testWidgets('play speaks the example word at normal and slow rates', (
    tester,
  ) async {
    final voice = FakeVoiceService();
    await _pumpHub(tester, store: InMemoryCoachStore(), voice: voice);
    await _openSound(tester, 'iː');

    await _tapKey(tester, const ValueKey('ex-normal-1'));
    expect(voice.spoken.last, ('beat', VoiceService.normalRate));
    expect(voice.spoken.last.$2, 1.0);

    await _tapKey(tester, const ValueKey('ex-slow-1'));
    expect(voice.spoken.last, ('beat', 0.6));
  });

  testWidgets('the contrast buttons speak each word', (tester) async {
    final voice = FakeVoiceService();
    await _pumpHub(tester, store: InMemoryCoachStore(), voice: voice);
    await _openSound(tester, 'iː');

    await _tapKey(tester, const ValueKey('contrast-a'));
    expect(voice.spoken.last.$1, 'sheep');
    await _tapKey(tester, const ValueKey('contrast-b'));
    expect(voice.spoken.last.$1, 'ship');
  });

  testWidgets('marking a sound learned persists and updates the hub', (
    tester,
  ) async {
    final store = InMemoryCoachStore();
    final voice = FakeVoiceService();
    await _pumpHub(tester, store: store, voice: voice);
    await _openSound(tester, 'θ');

    await _tapKey(tester, const ValueKey('learned-toggle'));
    expect(find.text('Learned'), findsOneWidget);
    expect(await IpaRepository(store).loadLearned(), {'θ'});

    // Sound page -> full chart -> hub.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 / 44 learned'), findsOneWidget);
    expect(find.text('12 sounds · 0 learned'), findsOneWidget);
    expect(find.text('24 sounds · 1 learned'), findsOneWidget);

    // A fresh app over the same store still shows the sound as learned.
    await tester.pumpWidget(const SizedBox());
    await _pumpHub(tester, store: store, voice: voice);
    expect(find.text('1 / 44 learned'), findsOneWidget);
    await _openSound(tester, 'θ');
    expect(find.text('Learned'), findsOneWidget);
  });

  testWidgets('unmarking a learned sound removes it', (tester) async {
    final store = InMemoryCoachStore();
    await IpaRepository(store).setLearned('θ', true);
    await _pumpHub(tester, store: store, voice: FakeVoiceService());
    await _openSound(tester, 'θ');
    expect(find.text('Learned'), findsOneWidget);
    await _tapKey(tester, const ValueKey('learned-toggle'));
    expect(find.text('Mark as learned'), findsOneWidget);
    expect(await IpaRepository(store).loadLearned(), isEmpty);
  });

  testWidgets('the quick check accepts the right answer', (tester) async {
    const seed = 7;
    final sound = ipaSoundFor('iː')!;
    final expected = buildIpaQuizQuestion(
      target: sound,
      pool: ipaSoundsIn(sound.group),
      random: Random(seed),
    )!;

    final voice = FakeVoiceService();
    await tester.pumpWidget(
      _app(
        home: IpaSoundScreen(sound: sound),
        store: InMemoryCoachStore(),
        voice: voice,
        random: Random(seed),
      ),
    );
    await tester.pumpAndSettle();

    await _tapKey(tester, const ValueKey('quiz-start'));
    expect(
      find.byKey(ValueKey('quiz-option-${expected.answer}')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('quiz-option-iː')), findsOneWidget);
    expect(expected.options, hasLength(3));

    await _tapKey(tester, const ValueKey('quiz-play'));
    expect(voice.spoken.last.$1, expected.word);

    await _tapKey(tester, ValueKey('quiz-option-${expected.answer}'));
    expect(find.textContaining('Correct.'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-next')), findsOneWidget);
  });

  testWidgets('the quick check explains a wrong answer', (tester) async {
    const seed = 7;
    final sound = ipaSoundFor('ɪ')!;
    final expected = buildIpaQuizQuestion(
      target: sound,
      pool: ipaSoundsIn(sound.group),
      random: Random(seed),
    )!;
    final wrong = expected.options.firstWhere((o) => o != expected.answer);

    await tester.pumpWidget(
      _app(
        home: IpaSoundScreen(sound: sound),
        store: InMemoryCoachStore(),
        voice: FakeVoiceService(),
        random: Random(seed),
      ),
    );
    await tester.pumpAndSettle();
    await _tapKey(tester, const ValueKey('quiz-start'));
    await _tapKey(tester, ValueKey('quiz-option-$wrong'));
    expect(find.textContaining('Not quite.'), findsOneWidget);

    // Once answered, the choices are locked.
    final other = expected.options.firstWhere(
      (o) => o != wrong && o != expected.answer,
    );
    await tester.tap(find.byKey(ValueKey('quiz-option-$other')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not quite.'), findsOneWidget);

    await _tapKey(tester, const ValueKey('quiz-next'));
    expect(find.byKey(const ValueKey('quiz-feedback')), findsNothing);
  });

  testWidgets('leaving a sound page stops speech', (tester) async {
    final voice = FakeVoiceService();
    await tester.pumpWidget(
      _app(
        home: IpaSoundScreen(sound: ipaSoundFor('ʃ')!),
        store: InMemoryCoachStore(),
        voice: voice,
      ),
    );
    await tester.pumpAndSettle();
    final before = voice.stopCount;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(voice.stopCount, greaterThan(before));
  });

  testWidgets('the hub and a sound page lay out on phone and tablet', (
    tester,
  ) async {
    for (final size in [const Size(390, 844), const Size(1024, 768)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpHub(
        tester,
        store: InMemoryCoachStore(),
        voice: FakeVoiceService(),
      );
      expect(tester.takeException(), isNull, reason: '$size hub');
      await _openSound(tester, 'ŋ');
      expect(tester.takeException(), isNull, reason: '$size sound');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
