import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/confusions_providers.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/daily_session.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/daily_session_screen.dart';
import 'package:uk_pronunciation_coach/ui/shell/state_views.dart';

import '../../shell/harness.dart';
import 'confusion_fixtures.dart';

/// Content with a fixed set of minimal pairs.
class _Content extends FakeContentRepository {
  _Content(this.pairs);

  final List<MinimalPair> pairs;

  @override
  Future<List<MinimalPair>> minimalPairs() async => pairs;
}

/// A recogniser with no model on the device.
class _NoModelRecognizer extends FakePhonemeRecognizer {
  @override
  Future<bool> isTierAvailable(ModelTier tier) async => false;

  @override
  Future<void> load(ModelTier tier) async =>
      throw ModelNotAvailableException(tier);
}

/// Everything a session test needs, with the recorder and recogniser it asked for.
class _Rig {
  _Rig({
    MicPermission permission = MicPermission.granted,
    List<MinimalPair> pairs = const [catCut],
    PhonemeRecognizer? recognizer,
    this.storedStreak,
  }) : recorder = FakeAudioRecorder(permission: permission),
       recognizer = recognizer ?? FakePhonemeRecognizer(),
       scorer = FakePronunciationScorer(wordScores: const [90, 40]),
       voice = FakeVoiceService(),
       store = InMemoryCoachStore(),
       content = _Content(pairs);

  final FakeAudioRecorder recorder;
  final PhonemeRecognizer recognizer;
  final FakePronunciationScorer scorer;
  final FakeVoiceService voice;
  final InMemoryCoachStore store;
  final _Content content;
  final Map<String, Object?>? storedStreak;
  late final FakeProgressRepository progress;

  Future<void> seed() async {
    progress = FakeProgressRepository(clock: fixedNow);
    await progress.saveProfile(
      const UserProfile(level: 1, onboardingDone: true),
    );
    for (final a in threeUncleAttempts(fixedNow())) {
      await progress.saveAttempt(a);
    }
    final prior = storedStreak;
    if (prior != null) {
      await store.write('confusions', prior);
    }
  }

  List<Override> get overrides => [
    clockProvider.overrideWithValue(fixedNow),
    progressRepositoryProvider.overrideWithValue(progress),
    contentRepositoryProvider.overrideWithValue(content),
    audioRecorderProvider.overrideWithValue(recorder),
    voiceServiceProvider.overrideWithValue(voice),
    phonemeRecognizerProvider.overrideWithValue(recognizer),
    pronunciationScorerProvider.overrideWithValue(scorer),
    coachStoreProvider.overrideWithValue(store),
  ];
}

Future<void> _open(WidgetTester tester, _Rig rig) async {
  await rig.seed();
  await tester.pumpWidget(
    harness(const DailySessionScreen(), overrides: rig.overrides),
  );
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view and taps it, then lets the frame settle.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) =>
    _tap(tester, find.widgetWithText(FilledButton, 'Next'));

