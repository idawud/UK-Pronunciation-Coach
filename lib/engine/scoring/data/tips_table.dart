/// One-line pronunciation advice for common substitutions. Pure data.
///
/// Keys use the normalised IPA of `TableTips` (`ɛ` for DRESS, `eə` for SQUARE, `ɹ`
/// for r, `ɡ` for g, `əʊ` for GOAT).
library;

/// `expected -> heard -> advice` for specific substitutions.
const Map<String, Map<String, String>> substitutionTips = {
  'θ': {
    't': 'Put your tongue between your teeth and blow, as in "think".',
    'f': 'Use your tongue, not your lip: tongue tip between your teeth.',
    's': 'Move your tongue forward to touch your top teeth, then blow.',
    'd': 'Keep it voiceless: tongue between your teeth and push air out.',
  },
  'ð': {
    'd': 'Put your tongue between your teeth and hum, as in "this".',
    'z': 'Bring your tongue forward to your teeth, keep the buzz.',
    'v': 'Use your tongue, not your lip, against your top teeth.',
    'θ': 'Add voice: feel a buzz in your throat, as in "the".',
  },
  'ɑː': {
    'æ': "Drop your jaw for a long 'ah', as in car.",
    'ʌ': "Make it longer and further back: 'ah', as in father.",
    'ɒ': "Unround your lips and hold the long 'ah'.",
  },
  'æ': {
    'ɛ': "Open your mouth wider, as in 'cat', not 'ket'.",
    'ɑː': "Keep it short and at the front of your mouth, as in 'hat'.",
    'ʌ': "Spread your lips and open your jaw, as in 'bad'.",
  },
  'ʌ': {
    'ɒ': "Keep your lips relaxed, not round: 'cup', not 'cop'.",
    'æ': "Relax your mouth to a short central 'uh', as in 'cup'.",
    'ɑː': "Keep it short: a quick 'uh', as in 'but'.",
    'ʊ': "Unround your lips: 'luck', not 'look'.",
  },
  'ɒ': {
    'ɑː': "Round your lips for a short 'o', as in 'hot'.",
    'ɔː': "Keep it short: 'cot', not 'caught'.",
    'əʊ': "Don't glide: one short rounded 'o', as in 'got'.",
    'oʊ': "Don't glide: one short rounded 'o', as in 'got'.",
    'ʌ': "Round your lips more: 'cot', not 'cut'.",
  },
  'ɔː': {
    'ɒ': "Make it long and round your lips more: 'caught', not 'cot'.",
    'əʊ': "Hold one steady sound, don't glide: 'law', not 'low'.",
    'oʊ': "Hold one steady sound, don't glide: 'law', not 'low'.",
    'ɑː': "Round your lips tightly for 'or', as in 'door'.",
  },
  'ɜː': {
    'ɛ': "Relax your lips and tongue to a long central 'er', as in 'bird'.",
    'eə': "Keep your tongue central and lips neutral: 'fur', not 'fair'.",
    'ɑː': "Keep your mouth half open for 'er', as in 'word'.",
    'ɔː': "Unround your lips for 'er': 'work', not 'walk'.",
  },
  'ɪ': {
    'iː': "Keep it short and relaxed: 'ship', not 'sheep'.",
    'ɛ': "Raise your tongue a little: 'bit', not 'bet'.",
  },
  'iː': {'ɪ': "Make it longer and smile a little: 'sheep', not 'ship'."},
  'ʊ': {
    'uː': "Keep it short and loose: 'full', not 'fool'.",
    'ʌ': "Round your lips a little: 'look', not 'luck'.",
  },
  'uː': {'ʊ': "Make it longer, lips rounded: 'fool', not 'full'."},
  'ɛ': {
    'æ': "Close your mouth a little: 'bed', not 'bad'.",
    'eɪ': "Don't glide: one short sound, as in 'get'.",
    'ɪ': "Lower your tongue a little: 'bet', not 'bit'.",
  },
  'eɪ': {
    'ɛ': "Glide from 'e' to 'i', as in 'day'.",
    'iː': "Start lower and glide up: 'late', not 'leet'.",
  },
  'aɪ': {
    'ɑː': "Finish the glide up to 'i', as in 'my'.",
    'eɪ': "Start with your jaw open: 'right', not 'rate'.",
  },
  'əʊ': {
    'ɔː': "Start from a relaxed 'uh' and glide to 'oo', as in 'go'.",
    'oʊ': "Start from a relaxed 'uh', not a round 'o', as in British 'go'.",
    'ɒ': "Glide from 'uh' to 'oo': 'coat', not 'cot'.",
  },
  'aʊ': {'ɑː': "Glide to a rounded 'oo' at the end, as in 'now'."},
  'ɔɪ': {'ɔː': "Finish the glide up to 'i', as in 'boy'."},
  'ɪə': {'iː': "Glide to a relaxed 'uh' at the end, as in 'here'."},
  'eə': {
    'eɪ': "Glide to a relaxed 'uh', not 'i': 'fair', not 'fay'.",
    'ɛ': "Hold the sound longer, as in 'care'.",
  },
  'ʊə': {'ɔː': "Start with a short 'oo' and glide to 'uh', as in 'tour'."},
  'ə': {
    'ʌ': "Relax: this is a weak 'uh', said quickly and quietly.",
    'æ': "Don't stress it: a quick, weak 'uh'.",
    'ɛ': "Don't stress it: a quick, weak 'uh'.",
  },
  'v': {
    'w': 'Touch your top teeth to your lower lip and buzz.',
    'b': "Don't close your lips: top teeth on lower lip and buzz.",
    'f': 'Add voice: feel the buzz as your teeth touch your lip.',
  },
  'w': {'v': "Round your lips, don't touch your teeth, as in 'wet'."},
  'b': {
    'p': 'Add voice: feel your throat buzz as your lips open.',
    'v': 'Close both lips fully before you release.',
  },
  'p': {
    'b': 'Hold back the voice and let a puff of air out.',
    'f': 'Close both lips fully, then release a puff of air.',
  },
  't': {
    'd': 'Hold back the voice and release a small puff of air.',
    'ɾ': 'Make a crisp t with a puff of air, not a soft d.',
    'ʔ': "Release the t clearly; don't stop it in your throat.",
    'θ': 'Touch the ridge behind your top teeth, not the teeth.',
  },
  'd': {
    't': 'Add voice: feel your throat buzz.',
    'ð': 'Touch the ridge behind your top teeth, not the teeth.',
  },
  'k': {'ɡ': 'Hold back the voice and release a small puff of air.'},
  'ɡ': {'k': 'Add voice: feel your throat buzz.'},
  's': {
    'ʃ': 'Spread your lips and keep your tongue tip forward.',
    'z': 'No buzz: a clean hiss.',
    'θ': 'Keep your tongue behind your teeth, not between them.',
  },
  'z': {
    's': 'Add voice: let it buzz, as in "zoo".',
    'dʒ': "Keep a smooth buzz; don't stop the air first.",
  },
  'ʃ': {
    's': 'Round your lips and pull your tongue back a little.',
    'tʃ': "Keep it smooth; don't start with a t.",
  },
  'ʒ': {
    'dʒ': "Keep it smooth; don't start with a d, as in 'measure'.",
    'z': 'Round your lips and pull your tongue back, as in "vision".',
  },
  'tʃ': {
    'ʃ': "Start with a short stop: 't' + 'sh', as in 'chip'.",
    't': "Release into 'sh': 'chip', not 'tip'.",
  },
  'dʒ': {
    'ʒ': "Start with a short stop: 'd' + 'zh', as in 'jam'.",
    'j': "Press your tongue up for a 'dj' sound, as in 'jet'.",
    'z': "Pull your tongue back: 'jet', not 'zet'.",
  },
  'j': {'dʒ': "Don't touch the roof of your mouth: 'yes', not 'jess'."},
  'h': {'x': 'Breathe out softly with an open throat, no scrape.'},
  'ŋ': {
    'n': 'Lift the back of your tongue, as in "sing".',
    'ŋɡ': "End on the 'ng'; don't add a g.",
    'ŋk': "End on the 'ng'; don't add a k.",
  },
  'n': {'ŋ': 'Touch the ridge behind your top teeth with your tongue tip.'},
  'ɹ': {
    'l': "Don't touch the roof of your mouth; curl your tongue back.",
    'w': 'Pull your tongue back and up, lips only slightly round.',
  },
  'l': {
    'ɹ': 'Touch the ridge behind your top teeth with your tongue tip.',
    'n': 'Let the air flow round the sides of your tongue.',
  },
};

