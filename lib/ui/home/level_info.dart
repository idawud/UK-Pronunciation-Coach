/// What each level practises (docs/SPEC.md, "Content and difficulty progression").
abstract final class LevelInfo {
  /// Highest level.
  static const int maxLevel = 6;

  /// Passages in a row at [levelUpScore]+ needed to move up.
  static const int levelUpRun = 3;

  /// Score that counts towards moving up.
  static const int levelUpScore = 85;

  static const _info = {
    1: ('1 sentence', 'Short vowels and clear consonants'),
    2: ('2-3 sentences', 'th sounds (think, this) and word endings'),
    3: ('A paragraph', 'Long vowels: bath, car, thought'),
    4: ('About 100 words', 'Word stress and weak forms'),
    5: ('About 150 words', 'Linking, rhythm and sentence stress'),
    6: ('About 200 words', 'Intonation and fast connected speech'),
  };

  /// Passage length at [level], e.g. "A paragraph".
  static String length(int level) => _info[level.clamp(1, maxLevel)]!.$1;

  /// Sound focus at [level].
  static String focus(int level) => _info[level.clamp(1, maxLevel)]!.$2;
}
