import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/ui/read/read_screen.dart';
import 'package:uk_pronunciation_coach/ui/read/widgets/record_controls.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';

import '../../helpers/golden.dart';
import 'controllable_voice_read.dart';
import 'read_test_helpers.dart';

Future<ReadHarness> _pump(WidgetTester tester, ControllableVoice voice) async {
  tester.view.physicalSize = goldenPhoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = ReadHarness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...h.overrides,
        voiceServiceProvider.overrideWithValue(voice),
      ],
      child: MaterialApp(
        theme: withTestFonts(AppTheme.light()),
        home: ReadScreen(args: ReadArgs(passageId: riverPassage.id)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 200));
}

Finder _preview() => find.byType(IconButton).first;

void main() {
  group('Read screen passage preview', () {
    testWidgets('preview icon is shown once content is loaded', (tester) async {
      final voice = ControllableVoice();
      await _pump(tester, voice);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byTooltip('Listen to the passage'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsNothing);
      await _close(tester);
    });

    testWidgets('tap speaks the whole passage at normal rate', (tester) async {
      final voice = ControllableVoice();
      await _pump(tester, voice);
      await tester.tap(_preview());
      await tester.pump();
      expect(voice.spoken, [(riverPassage.text, VoiceService.normalRate)]);
      voice.finishSpeaking();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      await _close(tester);
    });

    testWidgets('while speaking the button is Stop; tapping it stops', (
      tester,
    ) async {
      final voice = ControllableVoice();
      await _pump(tester, voice);
      await tester.tap(_preview());
      await tester.pump();
      expect(find.byTooltip('Stop'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);

      await tester.tap(_preview());
      await tester.pump();
      expect(voice.stopCount, 1);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byTooltip('Listen to the passage'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('stop is called when recording starts', (tester) async {
      final voice = ControllableVoice();
      await _pump(tester, voice);
      await tester.tap(_preview());
      await tester.pump();
      expect(voice.isSpeaking, isTrue);

      await tester.tap(find.bySemanticsLabel('Start recording'));
      await tester.pump();
      expect(voice.stopCount, 1);
      expect(find.byIcon(Icons.stop), findsNothing);
      expect(find.byTooltip('Listen to the passage'), findsOneWidget);
      expect(find.byType(RecordButton), findsOneWidget);
      await _close(tester);
    });

    testWidgets('stop is called on dispose', (tester) async {
      final voice = ControllableVoice();
      await _pump(tester, voice);
      await tester.tap(_preview());
      await tester.pump();
      final before = voice.stopCount;
      await _close(tester);
      expect(voice.stopCount, greaterThan(before));
    });
  });
}
