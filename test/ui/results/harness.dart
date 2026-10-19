// Shared test harness for Results and Fix a word (U3-results): a GoRouter with the
// screen under test, the real Fix route and a stub Read route, plus helpers to tap a
// word in the coloured passage and to hold the record button.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/ui/fix/fix_screen.dart';
import 'package:uk_pronunciation_coach/ui/results/results_screen.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';

/// Fakes used by one test, with handles to inspect them.
class Fakes {
  Fakes({
    FakeAudioRecorder? recorder,
    FakeContentRepository? content,
    FakeProgressRepository? progress,
    FakePronunciationScorer? scorer,
    FakePhonemeRecognizer? recognizer,
  }) : recorder = recorder ?? FakeAudioRecorder(),
       content = content ?? FakeContentRepository(),
       progress = progress ?? FakeProgressRepository(),
       scorer = scorer ?? FakePronunciationScorer(),
       recognizer = recognizer ?? FakePhonemeRecognizer();

  final FakeAudioRecorder recorder;
  final FakeContentRepository content;
  final FakeProgressRepository progress;
  final FakePronunciationScorer scorer;
  final FakePhonemeRecognizer recognizer;
  final FakeVoiceService voice = FakeVoiceService();

  /// Replaces [recognizer] in [overrides] (e.g. a mock that fails).
  PhonemeRecognizer? recognizerOverride;

  /// What the stub Read route pops with; null pops with nothing.
  AttemptResult? Function(ReadArgs args) readResult = (_) => null;

  /// Every ReadArgs the stub Read route was opened with.
  final List<ReadArgs> reads = [];

  /// What the Fix screen popped with when opened from the launcher.
  AttemptResult? fixReturned;
  bool fixClosed = false;

  List<Override> get overrides => [
    audioRecorderProvider.overrideWithValue(recorder),
    contentRepositoryProvider.overrideWithValue(content),
    progressRepositoryProvider.overrideWithValue(progress),
    pronunciationScorerProvider.overrideWithValue(scorer),
    phonemeRecognizerProvider.overrideWithValue(
      recognizerOverride ?? recognizer,
    ),
    voiceServiceProvider.overrideWithValue(voice),
    tipsProvider.overrideWithValue(FakeTips()),
  ];
}

/// Phone size used by widget tests.
const Size phoneSize = Size(390, 844);

/// Tablet size used by widget tests.
const Size tabletSize = Size(820, 1180);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

GoRouter _router(Fakes fakes, Widget Function(BuildContext) home) => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, _) => home(context)),
    GoRoute(
      path: AppRoutes.fix,
      builder: (_, state) => FixScreen(args: state.extra! as FixArgs),
    ),
    GoRoute(
      path: AppRoutes.read,
      builder: (_, state) {
        final args = state.extra! as ReadArgs;
        fakes.reads.add(args);
        return _ReadStub(args: args, fakes: fakes);
      },
    ),
    GoRoute(path: AppRoutes.home, builder: (_, _) => const Text('home')),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  Fakes fakes,
  Widget Function(BuildContext) home, {
  Size size = phoneSize,
  bool dark = false,
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: fakes.overrides,
      child: MaterialApp.router(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        routerConfig: _router(fakes, home),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps Results for [args].
Future<void> pumpResults(
  WidgetTester tester,
  Fakes fakes,
  ResultsArgs args, {
  Size size = phoneSize,
}) => _pump(tester, fakes, (_) => ResultsScreen(args: args), size: size);

/// Pumps a launcher, then opens Fix a word with [args] on top of it.
Future<void> pumpFix(
  WidgetTester tester,
  Fakes fakes,
  FixArgs args, {
  Size size = phoneSize,
}) async {
  await _pump(
    tester,
    fakes,
    (context) => Scaffold(
      body: TextButton(
        onPressed: () async {
          fakes.fixReturned = await GoRouter.of(context)
              .push<AttemptResult>(AppRoutes.fix, extra: args);
          fakes.fixClosed = true;
        },
        child: const Text('open fix'),
      ),
    ),
    size: size,
  );
  await tester.tap(find.text('open fix'));
  await tester.pumpAndSettle();
}

class _ReadStub extends StatelessWidget {
  const _ReadStub({required this.args, required this.fakes});

  final ReadArgs args;
  final Fakes fakes;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('read ${args.passageId} ${args.mode.name} ${args.wordIndex}'),
        TextButton(
          onPressed: () => context.pop(fakes.readResult(args)),
          child: const Text('finish reading'),
        ),
      ],
    ),
  );
}

/// Taps [word] in the passage text with key [key].
Future<void> tapWord(
  WidgetTester tester,
  String word, {
  Key key = const Key('resultsPassage'),
}) async {
  final rich = tester.widget<RichText>(
    find.descendant(of: find.byKey(key), matching: find.byType(RichText)).first,
  );
  var tapped = false;
  rich.text.visitChildren((span) {
    if (span is TextSpan &&
        span.text == word &&
        span.recognizer is TapGestureRecognizer) {
      (span.recognizer! as TapGestureRecognizer).onTap!();
      tapped = true;
      return false;
    }
    return true;
  });
  expect(tapped, isTrue, reason: 'no tappable span "$word"');
  await tester.pumpAndSettle();
}

/// Text style of [word] in the passage text with key [key].
TextStyle? wordStyle(
  WidgetTester tester,
  String word, {
  Key key = const Key('resultsPassage'),
}) {
  final rich = tester.widget<RichText>(
    find.descendant(of: find.byKey(key), matching: find.byType(RichText)).first,
  );
  TextStyle? style;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text == word) {
      style = span.style;
      return false;
    }
    return true;
  });
  return style;
}

/// Presses and releases the hold-to-record button, letting scoring finish.
Future<void> holdAndSay(WidgetTester tester) async {
  final mic = find.byIcon(Icons.mic_none);
  await tester.ensureVisible(mic);
  await tester.pumpAndSettle();
  final gesture = await tester.startGesture(tester.getCenter(mic));
  await tester.pump(const Duration(milliseconds: 120));
  await gesture.up();
  await tester.pumpAndSettle();
}
