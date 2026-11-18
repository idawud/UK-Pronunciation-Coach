import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_content.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_quiz.dart';

void main() {
  final vowels = ipaSoundsIn(IpaGroup.vowels);
  final consonants = ipaSoundsIn(IpaGroup.consonants);

  test('a seeded Random gives the same question every time', () {
    final a = buildIpaQuizQuestion(
      target: consonants.first,
      pool: consonants,
      random: Random(42),
    )!;
    final b = buildIpaQuizQuestion(
      target: consonants.first,
      pool: consonants,
      random: Random(42),
    )!;
    expect(a.word, b.word);
    expect(a.options, b.options);
  });

  test('the answer is always among the options, with no duplicates', () {
    for (var seed = 0; seed < 200; seed++) {
      for (final target in ipaSounds) {
        final pool = ipaSoundsIn(target.group);
        final q = buildIpaQuizQuestion(
          target: target,
          pool: pool,
          random: Random(seed),
        )!;
        expect(q.options, contains(q.answer), reason: '${target.symbol} $seed');
        expect(
          q.options.toSet(),
          hasLength(q.options.length),
          reason: '${target.symbol} $seed',
        );
        expect(q.options, hasLength(3), reason: '${target.symbol} $seed');
      }
    }
  });

  test('the word is one of the target sound examples', () {
    for (var seed = 0; seed < 50; seed++) {
      final q = buildIpaQuizQuestion(
        target: vowels[seed % vowels.length],
        pool: vowels,
        random: Random(seed),
      )!;
      expect(q.sound.examples.map((e) => e.word), contains(q.word));
    }
  });

  test('distractors never include the target twice or come from elsewhere', () {
    final q = buildIpaQuizQuestion(
      target: vowels.first,
      pool: [...vowels, vowels.first, vowels.first],
      random: Random(3),
    )!;
    final distractors = q.options.where((o) => o != q.answer).toList();
    expect(distractors, hasLength(2));
    for (final d in distractors) {
      expect(vowels.map((s) => s.symbol), contains(d));
    }
  });

  test('optionCount sets the number of choices, with a minimum of two', () {
    final two = buildIpaQuizQuestion(
      target: vowels.first,
      pool: vowels,
      random: Random(1),
      optionCount: 2,
    )!;
    expect(two.options, hasLength(2));
    final clamped = buildIpaQuizQuestion(
      target: vowels.first,
      pool: vowels,
      random: Random(1),
      optionCount: 0,
    )!;
    expect(clamped.options, hasLength(2));
  });

  test('returns null when the pool has nothing else to choose', () {
    expect(
      buildIpaQuizQuestion(
        target: vowels.first,
        pool: [vowels.first],
        random: Random(1),
      ),
      isNull,
    );
  });
}
