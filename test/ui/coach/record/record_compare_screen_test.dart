import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/voice_service.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/record/practice_lines.dart';
import 'package:uk_pronunciation_coach/ui/coach/record/record_compare_screen.dart';
import 'package:uk_pronunciation_coach/ui/coach/record/record_widgets.dart';

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

class ScreenHarness {
  ScreenHarness({
    required this.recorder,
    required this.voice,
    required this.store,
  });

  final FakeAudioRecorder recorder;
  final FakeVoiceService voice;
  final InMemoryCoachStore store;
}

Future<ScreenHarness> pumpScreen(
  WidgetTester tester, {
  FakeAudioRecorder? recorder,
  FakeVoiceService? voice,
  InMemoryCoachStore? store,
}) async {
  final h = ScreenHarness(
    recorder: recorder ?? FakeAudioRecorder(),
    voice: voice ?? FakeVoiceService(),
    store: store ?? InMemoryCoachStore(),
  );
  // Tall enough that every section is built and hit-testable without scrolling.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioRecorderProvider.overrideWithValue(h.recorder),
        voiceServiceProvider.overrideWithValue(h.voice),
        coachStoreProvider.overrideWithValue(h.store),
      ],
      child: const MaterialApp(home: RecordCompareScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

/// Scrolls the lazy list until [key] is built, then taps it.
Future<void> tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(finder);
}

/// Holds the record button down for a while, then lets go.
Future<void> holdToRecord(WidgetTester tester) async {
  final listener = find.descendant(
    of: find.byType(RecordButton),
    matching: find.byType(Listener),
  );
  final gesture = await tester.startGesture(tester.getCenter(listener.first));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking a line from the list makes it the line to speak', (
    tester,
  ) async {
    final h = await pumpScreen(tester);
    final line = practiceLines[2];

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(line).last);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      line,
    );
    await tapKey(tester, const Key('listenNormal'));
    await tester.pumpAndSettle();
    expect(h.voice.spoken.last, (line, VoiceService.normalRate));

    await tapKey(tester, const Key('listenSlow'));
    await tester.pumpAndSettle();
    expect(h.voice.spoken.last, (line, VoiceService.slowRate));
  });

  testWidgets('recording shows the pace readout', (tester) async {
    await pumpScreen(tester);
    expect(
      find.text('Record a reading to see your pace and pauses.'),
      findsOneWidget,
    );

    await holdToRecord(tester);

    expect(find.text('Your reading'), findsOneWidget);
    // The compare table repeats the labels, so the readout is one of several matches.
    expect(find.text('Speaking time'), findsWidgets);
    expect(find.text('Words per minute (estimate)'), findsOneWidget);
    expect(find.text('Pauses over 0.4 s'), findsWidgets);
    expect(find.text('Longest pause'), findsOneWidget);
  });

  testWidgets('a permission-denied record shows the allow prompt', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      recorder: FakeAudioRecorder(permission: MicPermission.denied),
    );
    await holdToRecord(tester);
    expect(find.text('Allow microphone'), findsOneWidget);
    expect(find.text('Your reading'), findsNothing);
  });

  testWidgets('a permanently denied record offers the settings', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      recorder: FakeAudioRecorder(permission: MicPermission.permanentlyDenied),
    );
    await holdToRecord(tester);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('compare speaks the model line and stop cancels it', (
    tester,
  ) async {
    final voice = _HoldingVoice();
    await pumpScreen(tester, voice: voice);

    await tapKey(tester, const Key('compareModel'));
    await tester.pump();
    expect(voice.spoken.last, (practiceLines.first, VoiceService.normalRate));
    expect(find.text('Stop'), findsOneWidget);

    await tapKey(tester, const Key('compareModel'));
    await tester.pumpAndSettle();
    expect(voice.stopCount, greaterThan(0));
    expect(find.text('Hear the model line'), findsOneWidget);
  });

  testWidgets('shadowing speaks, records, scores and saves to the store', (
    tester,
  ) async {
    final store = InMemoryCoachStore();
    final recorder = FakeAudioRecorder();
    await pumpScreen(tester, recorder: recorder, store: store);

    await tapKey(tester, const Key('shadowStart'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shadowDone')), findsOneWidget);
    expect(recorder.startCount, 1);

    await tapKey(tester, const Key('shadowDone'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rhythm match'), findsOneWidget);
    expect(find.textContaining('(estimate)'), findsWidgets);

    final saved = await store.read('shadow');
    expect(saved?['scores'], isA<List<Object?>>());
    expect((saved!['scores']! as List).length, 1);
  });

  testWidgets('stop cancels shadowing before the microphone starts', (
    tester,
  ) async {
    final voice = _HoldingVoice();
    final recorder = FakeAudioRecorder();
    await pumpScreen(tester, voice: voice, recorder: recorder);

    await tapKey(tester, const Key('shadowStart'));
    await tester.pump();
    expect(find.byKey(const Key('shadowStop')), findsOneWidget);

    await tapKey(tester, const Key('shadowStop'));
    await tester.pumpAndSettle();
    expect(voice.stopCount, greaterThan(0));
    expect(recorder.startCount, 0);
    expect(find.byKey(const Key('shadowStart')), findsOneWidget);
  });
}
