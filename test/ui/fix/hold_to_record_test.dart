import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/fix/hold_to_record.dart';

import '../results/harness.dart';

class _MockRecognizer extends Mock implements PhonemeRecognizer {}

class _StartFails extends FakeAudioRecorder {
  @override
  Future<void> start() async => throw StateError('mic busy');
}

class _PermissionOnStart extends FakeAudioRecorder {
  @override
  Future<void> start() async =>
      throw const MicPermissionException(MicPermission.denied);
}

void main() {
  final word = riverPassage.words[1];

  Future<List<WordResult>> pump(
    WidgetTester tester, {
    FakeAudioRecorder? recorder,
    PhonemeRecognizer? recognizer,
    bool show = true,
  }) async {
    final fakes = Fakes(recorder: recorder)..recognizerOverride = recognizer;
    final scored = <WordResult>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...fakes.overrides],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: show
                  ? HoldToRecordButton(word: word, onScored: scored.add)
                  : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    return scored;
  }

  testWidgets('scores a held word', (tester) async {
    final scored = await pump(tester);
    expect(find.text('Hold to say "Thursday"'), findsOneWidget);
    final g = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic_none)),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text("Release when you've finished"), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();
    expect(scored.single.score, 45);
    expect(scored.single.index, 1);
  });

  testWidgets('denied permission asks, then allows', (tester) async {
    final recorder = FakeAudioRecorder(permission: MicPermission.denied);
    final scored = await pump(tester, recorder: recorder);
    await holdAndSay(tester);
    expect(scored, isEmpty);
    expect(find.textContaining('needs the microphone'), findsOneWidget);
    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();
    expect(
      find.text('Microphone on. Hold the button and say the word.'),
      findsOneWidget,
    );
    await holdAndSay(tester);
    expect(scored, hasLength(1));
  });

  testWidgets('denied again keeps the prompt', (tester) async {
    final recorder = FakeAudioRecorder(
      permission: MicPermission.denied,
      permissionAfterRequest: MicPermission.denied,
    );
    await pump(tester, recorder: recorder);
    await holdAndSay(tester);
    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();
    expect(find.text('Allow microphone'), findsOneWidget);
  });

  testWidgets('permanently denied opens settings', (tester) async {
    final recorder = FakeAudioRecorder(
      permission: MicPermission.permanentlyDenied,
    );
    await pump(tester, recorder: recorder);
    await holdAndSay(tester);
    expect(find.textContaining('turned off for this app'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(recorder.settingsOpened, 1);
  });

  testWidgets('permission error from start shows the prompt', (tester) async {
    await pump(tester, recorder: _PermissionOnStart());
    await holdAndSay(tester);
    expect(find.text('Allow microphone'), findsOneWidget);
  });

  testWidgets('start failure shows a message', (tester) async {
    await pump(tester, recorder: _StartFails());
    await holdAndSay(tester);
    expect(
      find.text("Couldn't start the microphone. Please try again."),
      findsOneWidget,
    );
  });

  for (final (clip, message) in [
    (
      const AudioClip(
        path: '/q.wav',
        duration: Duration(seconds: 1),
        quality: AudioQuality.tooQuiet,
      ),
      'That was too quiet. Hold the phone closer and speak up.',
    ),
    (
      const AudioClip(
        path: '/n.wav',
        duration: Duration(seconds: 1),
        quality: AudioQuality.tooNoisy,
      ),
      "It's too noisy here. Try again somewhere quieter.",
    ),
    (
      const AudioClip(path: '/s.wav', duration: Duration(milliseconds: 100)),
      'Hold the button down while you say the word.',
    ),
  ]) {
    testWidgets('bad clip: $message', (tester) async {
      final scored = await pump(
        tester,
        recorder: FakeAudioRecorder(clip: clip),
      );
      await holdAndSay(tester);
      expect(scored, isEmpty);
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('scoring failure shows a message', (tester) async {
    registerFallbackValue(const AudioClip(path: '', duration: Duration.zero));
    final recognizer = _MockRecognizer();
    when(() => recognizer.loadedTier).thenReturn(ModelTier.full);
    when(() => recognizer.recognise(any())).thenThrow(StateError('no model'));
    final scored = await pump(tester, recognizer: recognizer);
    await holdAndSay(tester);
    expect(scored, isEmpty);
    expect(find.text("Couldn't score that. Please try again."), findsOneWidget);
  });

  testWidgets('leaving mid-recording cancels it', (tester) async {
    final recorder = FakeAudioRecorder();
    await pump(tester, recorder: recorder);
    final g = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic_none)),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(recorder.isRecording, isTrue);
    await pump(tester, recorder: recorder, show: false);
    await g.up();
    await tester.pump();
    expect(recorder.isRecording, isFalse);
  });
}
