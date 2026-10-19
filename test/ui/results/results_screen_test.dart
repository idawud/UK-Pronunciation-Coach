import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/ui/results/results_screen.dart';
import 'package:uk_pronunciation_coach/ui/results/word_sheet.dart';
import 'package:uk_pronunciation_coach/ui/theme/score_colors.dart';

import 'harness.dart';

class _MockEngine extends Mock implements PracticeEngine {}

void main() {
  final river = ResultsArgs(result: cannedRiverAttempt);

  testWidgets('shows scores, coloured passage, legend and buttons', (
    tester,
  ) async {
    await pumpResults(tester, Fakes(), river);
    expect(find.text('Results'), findsOneWidget);
    expect(find.byKey(const Key('overallScore')), findsOneWidget);
    expect(find.text('${cannedRiverAttempt.overall}'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('Fluency'), findsOneWidget);
    expect(find.text('A walk by the river'), findsOneWidget);
    expect(find.text('Good 80+'), findsOneWidget);
    expect(find.text('Close 60-79'), findsOneWidget);
    expect(find.text('Fix under 60'), findsOneWidget);
    expect(find.text('Tap any word to hear it and try again'), findsOneWidget);
    expect(find.text('Fix 3 red words'), findsOneWidget);
    expect(find.text('Next passage'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);

    // Colour plus a non-colour cue: red words underlined solid, close dotted.
    final thursday = wordStyle(tester, 'Thursday')!;
    expect(thursday.color, ScoreColors.light.fix);
    expect(thursday.decoration, TextDecoration.underline);
    expect(thursday.decorationStyle, TextDecorationStyle.solid);
    final walked = wordStyle(tester, 'walked')!;
    expect(walked.color, ScoreColors.light.close);
    expect(walked.decorationStyle, TextDecorationStyle.dotted);
    expect(wordStyle(tester, 'river')!.color, ScoreColors.light.close);
    expect(
      wordStyle(tester, 'On')!.decoration,
      isNot(TextDecoration.underline),
    );
    // Red words carry an icon (3 inline + 1 in the legend).
    expect(find.byIcon(Icons.error_outline), findsNWidgets(4));
  });

  testWidgets('tablet shows two panes', (tester) async {
    await pumpResults(tester, Fakes(), river, size: tabletSize);
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text('Fix 3 red words'), findsOneWidget);
  });

  testWidgets('shows a level up message', (tester) async {
    await pumpResults(
      tester,
      Fakes(),
      ResultsArgs(
        result: cannedRiverAttempt,
        levelChange: LevelChange(
          from: 3,
          to: 4,
          reason: 'Three passages in a row at 85 or more: welcome to level 4.',
          at: DateTime(2026, 10, 15),
        ),
      ),
    );
    expect(find.text('Level up: level 4'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
    expect(find.textContaining('Three passages in a row'), findsOneWidget);
  });

  testWidgets('shows a level down message', (tester) async {
    await pumpResults(
      tester,
      Fakes(),
      ResultsArgs(
        result: cannedRiverAttempt,
        levelChange: LevelChange(
          from: 3,
          to: 2,
          reason: 'Three passages under 60: back to level 2.',
          at: DateTime(2026, 10, 15),
        ),
      ),
    );
    expect(find.text('Back to level 2'), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);
  });

  testWidgets('tapping a word opens the sheet with sounds, tip and voice', (
    tester,
  ) async {
    final fakes = Fakes();
    await pumpResults(tester, fakes, river);
    await tapWord(tester, 'Thursday');
    expect(find.byType(WordSheet), findsOneWidget);
    expect(find.text('/θˈɜːzdeɪ/'), findsOneWidget);
    expect(find.text('/tɜːzdeɪ/'), findsOneWidget);
    expect(find.text('heard /t/'), findsOneWidget);
    expect(
      find.text('Put your tongue between your teeth and blow gently.'),
      findsOneWidget,
    );
    expect(find.text('58 Fix'), findsOneWidget);

    await tester.tap(find.text('Play British'));
    await tester.tap(find.text('Play slowly'));
    await tester.pump();
    expect(fakes.voice.spoken, [
      ('Thursday', 1.0),
      ('Thursday', VoiceService.slowRate),
    ]);
  });

  testWidgets('retry loop updates the word in place and saves it', (
    tester,
  ) async {
    final fakes = Fakes();
    await fakes.progress.saveAttempt(cannedRiverAttempt);
    await pumpResults(tester, fakes, river);
    await tapWord(tester, 'Thursday');

    await holdAndSay(tester); // 45
    expect(find.text('45 Fix'), findsOneWidget);
    expect(
      find.text('Saved. Listen again and have another go.'),
      findsOneWidget,
    );
    await holdAndSay(tester); // 72
    expect(find.text('72 Close'), findsOneWidget);
    await holdAndSay(tester); // 88
    expect(find.text('88 Good'), findsOneWidget);
    expect(find.text('Saved. Well done!'), findsOneWidget);
    expect(find.text('heard /t/'), findsNothing);
    expect(fakes.recorder.startCount, 3);
    expect(fakes.recognizer.recogniseCount, 3);
    // Full tier is not downloaded, so the light tier was loaded instead.
    expect(fakes.recognizer.loadedTier, ModelTier.light);

    final saved = await fakes.progress.attempt(cannedRiverAttempt.id);
    expect(saved!.words[1].score, 88);
    expect(saved.overall, cannedRiverAttempt.overall);

    // Close the sheet: the passage shows the new colour and one fewer red word.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(wordStyle(tester, 'Thursday')!.color, ScoreColors.light.good);
    expect(find.text('Fix 2 red words'), findsOneWidget);
  });

  testWidgets('a failed save is reported but the word still updates', (
    tester,
  ) async {
    await pumpResults(tester, Fakes(), river); // attempt not in the repository
    await tapWord(tester, 'bath');
    await holdAndSay(tester);
    expect(find.text("Couldn't save this retry."), findsOneWidget);
    expect(find.text('45 Fix'), findsOneWidget);
  });

  testWidgets('light tier shows word scores only', (tester) async {
    await pumpResults(
      tester,
      Fakes(),
      ResultsArgs(result: cannedRiverAttempt.copyWith(tier: ModelTier.light)),
    );
    expect(find.text('Light model: word scores only.'), findsOneWidget);
    await tapWord(tester, 'Thursday');
    expect(find.text('/θˈɜːzdeɪ/'), findsOneWidget);
    expect(find.text('You said'), findsNothing);
    expect(find.text('heard /t/'), findsNothing);
    expect(find.byKey(const Key('tipText')), findsNothing);
    expect(find.textContaining('Word score only.'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });

  testWidgets('missed and not-scored words explain themselves', (tester) async {
    final passage = buildPassage(
      id: 'x1',
      level: 1,
      title: 'Odd words',
      text: 'Hello Zyx world.',
      ipa: ['h ə l ˈəʊ', '', 'w ˈɜː l d'],
    );
    final attempt = buildAttempt(
      passage,
      id: 'a1',
      at: DateTime(2026),
      missedWords: {2},
    );
    final fakes = Fakes(content: FakeContentRepository(passages: [passage]));
    await pumpResults(tester, fakes, ResultsArgs(result: attempt));
    expect(find.text('Fix 1 red word'), findsOneWidget);

    await tapWord(tester, 'Zyx');
    expect(
      find.textContaining("isn't in the British dictionary"),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.mic_none), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tapWord(tester, 'world');
    expect(find.text("We didn't hear this word."), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });

  testWidgets('passage that cannot be loaded falls back to plain words', (
    tester,
  ) async {
    final fakes = Fakes(
      content: FakeContentRepository(passages: [], placement: []),
    );
    await pumpResults(tester, fakes, river);
    expect(
      find.text("Couldn't load the passage text, so retries are off."),
      findsOneWidget,
    );
    await tapWord(tester, 'Thursday');
    expect(find.text('/θɜːzdeɪ/'), findsOneWidget); // from the scored sounds
    expect(find.byIcon(Icons.mic_none), findsNothing);
  });

  testWidgets('empty attempt says nothing was scored', (tester) async {
    await pumpResults(
      tester,
      Fakes(),
      ResultsArgs(result: cannedRiverAttempt.copyWith(words: const [])),
    );
    expect(
      find.text('Nothing was scored. Try reading the passage again.'),
      findsOneWidget,
    );
    expect(find.textContaining('red word'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Next passage'), findsOneWidget);
  });

  testWidgets('no red words: Next passage is the main button', (tester) async {
    final good = goodAttempt(riverPassage, id: 'g', at: DateTime(2026));
    await pumpResults(tester, Fakes(), ResultsArgs(result: good));
    expect(find.textContaining('red word'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Next passage'), findsOneWidget);
  });

  testWidgets('Next passage opens Read for the chosen passage', (tester) async {
    final fakes = Fakes();
    await pumpResults(tester, fakes, river);
    await tester.tap(find.text('Next passage'));
    await tester.pumpAndSettle();
    expect(fakes.reads.single.mode, ReadMode.passage);
    expect(find.textContaining('read sample-'), findsOneWidget);
  });

  testWidgets('Next passage failure shows a message', (tester) async {
    final engine = _MockEngine();
    when(engine.nextPassage).thenThrow(StateError('boom'));
    final fakes = Fakes();
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakes.overrides,
          practiceEngineProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(home: ResultsScreen(args: river)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next passage'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't choose the next passage."), findsOneWidget);
  });

  testWidgets('Fix red words opens Fix and takes back its updates', (
    tester,
  ) async {
    final fakes = Fakes(scorer: FakePronunciationScorer(wordScores: [90]));
    await fakes.progress.saveAttempt(cannedRiverAttempt);
    await pumpResults(tester, fakes, river);
    await tester.tap(find.text('Fix 3 red words'));
    await tester.pumpAndSettle();
    expect(find.text('Word 1 of 3'), findsOneWidget);
    await holdAndSay(tester); // Thursday -> 90
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip')); // skip the sentence
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('Fix 2 red words'), findsOneWidget);
    expect(wordStyle(tester, 'Thursday')!.color, ScoreColors.light.good);
  });
}