/// Presses the hold-to-say control, keeps it down briefly, then releases it.
Future<void> _holdToSay(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(const Key('holdToSay'))),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the session shows the first step and its progress', (
    tester,
  ) async {
    final rig = _Rig();
    await _open(tester, rig);
    expect(find.text("Today's session"), findsOneWidget);
    expect(find.text('Step 1 of 8'), findsOneWidget);
    expect(find.text('Listen slowly. Hear the vowel change.'), findsOneWidget);
    expect(find.text('cat  ·  cut'), findsOneWidget);
  });

  testWidgets('Play speaks both words of the pair slowly', (tester) async {
    final rig = _Rig();
    await _open(tester, rig);
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Play'));
    expect(rig.voice.spoken, [
      ('cat', VoiceService.slowRate),
      ('cut', VoiceService.slowRate),
    ]);
  });

  testWidgets('a full session: listen, say with verdicts, then streak saved', (
    tester,
  ) async {
    final rig = _Rig();
    await _open(tester, rig);

    // Steps 1 and 2: listen.
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Play'));
    await _next(tester);
    expect(find.text('Now listen at normal speed.'), findsOneWidget);
    await _next(tester);

    // Step 3: say "cat" and hear the estimate.
    expect(find.text('Say "cat" clearly.'), findsOneWidget);
    await _holdToSay(tester);
    expect(find.text("Sounds like 'cat'. Nice."), findsOneWidget);
    expect(
      find.text('Estimate from the on-device model, not a score.'),
      findsOneWidget,
    );
    await _next(tester);

    // Step 4: say "cut"; the model fits "cat" better, so a listener may hear that.
    expect(find.text('Now say "cut".'), findsOneWidget);
    await _holdToSay(tester);
    expect(
      find.text("You said 'cut'; a listener may hear 'cat'."),
      findsOneWidget,
    );
    await _next(tester);

    // Steps 5 to 7 (the repeat round), then the last step ends the session.
    await _next(tester);
    await _next(tester);
    await _next(tester);
    expect(find.text('Step 8 of 8'), findsOneWidget);
    await _holdToSay(tester);
    await _tap(tester, find.widgetWithText(FilledButton, 'Finish'));

    expect(find.text('Session done'), findsOneWidget);
    expect(
      find.text('1-day streak. Come back tomorrow to keep it going.'),
      findsOneWidget,
    );
    expect(await rig.store.read('confusions'), {
      'lastSessionDate': '2026-10-19',
      'streak': 1,
    });
  });

  testWidgets('finishing the day after a session extends the streak', (
    tester,
  ) async {
    final rig = _Rig(
      storedStreak: {'lastSessionDate': '2026-10-18', 'streak': 4},
    );
    await _open(tester, rig);
    for (var i = 0; i < 7; i++) {
      await _next(tester);
    }
    await _tap(tester, find.widgetWithText(FilledButton, 'Finish'));
    expect(
      find.text('5-day streak. Come back tomorrow to keep it going.'),
      findsOneWidget,
    );
    expect(await rig.store.read('confusions'), {
      'lastSessionDate': '2026-10-19',
      'streak': 5,
    });
  });

  testWidgets('a denied microphone offers to allow it', (tester) async {
    final rig = _Rig(permission: MicPermission.denied);
    await _open(tester, rig);
    await _next(tester);
    await _next(tester);
    await _holdToSay(tester);
    expect(find.text('Allow microphone'), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);
  });

  testWidgets('a permanently denied microphone points to settings', (
    tester,
  ) async {
    final rig = _Rig(permission: MicPermission.permanentlyDenied);
    await _open(tester, rig);
    await _next(tester);
    await _next(tester);
    await _holdToSay(tester);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.textContaining('turned off for this app'), findsOneWidget);
  });

  testWidgets('with no model on the device the step says so', (tester) async {
    final rig = _Rig(recognizer: _NoModelRecognizer());
    await _open(tester, rig);
    await _next(tester);
    await _next(tester);
    await _holdToSay(tester);
    expect(
      find.textContaining("The speech model isn't available"),
      findsOneWidget,
    );
    expect(find.text("Sounds like 'cat'. Nice."), findsNothing);
  });

  testWidgets('no pairs gives an empty session message', (tester) async {
    final rig = _Rig(pairs: const []);
    await rig.seed();
    await tester.pumpWidget(
      harness(const DailySessionScreen(), overrides: rig.overrides),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing to practise yet'), findsOneWidget);
  });

  testWidgets('the loading view shows while the session builds', (
    tester,
  ) async {
    final rig = _Rig();
    await rig.seed();
    final never = Completer<List<SessionStep>>();
    await tester.pumpWidget(
      harness(
        const DailySessionScreen(),
        overrides: [
          ...rig.overrides,
          dailySessionProvider.overrideWith((ref) => never.future),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
  });
}
