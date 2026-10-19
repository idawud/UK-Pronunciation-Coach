import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/onboarding/onboarding_screen.dart';

import '../shell/harness.dart';

class _MockEngine extends Mock implements PracticeEngine {}

class _ThrowingVoice extends FakeVoiceService {
  @override
  Future<bool> hasBritishVoice() async => throw StateError('tts');
}

void main() {
  Future<List<Pushed>> pump(
    WidgetTester tester,
    Seeded s, {
    OnboardingStep step = OnboardingStep.welcome,
    List<Override> extra = const [],
  }) async {
    final log = <Pushed>[];
    await tester.pumpWidget(
      routerHarness(
        OnboardingScreen(initialStep: step),
        overrides: [...s.overrides, ...extra],
        log: log,
      ),
    );
    await tester.pumpAndSettle();
    return log;
  }

  /// Placement reader returning [scores] in turn (null = user backed out).
  Override reader(List<int?> scores, {List<Passage>? seen}) {
    var i = 0;
    return placementReaderProvider.overrideWithValue((context, passage) async {
      seen?.add(passage);
      final score = scores[i++];
      if (score == null) return null;
      return goodAttempt(
        passage,
        id: 'placement-$i',
        at: fixedNow(),
        score: score,
        fluency: score,
      );
    });
  }

  testWidgets('full flow: welcome to level result to Home', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    final seen = <Passage>[];
    final log = await pump(
      tester,
      s,
      extra: [
        reader([null, 90, 90, 90], seen: seen),
      ],
    );
    expect(find.text('Speak clear British English'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Microphone is ready'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Check the British voice'), findsOneWidget);
    expect(find.text('Voice: English (United Kingdom)'), findsOneWidget);
    await tester.tap(find.text('Play sample'));
    await tester.pump();
    expect(s.voice.spoken.single.$1, voiceSample);
    await tester.tap(find.text('Sounds good'));
    await tester.pumpAndSettle();

    expect(find.text('Find your level'), findsOneWidget);
    // The first read is abandoned: still on passage 1.
    await tester.tap(find.text('Read passage 1 of 3'));
    await tester.pumpAndSettle();
    expect(find.text('Read passage 1 of 3'), findsOneWidget);
    for (var i = 1; i <= 3; i++) {
      await tester.tap(find.text('Read passage $i of 3'));
      await tester.pumpAndSettle();
    }
    expect(seen.map((p) => p.level), [1, 1, 3, 5]);

    expect(find.text('You start at level 6'), findsOneWidget);
    final profile = await s.progress.profile();
    expect(profile.placementDone, isTrue);
    expect(profile.onboardingDone, isFalse);

    await tester.tap(find.text('Start practising'));
    await tester.pumpAndSettle();
    expect((await s.progress.profile()).onboardingDone, isTrue);
    expect(find.text('Speak clear British English'), findsNothing);
    expect(log, isEmpty, reason: 'went to Home, which is the harness root');
  });

  testWidgets('back button returns to the previous step', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    await pump(tester, s, step: OnboardingStep.voice);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Microphone is ready'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('microphone denied: allow grants it', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    s.recorder.permission = MicPermission.denied;
    await pump(tester, s, step: OnboardingStep.microphone);
    expect(find.text('Allow the microphone'), findsOneWidget);
    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();
    expect(find.text('Microphone is ready'), findsOneWidget);
  });

  testWidgets('microphone denied: not now moves on', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    s.recorder.permission = MicPermission.denied;
    await pump(tester, s, step: OnboardingStep.microphone);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Check the British voice'), findsOneWidget);
  });

  testWidgets('microphone permanently denied opens settings', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    s.recorder.permission = MicPermission.permanentlyDenied;
    await pump(tester, s, step: OnboardingStep.microphone);
    expect(find.text('Microphone is turned off'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(s.recorder.settingsOpened, 1);

    s.recorder.permission = MicPermission.granted;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Microphone is ready'), findsOneWidget);
  });

  testWidgets('no British voice explains how to install one', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    s.voice.britishVoice = false;
    await pump(tester, s, step: OnboardingStep.voice);
    expect(find.text('No British voice found'), findsOneWidget);
    s.voice.britishVoice = true;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Check the British voice'), findsOneWidget);
  });

  testWidgets('voice check failure counts as no voice', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    s.voice = _ThrowingVoice();
    await pump(tester, s, step: OnboardingStep.voice);
    expect(find.text('No British voice found'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Find your level'), findsOneWidget);
  });

  testWidgets('skip placement finishes at level 1', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    await pump(tester, s, step: OnboardingStep.placement);
    await tester.tap(find.text('Skip and start at level 1'));
    await tester.pumpAndSettle();
    final p = await s.progress.profile();
    expect(p.onboardingDone, isTrue);
    expect(p.placementDone, isFalse);
    expect(p.level, 1);
  });

  testWidgets('placement load error retries', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    final engine = _MockEngine();
    var fail = true;
    when(engine.placementPassages).thenAnswer((_) async {
      if (fail) throw StateError('x');
      return samplePassages;
    });
    s.engineOverride = engine;
    await pump(tester, s, step: OnboardingStep.placement);
    expect(find.text('Could not load the reading test.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Find your level'), findsOneWidget);
  });

  testWidgets('a failing read asks to try again', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    await pump(
      tester,
      s,
      step: OnboardingStep.placement,
      extra: [
        placementReaderProvider.overrideWithValue(
          (context, passage) async => throw StateError('scoring'),
        ),
      ],
    );
    await tester.tap(find.text('Read passage 1 of 3'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try that one again.'),
      findsOneWidget,
    );
  });

  testWidgets('result falls back to level 1 if the level cannot be read', (
    tester,
  ) async {
    final s = await seedEmpty(onboardingDone: false);
    final engine = _MockEngine();
    when(engine.currentLevel).thenThrow(StateError('x'));
    s.engineOverride = engine;
    await pump(tester, s, step: OnboardingStep.result);
    expect(find.text('You start at level 1'), findsOneWidget);
    expect(find.text('All set'), findsOneWidget);
  });

  testWidgets('loading states show a spinner', (tester) async {
    final s = await seedEmpty(onboardingDone: false);
    await tester.pumpWidget(
      harness(
        const OnboardingScreen(initialStep: OnboardingStep.microphone),
        overrides: s.overrides,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
