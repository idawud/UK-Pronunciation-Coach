import '../contracts/tips.dart';

/// Small table-driven [Tips] (A3 ships the full 25+ entry table).
class FakeTips implements Tips {
  /// Expected IPA -> heard IPA -> tip.
  static const Map<String, Map<String, String>> table = {
    'θ': {
      't': 'Put your tongue between your teeth and blow gently.',
      'f': 'Touch your tongue to your top teeth, not your lip.',
      's': 'Put your tongue between your teeth, not behind them.',
    },
    'ð': {'d': 'Tongue between your teeth and use your voice: "this".'},
    'ɑː': {
      'æ': "Drop your jaw for a long 'ah', as in car.",
      'ɑːɹ': "In British English, don't sound the r here.",
    },
    'ɔː': {'ɔːɹ': "In British English, don't sound the r here."},
    'ɜː': {'ɜːɹ': "In British English, don't sound the r here."},
    'v': {'w': 'Touch your top teeth to your bottom lip for v.'},
    'iː': {'ɪ': 'Make it longer and smile slightly: "sheep", not "ship".'},
    'd': {'': "Don't drop the final d; finish the word."},
    't': {'': "Don't drop the final t; finish the word."},
  };

  @override
  String? tipFor(String expected, String? heard) {
    if (heard == null || heard == expected) return null;
    return table[expected]?[heard];
  }
}
