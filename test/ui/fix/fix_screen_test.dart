import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/fix/fix_screen.dart';
import 'package:uk_pronunciation_coach/ui/fix/sound_chips.dart';

import '../results/harness.dart';

AttemptResult _sentenceResult(ReadArgs args) {
  final range = riverPassage.sentenceRange(args.wordIndex!);
  final r = goodAttempt(
    riverPassage,
    id: 'sentence',
    at: DateTime(2026, 10, 15, 9),
  );
  return r.copyWith(
    words: [
      for (final w in r.words)
        if (w.index >= range.start && w.index < range.end) w,
    ],
  );
}

void main() {
  final river = FixArgs(result: cannedRiverAttempt);

  testWidgets('retry loop: repeat until 80+, then read the sentence once', (
    tester,
  ) async {
    final fakes = Fakes()..readResult = _sentenceResult;
    await fakes.progress.saveAttempt(cannedRiverAttempt);
    await pumpFix(tester, fakes, river);

    expect(find.text('Word 1 of 3'), findsOneWidget);
    expect(find.byKey(const Key('practiceWord')), findsOneWidget);
    expect(find.text('Thursday'), findsOneWidget);
    expect(find.text('/θˈɜːzdeɪ/'), findsOneWidget);
    expect(find.text('/tɜːzdeɪ/'), findsOneWidget);
    expect(find.byType(SoundChips), findsOneWidget);
    expect(find.text('heard /t/'), findsOneWidget);
    expect(
      find.text('Put your tongue between your teeth and blow gently.'),
      findsOneWidget,
    );
    expect(find.text('Reading score '), findsOneWidget);
    expect(find.text('  Target $fixTarget'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Play slowly'));
    await tester.pump();
    expect(fakes.voice.spoken.single, ('Thursday', VoiceService.slowRate));

    await holdAndSay(tester); // 45
    expect(find.text('Last score '), findsOneWidget);
    expect(find.text('45 Fix'), findsWidgets);
    expect(
      find.text('Not quite yet. Listen again and have another go.'),
      findsOneWidget,
    );
    expect(find.text('Next'), findsNothing);
    await holdAndSay(tester); // 72
    expect(find.text('72 Close'), findsWidgets);
    expect(find.text('Next'), findsNothing);
    await holdAndSay(tester); // 88
    expect(find.text('88 Good'), findsWidgets);
    expect(find.text('Well done! That sounds British.'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // Saved on moving on.
    final saved = await fakes.progress.attempt(cannedRiverAttempt.id);
    expect(saved!.words[1].score, 88);

    // Sentence step for "On Thursday we walked by the river."
    expect(find.text('Now say the whole sentence'), findsOneWidget);
    await tester.tap(find.text('Read the sentence'));
    await tester.pumpAndSettle();
    expect(fakes.reads.single.mode, ReadMode.sentence);
    expect(fakes.reads.single.wordIndex, 1);
    expect(fakes.reads.single.passageId, riverPassage.id);
    await tester.tap(find.text('finish reading'));
    await tester.pumpAndSettle();
    expect(find.text('Your sentence'), findsOneWidget);
    expect(find.text('Sentence score '), findsOneWidget);
    expect(find.byKey(const Key('fixSentence')), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Next red word in another sentence.
    expect(find.text('Word 2 of 3'), findsOneWidget);
    expect(find.text('castle'), findsOneWidget);
  });

  testWidgets('skipping every word saves nothing and ends with a summary', (
    tester,
  ) async {
    final fakes = Fakes();
    await fakes.progress.saveAttempt(cannedRiverAttempt);
    await pumpFix(tester, fakes, river);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Fixed 0 of 3 words'), findsOneWidget);
    expect(fakes.reads, isEmpty);
    expect(
      await fakes.progress.attempt(cannedRiverAttempt.id),
      cannedRiverAttempt,
    );

    await tester.tap(find.text('Back to results'));
    await tester.pumpAndSettle();
    expect(fakes.fixClosed, isTrue);
    expect(fakes.fixReturned, cannedRiverAttempt);
  });

  testWidgets('a skipped word with tries saves its last try', (tester) async {
    final fakes = Fakes();
    await fakes.progress.saveAttempt(cannedRiverAttempt);
    await pumpFix(
      tester,
      fakes,
      FixArgs(result: cannedRiverAttempt, wordIndexes: const [21]),
    );
    expect(find.text('Word 1 of 1'), findsOneWidget);
    await holdAndSay(tester); // 45
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Fixed 0 of 1 word'), findsOneWidget);
    expect(find.text('Was 46'), findsOneWidget);
    final saved = await fakes.progress.attempt(cannedRiverAttempt.id);
    expect(saved!.words[21].score, 45);
    await tester.tap(find.text('Back to results'));
    await tester.pumpAndSettle();
    expect(fakes.fixReturned!.words[21].score, 45);
  });

  testWidgets('words in the same sentence share one sentence step', (
    tester,
  ) async {
    final fakes = Fakes(scorer: FakePronunciationScorer(wordScores: [90]))
      ..readResult = _sentenceResult;
    await pumpFix(
      tester,
      fakes,
      FixArgs(result: cannedRiverAttempt, wordIndexes: const [1, 3]),
    );
    await holdAndSay(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // Straight to "walked" (same sentence), no sentence step yet.
    expect(find.text('Word 2 of 2'), findsOneWidget);
    expect(find.text('walked'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Now say the whole sentence'), findsOneWidget);
    await tester.tap(find.text('Read the sentence'));
    await tester.pumpAndSettle();
    expect(fakes.reads.single.wordIndex, 1);
  });

  testWidgets('leaving the sentence reading without a result moves on', (
    tester,
  ) async {
    final fakes = Fakes(scorer: FakePronunciationScorer(wordScores: [90]));
    await pumpFix(
      tester,
      fakes,
      FixArgs(result: cannedRiverAttempt, wordIndexes: const [1]),
    );
    await holdAndSay(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read the sentence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('finish reading')); // pops with null
    await tester.pumpAndSettle();
    expect(find.text('Fixed 1 of 1 word'), findsOneWidget);
  });

  testWidgets('skipping the sentence moves on', (tester) async {
    final fakes = Fakes(scorer: FakePronunciationScorer(wordScores: [90]));
    await pumpFix(
      tester,
      fakes,
      FixArgs(result: cannedRiverAttempt, wordIndexes: const [1]),
    );
    await holdAndSay(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Fixed 1 of 1 word'), findsOneWidget);
    expect(fakes.reads, isEmpty);
  });

  testWidgets('light tier hides per-sound detail', (tester) async {
    await pumpFix(
      tester,
      Fakes(),
      FixArgs(result: cannedRiverAttempt.copyWith(tier: ModelTier.light)),
    );
    expect(find.text('/θˈɜːzdeɪ/'), findsOneWidget);
    expect(find.byType(SoundChips), findsNothing);
    expect(find.text('You said'), findsNothing);
    expect(find.byKey(const Key('tipText')), findsNothing);
    expect(find.textContaining('Word score only.'), findsOneWidget);
  });

  testWidgets('no red words shows an empty state', (tester) async {
    final fakes = Fakes();
    await pumpFix(
      tester,
      fakes,
      FixArgs(result: cannedRiverAttempt, wordIndexes: const []),
    );
    expect(find.text('No red words to fix. Nice reading!'), findsOneWidget);
    await tester.tap(find.text('Back to results'));
    await tester.pumpAndSettle();
    expect(fakes.fixClosed, isTrue);
  });

  testWidgets('unknown passage shows an error state', (tester) async {
    await pumpFix(
      tester,
      Fakes(
        content: FakeContentRepository(passages: [], placement: []),
      ),
      river,
    );
    expect(
      find.text("Couldn't load these words. Go back and try again."),
      findsOneWidget,
    );
  });

  testWidgets('invalid word index shows an error state', (tester) async {
    await pumpFix(
      tester,
      Fakes(),
      FixArgs(result: cannedRiverAttempt, wordIndexes: const [99]),
    );
    expect(
      find.text("Couldn't load these words. Go back and try again."),
      findsOneWidget,
    );
  });

  testWidgets('system back returns the updated attempt', (tester) async {
    final fakes = Fakes(scorer: FakePronunciationScorer(wordScores: [90]));
    await pumpFix(tester, fakes, river);
    await holdAndSay(tester);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(fakes.fixClosed, isTrue);
    expect(fakes.fixReturned!.words[1].score, 90);
  });

  testWidgets('a failed save is reported', (tester) async {
    final fakes = Fakes(); // attempt not saved
    await pumpFix(
      tester,
      fakes,
      FixArgs(result: cannedRiverAttempt, wordIndexes: const [21]),
    );
    await holdAndSay(tester);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.textContaining("Couldn't save your try"), findsOneWidget);
  });

  testWidgets('tablet layout caps the reading width', (tester) async {
    await pumpFix(tester, Fakes(), river, size: tabletSize);
    expect(find.text('Word 1 of 3'), findsOneWidget);
    expect(tester.getSize(find.byType(ListView)).width, lessThanOrEqualTo(680));
  });
}
