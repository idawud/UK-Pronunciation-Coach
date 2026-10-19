import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/read/read_screen.dart';
import 'package:uk_pronunciation_coach/ui/read/widgets/record_controls.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';

import '../../helpers/golden.dart';
import 'read_test_helpers.dart';

/// Opens [args] on the Read screen inside a minimal router and returns a handle.
class _App {
  _App(this.h, this.router);

  final ReadHarness h;
  final GoRouter router;
  AttemptResult? popped;
  bool poppedNull = false;
}

Future<_App> _pump(
  WidgetTester tester,
  ReadArgs args, {
  ReadHarness? harness,
  Size size = goldenPhoneSize,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = harness ?? ReadHarness();
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (_, _) => const Scaffold(body: Text('Caller')),
      ),
      GoRoute(
        path: AppRoutes.read,
        builder: (_, s) => ReadScreen(args: s.extra! as ReadArgs),
      ),
      GoRoute(
        path: AppRoutes.results,
        builder: (_, s) {
          final a = s.extra! as ResultsArgs;
          return Scaffold(
            body: Text(
              'Results ${a.result.overall} level ${a.levelChange?.to}',
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  final app = _App(h, router);
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides,
      child: MaterialApp.router(
        theme: withTestFonts(AppTheme.light()),
        routerConfig: router,
      ),
    ),
  );
  unawaited(
    router.push<AttemptResult>(AppRoutes.read, extra: args).then((r) {
      app.popped = r;
      app.poppedNull = r == null;
    }),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return app;
}

/// Unmounts everything so no timer outlives the test.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 200));
}

/// Passage mode saves through the fake repository, which checks the (fake) audio
/// file with real I/O; let that finish outside the fake clock.
Future<void> _finishSaving(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.bySemanticsLabel(label);

Future<void> _recordAndStop(WidgetTester tester) async {
  await tester.tap(_button('Start recording'));
  await tester.pump();
  await tester.tap(_button('Stop recording'));
  await tester.pumpAndSettle();
}

void main() {
  final river = ReadArgs(passageId: riverPassage.id);

  for (final (name, size) in [
    ('phone', goldenPhoneSize),
    ('tablet', goldenTabletSize),
  ]) {
    group('ReadScreen on $name', () {
      testWidgets('loading shows a spinner, then the passage', (tester) async {
        await _pump(tester, river, size: size, settle: false);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('A walk by the river'), findsOneWidget);
        expect(find.text('Level 3 · Passage 1 of 1'), findsOneWidget);
        expect(find.text(riverPassage.text), findsOneWidget);
        expect(find.text('Tap and read aloud'), findsOneWidget);
        expect(_button('Start recording'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _close(tester);
      });

      testWidgets('unknown passage shows an error with a way back', (
        tester,
      ) async {
        final app = await _pump(
          tester,
          const ReadArgs(passageId: 'missing'),
          size: size,
        );
        expect(find.text("We couldn't find this passage."), findsOneWidget);
        await tester.tap(find.text('Go back'));
        await tester.pumpAndSettle();
        expect(find.text('Caller'), findsOneWidget);
        expect(app.poppedNull, isTrue);
      });

      testWidgets('records, then scores and opens Results (passage)', (
        tester,
      ) async {
        final h = ReadHarness(
          recorder: FakeAudioRecorder(
            levels: [0.2, 0.9, 0.5],
            emitSilenceAfterLevels: false,
          ),
        );
        h.recognizer.gate = Completer<void>();
        await _pump(tester, river, harness: h, size: size);
        await tester.tap(_button('Start recording'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(LevelWaveform), findsOneWidget);
        expect(
          find.text('Stops by itself after 2 s of silence'),
          findsOneWidget,
        );
        expect(find.text('Tap to stop'), findsOneWidget);
        h.now = h.now.add(const Duration(seconds: 7));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('0:07'), findsOneWidget);

        await tester.tap(_button('Stop recording'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Scoring...'), findsOneWidget);
        expect(find.text('Listening to your sounds'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        h.recognizer.gate!.complete();
        await _finishSaving(tester);
        expect(
          find.text('Results ${cannedRiverAttempt.overall} level null'),
          findsOneWidget,
        );
        expect(h.engine.recorded, hasLength(1));
        expect(h.engine.practiceLogged, [h.recorder.clip.duration]);
      });

      testWidgets('cancel while scoring goes back to ready', (tester) async {
        final h = ReadHarness();
        h.recognizer.gate = Completer<void>();
        await _pump(tester, river, harness: h, size: size);
        await tester.tap(_button('Start recording'));
        await tester.pump();
        await tester.tap(_button('Stop recording'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(find.text('Tap and read aloud'), findsOneWidget);
        h.recognizer.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Tap and read aloud'), findsOneWidget);
        expect(h.engine.recorded, isEmpty);
        await _close(tester);
      });

      testWidgets('discard while recording', (tester) async {
        final h = ReadHarness();
        await _pump(tester, river, harness: h, size: size);
        await tester.tap(_button('Start recording'));
        await tester.pump();
        await tester.tap(find.text('Discard'));
        await tester.pump();
        expect(find.text('Tap and read aloud'), findsOneWidget);
        expect(h.recorder.isRecording, isFalse);
        await _close(tester);
      });

      testWidgets('leaving while recording cancels it', (tester) async {
        final h = ReadHarness();
        final app = await _pump(tester, river, harness: h, size: size);
        await tester.tap(_button('Start recording'));
        await tester.pump();
        expect(h.recorder.isRecording, isTrue);
        app.router.pop();
        await tester.pumpAndSettle();
        expect(h.recorder.isRecording, isFalse);
      });

      testWidgets('permission denied offers the prompt again', (tester) async {
        final h = ReadHarness(
          recorder: FakeAudioRecorder(
            permission: MicPermission.denied,
            permissionAfterRequest: MicPermission.denied,
          ),
        );
        await _pump(tester, river, harness: h, size: size);
        await tester.tap(_button('Start recording'));
        await tester.pumpAndSettle();
        expect(find.text('Microphone access is off'), findsOneWidget);
        expect(find.text('Allow microphone'), findsOneWidget);
        h.recorder.permissionAfterRequest = MicPermission.granted;
        await tester.tap(find.text('Allow microphone'));
        await tester.pumpAndSettle();
        expect(find.text('Tap and read aloud'), findsOneWidget);
        await _close(tester);
      });

      testWidgets('permanently denied opens settings and rechecks on resume', (
        tester,
      ) async {
        final h = ReadHarness(
          recorder: FakeAudioRecorder(
            permission: MicPermission.permanentlyDenied,
          ),
        );
        await _pump(tester, river, harness: h, size: size);
        await tester.tap(_button('Start recording'));
        await tester.pumpAndSettle();
        expect(find.textContaining('phone settings'), findsOneWidget);
        await tester.tap(find.text('Open settings'));
        await tester.pump();
        expect(h.recorder.settingsOpened, 1);
        h.recorder.permission = MicPermission.granted;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('Tap and read aloud'), findsOneWidget);
        await _close(tester);
      });

      for (final (quality, title) in [
        (AudioQuality.tooQuiet, 'That was too quiet'),
        (AudioQuality.tooNoisy, "It's too noisy here"),
      ]) {
        testWidgets('$quality offers a retry', (tester) async {
          final h = ReadHarness();
          h.recorder.clip = h.recorder.clip.copyWith(quality: quality);
          await _pump(tester, river, harness: h, size: size);
          await _recordAndStop(tester);
          expect(find.text(title), findsOneWidget);
          await tester.tap(find.text('Try again'));
          await tester.pump();
          expect(find.text('Tap to stop'), findsOneWidget);
          await _close(tester);
        });
      }

      testWidgets('no speech offers a retry', (tester) async {
        final h = ReadHarness(
          recorder: FakeAudioRecorder(
            levels: const [],
            emitSilenceAfterLevels: false,
            segments: const [],
          ),
        );
        await _pump(tester, river, harness: h, size: size);
        await _recordAndStop(tester);
        expect(find.text("We didn't hear you"), findsOneWidget);
        await _close(tester);
      });

      testWidgets('an error offers to try again', (tester) async {
        final h = ReadHarness();
        h.recognizer.recogniseError = StateError('boom');
        await _pump(tester, river, harness: h, size: size);
        await _recordAndStop(tester);
        expect(find.text('Something went wrong'), findsOneWidget);
        await tester.tap(find.text('Try again'));
        await tester.pump();
        expect(find.text('Tap and read aloud'), findsOneWidget);
        await _close(tester);
      });

      testWidgets('model still downloading: notice, then waits', (
        tester,
      ) async {
        final recognizer = TestRecognizer(lightAvailable: false)
          ..statusOverride = const ModelDownloadProgress(
            state: DownloadState.downloading,
            receivedBytes: 42,
            totalBytes: 100,
          );
        final h = ReadHarness(recognizer: recognizer);
        await _pump(tester, river, harness: h, size: size);
        expect(find.textContaining('still downloading (42%)'), findsOneWidget);
        expect(find.textContaining('light model'), findsOneWidget);
        await tester.tap(_button('Start recording'));
        await tester.pump();
        await tester.tap(_button('Stop recording'));
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Waiting for the speech model download'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Scoring starts when it finishes'),
          findsOneWidget,
        );
        recognizer.emitDownload(
          const ModelDownloadProgress(
            state: DownloadState.completed,
            receivedBytes: 100,
            totalBytes: 100,
          ),
        );
        await _finishSaving(tester);
        expect(find.textContaining('Results'), findsOneWidget);
      });

      testWidgets('waiting for Wi-Fi notice', (tester) async {
        final recognizer = TestRecognizer()
          ..statusOverride = const ModelDownloadProgress(
            state: DownloadState.waitingForWifi,
          );
        await _pump(
          tester,
          river,
          harness: ReadHarness(recognizer: recognizer),
          size: size,
        );
        expect(find.textContaining('when you are on Wi-Fi'), findsOneWidget);
        await _close(tester);
      });

      testWidgets('text size buttons change the passage size', (tester) async {
        final h = ReadHarness();
        await _pump(tester, river, harness: h, size: size);
        double fontSize() =>
            tester.widget<Text>(find.text(riverPassage.text)).style!.fontSize!;
        expect(fontSize(), 20);
        await tester.tap(find.byTooltip('Larger text'));
        await tester.pumpAndSettle();
        expect(fontSize(), closeTo(22, 0.01));
        await tester.tap(find.byTooltip('Smaller text'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Smaller text'));
        await tester.pumpAndSettle();
        expect(fontSize(), closeTo(18, 0.01));
        expect((await h.progress.profile()).textScale, 0.9);
        await _close(tester);
      });

      testWidgets('sentence mode pops with the result', (tester) async {
        final app = await _pump(
          tester,
          ReadArgs(
            passageId: riverPassage.id,
            mode: ReadMode.sentence,
            wordIndex: 1,
          ),
          size: size,
        );
        expect(find.text('Say the sentence'), findsOneWidget);
        expect(find.text('From "A walk by the river"'), findsOneWidget);
        expect(find.text('On Thursday we walked by the river'), findsOneWidget);
        await _recordAndStop(tester);
        expect(find.text('Caller'), findsOneWidget);
        expect(app.popped!.words.map((w) => w.index), [0, 1, 2, 3, 4, 5, 6]);
        expect(app.h.engine.recorded, isEmpty);
      });

      testWidgets('word mode shows the word and pops with it', (tester) async {
        final app = await _pump(
          tester,
          ReadArgs(
            passageId: riverPassage.id,
            mode: ReadMode.word,
            wordIndex: 11,
          ),
          size: size,
        );
        expect(find.text('Say the word'), findsOneWidget);
        expect(find.text('castle'), findsOneWidget);
        expect(find.text('Tap and say the word'), findsOneWidget);
        await _recordAndStop(tester);
        expect(app.popped!.words.single.text, 'castle');
      });

      testWidgets('placement mode pops and saves nothing', (tester) async {
        final app = await _pump(
          tester,
          ReadArgs(passageId: teaPassage.id, mode: ReadMode.placement),
          size: size,
        );
        expect(find.text('Placement test · Level 1'), findsOneWidget);
        await _recordAndStop(tester);
        expect(app.popped!.passageId, teaPassage.id);
        expect(app.h.engine.recorded, isEmpty);
        expect(app.h.engine.practiceLogged, isEmpty);
      });
    });
  }

  testWidgets('pops through the Navigator without a router', (tester) async {
    final h = ReadHarness();
    AttemptResult? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: h.overrides,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<AttemptResult>(
                  MaterialPageRoute(
                    builder: (_) => ReadScreen(
                      args: ReadArgs(
                        passageId: teaPassage.id,
                        mode: ReadMode.word,
                        wordIndex: 0,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _recordAndStop(tester);
    expect(result!.words.single.text, 'I');
  });

  group('RecordButton', () {
    testWidgets('hold mode reports press and release', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Center(
              child: RecordButton(
                recording: false,
                onHoldStart: () => events.add('down'),
                onHoldEnd: () => events.add('up'),
              ),
            ),
          ),
        ),
      );
      expect(_button('Hold to record'), findsOneWidget);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(RecordButton)),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(events, ['down', 'up']);
    });

    testWidgets('disabled ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RecordButton(
                  recording: false,
                  enabled: false,
                  onTap: () => taps++,
                ),
                const RecordButton(recording: true, onHoldStart: _noop),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(RecordButton).first);
      expect(taps, 0);
      expect(_button('Recording. Release to stop'), findsOneWidget);
    });
  });

  test('formatElapsed', () {
    expect(formatElapsed(Duration.zero), '0:00');
    expect(formatElapsed(const Duration(seconds: 75)), '1:15');
  });
}

void _noop() {}
