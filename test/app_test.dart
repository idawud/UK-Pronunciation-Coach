import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/app.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/main.dart' as app;

void main() {
  testWidgets('app starts on onboarding on first run', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CoachApp()));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('app starts on home once onboarding is done', (tester) async {
    final progress = FakeProgressRepository();
    await progress.saveProfile(const UserProfile(onboardingDone: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [progressRepositoryProvider.overrideWithValue(progress)],
        child: const CoachApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('UK Pronunciation Coach'), findsOneWidget);
    expect(find.text("Start today's passage"), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('main() runs the app', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.byType(CoachApp), findsOneWidget);
  });

  testWidgets('start-up shows loading, then an error with Try again', (
    tester,
  ) async {
    debugUseFakesOverride = false;
    addTearDown(() => debugUseFakesOverride = true);
    final progress = FakeProgressRepository();
    var attempts = 0;
    final gate = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStoreProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) {
              await gate.future;
              throw StateError('database locked');
            }
            return progress;
          }),
          recognizerStoreProvider.overrideWith(
            (ref) async => FakePhonemeRecognizer(),
          ),
          // Everything else stays fake: this test is about start-up only.
          audioRecorderProvider.overrideWith((ref) => FakeAudioRecorder()),
          voiceServiceProvider.overrideWith((ref) => FakeVoiceService()),
          contentRepositoryProvider.overrideWith(
            (ref) => FakeContentRepository(),
          ),
        ],
        child: const CoachApp(),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text("The app couldn't start"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    // The retry runs the failed step again; this time it works.
    expect(attempts, 2);
    expect(find.text('Get started'), findsOneWidget);
  });
}
