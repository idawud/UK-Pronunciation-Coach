// Shared helpers for U1-home's widget and golden tests: seeded fakes with a fixed
// clock, provider overrides, and a small router with stub Read / Fix routes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';

/// Fixed "now" for every U1 test: Monday 19 October 2026, 09:30.
DateTime fixedNow() => DateTime(2026, 10, 19, 9, 30);

/// Fakes wired together with [fixedNow].
class Seeded {
  Seeded({FakeContentRepository? library})
    : progress = FakeProgressRepository(clock: fixedNow),
      content = library ?? FakeContentRepository() {
    engine = FakePracticeEngine(
      content: content,
      progress: progress,
      clock: fixedNow,
    );
  }

  final FakeProgressRepository progress;
  final FakeContentRepository content;
  late final FakePracticeEngine engine;
  final recorder = FakeAudioRecorder();
  FakeVoiceService voice = FakeVoiceService();

  /// Engine bound in [overrides] instead of [engine] (e.g. a failing mock).
  PracticeEngine? engineOverride;

  /// Provider overrides binding these fakes.
  List<Override> get overrides => [
    clockProvider.overrideWithValue(fixedNow),
    progressRepositoryProvider.overrideWithValue(progress),
    contentRepositoryProvider.overrideWithValue(content),
    practiceEngineProvider.overrideWithValue(engineOverride ?? engine),
    audioRecorderProvider.overrideWithValue(recorder),
    voiceServiceProvider.overrideWithValue(voice),
  ];
}

/// An empty store with a finished onboarding at [level].
Future<Seeded> seedEmpty({int level = 1, bool onboardingDone = true}) async {
  final s = Seeded();
  await s.progress.saveProfile(
    UserProfile(level: level, onboardingDone: onboardingDone),
  );
  return s;
}

/// A user at level 3 with the canned river attempt (Thursday, castle, bath red and due
/// for review), 2 good attempts in a row, and practice today, yesterday and the day
/// before (streak 3, 6 of 10 minutes today).
Future<Seeded> seedHistory() async {
  final s = await seedEmpty(level: 3);
  await s.engine.recordAttempt(cannedRiverAttempt);
  for (final (i, word) in ['Thursday', 'castle', 'bath'].indexed) {
    final spec = riverPassage.words.firstWhere((w) => w.text == word);
    await s.progress.upsertReview(
      ReviewItem.enqueue(
        word: word,
        phonemes: spec.phonemes,
        now: DateTime(2026, 10, 17, 8 + i),
        score: 40 + 5 * i,
        passageId: riverPassage.id,
      ),
    );
  }
  await s.progress.saveAttempt(
    goodAttempt(teaPassage, id: 'g1', at: DateTime(2026, 10, 17, 9)),
  );
  await s.progress.saveAttempt(
    goodAttempt(teaPassage, id: 'g2', at: DateTime(2026, 10, 18, 9)),
  );
  for (final day in [17, 18, 19]) {
    await s.progress.logPractice(
      PracticeSession(
        start: DateTime(2026, 10, day, 8),
        duration: Duration(minutes: day == 19 ? 6 : 12),
      ),
    );
  }
  return s;
}

/// Wraps [child] in a ProviderScope and MaterialApp with [theme].
Widget harness(
  Widget child, {
  required List<Override> overrides,
  ThemeData? theme,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: child,
  ),
);

/// Pushed route recorded by [routerHarness].
typedef Pushed = ({String path, Object? extra});

/// A router whose `/` builds [home], with stub screens for every other app route that
/// record what was opened in [log] (path + extra).
Widget routerHarness(
  Widget home, {
  required List<Override> overrides,
  required List<Pushed> log,
  ThemeData? theme,
}) {
  Widget stub(GoRouterState state) {
    log.add((path: state.matchedLocation, extra: state.extra));
    return Scaffold(body: Text('stub ${state.uri}'));
  }

  final router = GoRouter(
    routes: [
      GoRoute(path: AppRoutes.home, builder: (c, s) => home),
      for (final path in [
        AppRoutes.practise,
        AppRoutes.read,
        AppRoutes.fix,
        AppRoutes.onboarding,
      ])
        GoRoute(path: path, builder: (c, s) => stub(s)),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(theme: theme, routerConfig: router),
  );
}
