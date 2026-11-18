import 'dart:math';

import 'ipa_content.dart';

/// One "Quick check" question: a word to hear and the symbols to choose from.
///
/// The correct answer is always [sound]'s symbol and is always one of [options].
class IpaQuizQuestion {
  /// Creates a question.
  const IpaQuizQuestion({
    required this.sound,
    required this.word,
    required this.options,
  });

  /// The lesson sound the word contains.
  final IpaSound sound;

  /// The example word to play, without braces.
  final String word;

  /// Symbols to choose from, in the order shown. Never contains duplicates.
  final List<String> options;

  /// The correct symbol, the same as `sound.symbol`.
  String get answer => sound.symbol;
}

/// Builds one question for [target].
///
/// The word is one of [target]'s example words, picked at random. The options are
/// [target]'s symbol plus up to `optionCount - 1` distinct symbols from [pool]
/// (never the target's own symbol), shuffled. Every choice comes from [random], so a
/// seeded `Random` gives the same question each time.
///
/// [optionCount] is clamped to at least 2. When [pool] has no other symbol this
/// returns null, because there is nothing to choose between.
IpaQuizQuestion? buildIpaQuizQuestion({
  required IpaSound target,
  required List<IpaSound> pool,
  required Random random,
  int optionCount = 3,
}) {
  final count = optionCount < 2 ? 2 : optionCount;
  final candidates = {
    for (final s in pool)
      if (s.symbol != target.symbol) s.symbol,
  }.toList()..shuffle(random);
  if (candidates.isEmpty) return null;
  final options = [target.symbol, ...candidates.take(count - 1)]
    ..shuffle(random);
  final example = target.examples[random.nextInt(target.examples.length)];
  return IpaQuizQuestion(sound: target, word: example.word, options: options);
}
