import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/ui/coach/coach_exercises.dart';
import 'package:uk_pronunciation_coach/ui/coach/coach_screen.dart';
import 'package:uk_pronunciation_coach/ui/shell/state_views.dart';
import 'package:uk_pronunciation_coach/ui/theme/theme.dart';

import '../shell/harness.dart';

class _MockProgress extends Mock implements ProgressRepository {}

/// A voice whose utterances last until they are stopped, like real speech.
class _HoldingVoice extends FakeVoiceService {
  Completer<void>? _current;

  @override
  Future<void> speak(String text, {double rate = 1.0}) {
    spoken.add((text, rate));
    final done = Completer<void>();
    _current = done;
    return done.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _current?.complete();
    _current = null;
  }
}

Future<List<Pushed>> _pumpCoach(
  WidgetTester tester,
  List<Override> overrides,
) async {
  final log = <Pushed>[];
  await tester.pumpWidget(
    routerHarness(const CoachScreen(), overrides: overrides, log: log),
  );
  await tester.pumpAndSettle();
  return log;
}

void main() {
  testWidgets('shows a loading view while the data loads', (tester) async {
    final progress = _MockProgress();
    final never = Completer<List<SoundStat>>();
    when(() => progress.changes).thenAnswer((_) => const Stream<void>.empty());
    when(progress.soundStats).thenAnswer((_) => never.future);
    await tester.pumpWidget(
      routerHarness(
        const CoachScreen(),
        overrides: [
          progressRepositoryProvider.overrideWithValue(progress),
          voiceServiceProvider.overrideWithValue(FakeVoiceService()),
        ],
        log: [],
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows an error view and retries', (tester) async {
    final progress = _MockProgress();
    when(() => progress.changes).thenAnswer((_) => const Stream<void>.empty());
    when(progress.soundStats).thenThrow(StateError('db'));
    await _pumpCoach(tester, [
      progressRepositoryProvider.overrideWithValue(progress),
      voiceServiceProvider.overrideWithValue(FakeVoiceService()),
    ]);
    expect(find.byType(MessageView), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    verify(progress.soundStats).called(2);
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('empty stats show the prompt and still list the library', (
    tester,
  ) async {
    final s = await seedEmpty();
    await _pumpCoach(tester, s.overrides);
    expect(
      find.text('Read a passage first and your coach will pick exercises'),
      findsOneWidget,
    );
    expect(find.text('Exercise library'), findsOneWidget);
    expect(find.text('Warm-ups'), findsOneWidget);
    expect(find.text('Loose lips'), findsOneWidget);
    expect(find.text('Practise passage'), findsNothing);
  });

  testWidgets('weak sounds get a guided card with pairs that play', (
    tester,
  ) async {
    final s = await seedEmpty();
    final backup = ProgressBackup(
      exportedAt: fixedNow(),
      profile: const UserProfile(onboardingDone: true),
      soundStats: [
        SoundStat(
          ipa: 'ɪ',
          accuracy: 30,
          attempts: 4,
          lastPractised: fixedNow(),
        ),
      ],
    );
    await s.progress.importJson(jsonEncode(backup.toJson()));
    await _pumpCoach(tester, s.overrides);

    expect(find.text(AppTypography.slashes(['ɪ'])), findsOneWidget);
    expect(find.text('Practise passage'), findsOneWidget);
    expect(find.text('ship · sheep'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'ship'));
    await tester.pumpAndSettle();
    expect(s.voice.spoken.last, ('ship', 1.0));

    await tester.tap(find.widgetWithText(TextButton, 'sheep slowly'));
    await tester.pumpAndSettle();
    expect(s.voice.spoken.last, ('sheep', VoiceService.slowRate));
  });

  testWidgets('a library play button speaks the exercise', (tester) async {
    final s = await seedEmpty();
    await _pumpCoach(tester, s.overrides);
    await tester.tap(find.byTooltip('Play Loose lips'));
    await tester.pumpAndSettle();
    final lips = coachLibrary.firstWhere((e) => e.id == 'warm-lips');
    expect(s.voice.spoken.last, (lips.speakText, lips.rate));
  });

  testWidgets('play toggles to stop while speaking', (tester) async {
    final s = await seedEmpty();
    final voice = _HoldingVoice();
    s.voice = voice;
    await _pumpCoach(tester, s.overrides);

    await tester.tap(find.byTooltip('Play Loose lips'));
    await tester.pump();
    expect(voice.spoken.length, 1);
    expect(find.byTooltip('Stop'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(voice.stopCount, 1);
    expect(find.byTooltip('Stop'), findsNothing);
    expect(find.byTooltip('Play Loose lips'), findsOneWidget);
  });

  testWidgets('speech stops when the screen is disposed', (tester) async {
    final s = await seedEmpty();
    final voice = _HoldingVoice();
    s.voice = voice;
    await _pumpCoach(tester, s.overrides);
    await tester.tap(find.byTooltip('Play Loose lips'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(voice.stopCount, 1);
  });

  testWidgets('tongue twisters are in their own section', (tester) async {
    final s = await seedEmpty();
    await _pumpCoach(tester, s.overrides);
    expect(find.text('Red lorry, yellow lorry'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Tongue twisters'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tongue twisters'));
    await tester.pumpAndSettle();
    expect(find.text('Red lorry, yellow lorry'), findsOneWidget);
  });
}
