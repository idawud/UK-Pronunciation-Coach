/// The fixed exercise library shown on the Coach tab. Pure Dart, no scoring: the
/// coach speaks a model line and the user copies it aloud.
library;

/// Groups of exercises, shown as sections of the library.
enum CoachCategory {
  /// Short mouth and lip warm-ups.
  warmUp,

  /// Tongue twisters for tricky clusters and sounds.
  tongueTwister,

  /// Paced sentences and breath control.
  paceBreathing;

  /// Section heading shown in the library.
  String get label => switch (this) {
    CoachCategory.warmUp => 'Warm-ups',
    CoachCategory.tongueTwister => 'Tongue twisters',
    CoachCategory.paceBreathing => 'Pace and breathing',
  };
}

/// One exercise: what to do ([instructions]) and what the coach says ([speakText]).
class CoachExercise {
  /// Creates an exercise. [rate] is the speech rate (0.1-2.0, 1.0 normal).
  const CoachExercise({
    required this.id,
    required this.title,
    required this.instructions,
    required this.speakText,
    required this.category,
    this.rate = 1.0,
  });

  /// Stable identifier, unique within [coachLibrary].
  final String id;

  /// Short name shown on the card.
  final String title;

  /// What the user should do while listening and speaking.
  final String instructions;

  /// The text the coach speaks.
  final String speakText;

  /// Section the exercise belongs to.
  final CoachCategory category;

  /// Speech rate for [speakText]: 1.0 normal, lower is slower.
  final double rate;
}

/// Every exercise, grouped by category in display order.
const List<CoachExercise> coachLibrary = [
  // Warm-ups.
  CoachExercise(
    id: 'warm-lips',
    title: 'Loose lips',
    instructions:
        'Relax your lips and blow gently through them, like a horse. '
        'Feel the buzz, then copy the coach.',
    speakText: 'Brr, brr, brr, brr, brr.',
    category: CoachCategory.warmUp,
  ),
  CoachExercise(
    id: 'warm-jaw',
    title: 'Jaw drop',
    instructions:
        'Let your jaw drop without tensing your neck. Hold a long, open "ah" '
        'and feel the space at the back of your mouth.',
    speakText: 'Aah. Aah. Aah. Aah.',
    category: CoachCategory.warmUp,
  ),
  CoachExercise(
    id: 'warm-vowels',
    title: 'Vowel stretch',
    instructions:
        'Say each vowel slowly and keep it steady until the next one starts. '
        'Notice where your tongue sits for each one.',
    speakText: 'ee, i, ay, eh, ah, aw, oh, oo.',
    category: CoachCategory.warmUp,
    rate: 0.8,
  ),
  CoachExercise(
    id: 'warm-smile',
    title: 'Smile and round',
    instructions:
        'Smile wide for "ee", then round your lips for "oo". Switch back and '
        'forth without letting your jaw move much.',
    speakText: 'ee, oo, ee, oo, ee, oo.',
    category: CoachCategory.warmUp,
  ),

  // Tongue twisters.
  CoachExercise(
    id: 'twister-red-lorry',
    title: 'Red lorry, yellow lorry',
    instructions:
        'Start slowly. Keep the r in red sounding light, and pick up speed only '
        'once every word is clear.',
    speakText: 'Red lorry, yellow lorry. Red lorry, yellow lorry.',
    category: CoachCategory.tongueTwister,
    rate: 0.8,
  ),
  CoachExercise(
    id: 'twister-seashells',
    title: 'She sells seashells',
    instructions:
        'Focus on the "sh" and "s" sounds: the sh is made further back in the '
        'mouth. Say it three times, then faster.',
    speakText: 'She sells seashells on the seashore. She sells seashells on the seashore.',
    category: CoachCategory.tongueTwister,
    rate: 0.8,
  ),
  CoachExercise(
    id: 'twister-thin-thrushes',
    title: 'Three thin thrushes',
    instructions:
        'Put your tongue lightly between your teeth for "th". Keep the voice '
        'off for the thin ones and on for "this" and "that".',
    speakText: 'Three thin thrushes think of thick things.',
    category: CoachCategory.tongueTwister,
    rate: 0.8,
  ),
  CoachExercise(
    id: 'twister-betty-butter',
    title: 'Betty bought butter',
    instructions:
        'Say each "t" clearly, even between words. In British speech the t in '
        'butter and bitter is often a soft flap, so aim for a clear t.',
    speakText: 'Betty bought a bit of butter, but the butter was bitter.',
    category: CoachCategory.tongueTwister,
    rate: 0.8,
  ),
  CoachExercise(
    id: 'twister-rugged-rocks',
    title: 'Round the rugged rocks',
    instructions:
        'Keep the r light and the w rounded. Do not add an r at the end of '
        'words like "ran", which British English does not sound.',
    speakText: 'Round the rugged rocks the ragged rascal ran.',
    category: CoachCategory.tongueTwister,
    rate: 0.8,
  ),

  // Pace and breathing.
  CoachExercise(
    id: 'pace-slow-sentence',
    title: 'Slow and steady',
    instructions:
        'Breathe in through your nose. Say the sentence at this slow pace, one '
        'word per breath group, and breathe out at the full stop.',
    speakText: 'The sun rises slowly over the quiet hills.',
    category: CoachCategory.paceBreathing,
    rate: 0.6,
  ),
  CoachExercise(
    id: 'pace-breath-groups',
    title: 'Breath groups',
    instructions:
        'Breathe in for a count of four. Say each phrase on one breath, pause '
        'at the commas, and breathe in again before the next phrase.',
    speakText:
        'I like a cup of tea, in the morning, with a biscuit, by the window.',
    category: CoachCategory.paceBreathing,
    rate: 0.8,
  ),
  CoachExercise(
    id: 'pace-long-vowels',
    title: 'Long vowels',
    instructions:
        'Hold each long vowel for a steady count of three and breathe out evenly '
        'through it. Do not let the sound fade at the end.',
    speakText: 'Her art is far from the park.',
    category: CoachCategory.paceBreathing,
    rate: 0.6,
  ),
];
