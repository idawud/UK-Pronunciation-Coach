// Shared builders for the Confusions tests: attempts with chosen phoneme results and
// the minimal pair used across the section.
import 'package:uk_pronunciation_coach/core/models/models.dart';

/// A phoneme result: [expected] said as [heard] (null when judged correct), scored
/// [score].
PhonemeResult phoneme(String expected, {String? heard, int score = 90}) =>
    PhonemeResult(
      expected: expected,
      heard: heard,
      score: score,
      start: Duration.zero,
      end: const Duration(milliseconds: 100),
    );

/// A word result for [text] with [phonemes].
WordResult word(int index, String text, List<PhonemeResult> phonemes) =>
    WordResult(
      index: index,
      text: text,
      score: 50,
      phonemes: phonemes,
      status: WordStatus.fix,
    );

/// An attempt at [at] holding [words].
AttemptResult attempt(String id, DateTime at, List<WordResult> words) =>
    AttemptResult(
      id: id,
      passageId: 'fixture',
      at: at,
      overall: 50,
      accuracy: 50,
      fluency: 50,
      words: words,
    );

/// The contrast cat / cut (`æ-ʌ`), with its phonemes.
const MinimalPair catCut = MinimalPair(
  contrast: 'æ-ʌ',
  wordA: 'cat',
  wordB: 'cut',
  phonemesA: [
    PhonemeSpec(ipa: 'k'),
    PhonemeSpec(ipa: 'æ', stress: 1),
    PhonemeSpec(ipa: 't'),
  ],
  phonemesB: [
    PhonemeSpec(ipa: 'k'),
    PhonemeSpec(ipa: 'ʌ', stress: 1),
    PhonemeSpec(ipa: 't'),
  ],
);

/// Three attempts in which the user said `ʌ` as `æ` on the word "cut", at [now] minus
/// one day, so a count of three falls inside the window.
List<AttemptResult> threeUncleAttempts(DateTime now) => [
  for (var i = 0; i < 3; i++)
    attempt('swap-$i', now.subtract(Duration(days: 1, hours: i)), [
      word(0, 'cut', [phoneme('ʌ', heard: 'æ', score: 40)]),
    ]),
];