/// Advice when [expected] was left out (`heard` is empty).
const Map<String, String> droppedTips = {
  'h': "Don't drop the h: breathe out before the vowel, as in 'home'.",
  't': "Don't drop the t: touch the ridge behind your teeth and release.",
  'd': "Don't drop the d at the end: finish the word clearly.",
  'k': "Don't drop the k: finish the word clearly.",
  'ŋ': "End on the 'ng' sound, as in 'sing'.",
  'l': "Don't drop the l: touch the ridge behind your teeth.",
  's': 'Say the final s clearly.',
  'z': "Say the final 'z' sound clearly.",
};

/// Advice per expected sound when the specific substitution is not in the table.
const Map<String, String> generalTips = {
  'θ': 'Put your tongue between your teeth and blow, as in "think".',
  'ð': 'Put your tongue between your teeth and hum, as in "this".',
  'ɑː': "Drop your jaw for a long 'ah', as in car.",
  'ɒ': "Round your lips for a short 'o', as in 'hot'.",
  'ɔː': "Round your lips for a long 'or', as in 'door'.",
  'ɜː': "Relax your lips for a long 'er', as in 'bird'.",
  'əʊ': "Glide from a relaxed 'uh' to 'oo', as in 'go'.",
  'æ': "Open your mouth wide for a short 'a', as in 'cat'.",
  'ʌ': "A short, relaxed 'uh', as in 'cup'.",
  'v': 'Top teeth on your lower lip, and buzz.',
  'w': 'Round your lips and glide, as in "wet".',
  'ŋ': 'Lift the back of your tongue, as in "sing".',
};

/// Advice when an r is sounded after a vowel (British English is non-rhotic).
const String rhoticTip = "In British English, don't sound the r here.";
