import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/fix/word_practice.dart';

import '../results/harness.dart';

/// I2's request 3: the full model hears many British vowels before a written r as
/// r-coloured, so a "don't sound the r" tip must not appear on a green word.
void main() {
  final word = riverPassage.words[1]; // Thursday

  WordResult resultWith(int score) => WordResult(
    index: word.index,
    text: word.text,
    score: score,
    status: WordStatus.fromScore(score),
    phonemes: [
      for (final (i, p) in word.phonemes.indexed)
        PhonemeResult(
          expected: p.ipa,
          heard: i == 1 ? '${p.ipa}ɹ' : null,
          score: i == 1 ? 70 : 95,
          start: Duration(milliseconds: 100 * i),
          end: Duration(milliseconds: 100 * i + 100),
        ),
    ],
  );

  Future<void> pump(WidgetTester tester, WordResult result) async {
    final fakes = Fakes();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...fakes.overrides],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WordPractice(result: result, word: word, onScored: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const tip = "In British English, don't sound the r here.";

  testWidgets('a green word shows no sound tip', (tester) async {
    await pump(tester, resultWith(85));
    expect(find.text(tip), findsNothing);
  });

  testWidgets('an amber word with the same sound shows the tip', (
    tester,
  ) async {
    await pump(tester, resultWith(70));
    expect(find.text(tip), findsOneWidget);
  });
}
