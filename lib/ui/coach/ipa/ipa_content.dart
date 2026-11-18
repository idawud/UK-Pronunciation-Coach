/// Static content for the "IPA lessons" section: the 44 sounds of Standard Southern
/// British English (RP), the intro lesson, and the group labels.
///
/// Symbols match the app's phoneme inventory (the Britfone normalisation used by the
/// scorer, `lib/engine/scoring/data/phoneme_map.dart`): `ɛ` for DRESS, `ɹ` for r,
/// `ɡ` (single-storey g) for g, `əʊ` for GOAT, and `tʃ` / `dʒ` for the affricates.
/// Example words are marked with braces around the sound's spelling, e.g. `sh{ee}p`.
library;

/// The three lesson groups on the hub.
enum IpaGroup {
  /// Monophthongs: one steady vowel.
  vowels(
    'Vowels',
    'Twelve single vowel sounds. Each one holds a steady position.',
  ),

  /// Diphthongs: one vowel that glides from one position to another.
  diphthongs(
    'Diphthongs',
    'Eight gliding vowels. Start the first part and move towards the second.',
  ),

  /// Consonants, grouped by how the airflow is shaped.
  consonants(
    'Consonants',
    'Twenty-four consonants, grouped by how the air is blocked or narrowed.',
  );

  const IpaGroup(this.label, this.description);

  /// Heading shown on the hub and the grid.
  final String label;

  /// One-line description shown on the grid screen.
  final String description;
}

/// How a consonant's airflow is shaped (its manner of articulation).
enum IpaManner {
  /// Air is fully blocked, then released with a small burst.
  plosive('Plosive'),

  /// Air is pushed through a narrow gap, making a hiss or buzz.
  fricative('Fricative'),

  /// A plosive that releases into a fricative.
  affricate('Affricate'),

  /// Air is blocked in the mouth and passes through the nose.
  nasal('Nasal'),

  /// Sounds close to vowels; the tongue or lips move freely.
  approximant('Approximant');

  const IpaManner(this.label);

  /// Name shown on the consonant grid and the detail page.
  final String label;
}

/// An example word, with the sound's spelling marked by braces, e.g. `sh{ee}p`.
class IpaExample {
  /// Creates an example from [marked], which must contain exactly one `{...}` pair.
  const IpaExample(this.marked);

  /// The word with braces around the part that carries the sound.
  final String marked;

  /// The plain word, braces removed.
  String get word => marked.replaceAll('{', '').replaceAll('}', '');

  /// Index in [word] where the highlighted part starts.
  int get highlightStart => marked.indexOf('{');

  /// Index in [word] just after the highlighted part.
  int get highlightEnd => marked.indexOf('}') - 1;
}

/// A commonly confused sound and a pair of words that show the difference. The
/// first word contains the lesson sound; the second contains [otherSymbol]. A null
/// [otherSymbol] means the confusion is with silence (a dropped sound).
class IpaContrast {
  /// Creates a contrast.
  const IpaContrast({
    this.otherSymbol,
    required this.word,
    required this.otherWord,
  });

  /// The sound it is confused with, or null when the sound is dropped.
  final String? otherSymbol;

  /// A word with the lesson sound.
  final String word;

  /// A word with [otherSymbol] (or, when null, the same word without the sound).
  final String otherWord;
}

/// One lesson sound: its symbol, example words, contrast and advice.
class IpaSound {
  /// Creates a sound.
  const IpaSound({
    required this.symbol,
    required this.group,
    required this.keyword,
    required this.examples,
    required this.contrast,
    required this.mouthTip,
    required this.pitfall,
    this.lexicalSet,
    this.manner,
    this.voiced,
  });

  /// The IPA symbol without slashes, e.g. `iː`. Unique across the 44 sounds.
  final String symbol;

  /// Lesson group.
  final IpaGroup group;

  /// Keyword in ordinary spelling for a vowel, e.g. `see` for /iː/, or a
  /// consonant's first example word.
  final String keyword;

  /// Lexical set name for a vowel or diphthong (FLEECE, GOAT, ...); null for consonants.
  final String? lexicalSet;

  /// Manner of articulation; set for consonants only.
  final IpaManner? manner;

  /// Whether the vocal cords vibrate; set for consonants only.
  final bool? voiced;

  /// Three example words with the sound marked.
  final List<IpaExample> examples;

  /// A commonly confused sound with a word pair.
  final IpaContrast contrast;

  /// One or two plain-English sentences on the tongue, lips, jaw or voicing.
  final String mouthTip;

  /// The typical mistake learners make with this sound.
  final String pitfall;
}

/// One paragraph of the "What is the IPA?" lesson.
class IpaIntroPoint {
  /// Creates a paragraph.
  const IpaIntroPoint(this.title, this.body);

  /// Short heading.
  final String title;

  /// Body text in plain English.
  final String body;
}

/// The intro lesson, in reading order.
const List<IpaIntroPoint> ipaIntroPoints = [
  IpaIntroPoint(
    'Sounds, not spelling',
    'Each IPA symbol stands for one sound. English spelling is less regular: '
        "'ough' is said differently in 'though', 'cough' and 'thought'.",
  ),
  IpaIntroPoint(
    "Why /ʃ/ is not 'sh'",
    "/ʃ/ is one sound with one symbol, as at the start of 'ship'. The letters "
        "s and h can also be two separate sounds, as in 'mishap', so 'sh' on "
        'paper does not always mean /ʃ/.',
  ),
  IpaIntroPoint(
    'Slashes and brackets',
    'This app writes sounds between slashes, like /ʃɪp/. Square brackets, '
        'like [ʃɪp], show more detailed transcription. The app does not use them.',
  ),
  IpaIntroPoint(
    'The length mark ː',
    'The two-dot mark ː after a vowel means the vowel is long. Compare /ʃiːp/ '
        "'sheep' with /ʃɪp/ 'ship'.",
  ),
  IpaIntroPoint(
    'The stress mark ˈ',
    'A small raised line ˈ before a syllable means that syllable is stressed. '
        "In 'water' the stress is on the first part: /ˈwɔːtə/.",
  ),
  IpaIntroPoint(
    'How to use these lessons',
    'Open a group, tap a sound, hear its example words, practise the contrast, '
        "then mark it learned. The phone's British voice cannot say one sound on "
        'its own reliably, so the lessons play whole words that contain it.',
  ),
];

/// Every lesson sound, in display order: 12 vowels, 8 diphthongs, 24 consonants.
const List<IpaSound> ipaSounds = [
  // Monophthongs.
  IpaSound(
    symbol: 'iː',
    group: IpaGroup.vowels,
    lexicalSet: 'FLEECE',
    keyword: 'see',
    examples: [
      IpaExample('sh{ee}p'),
      IpaExample('b{ea}t'),
      IpaExample('gr{ee}n'),
    ],
    contrast: IpaContrast(otherSymbol: 'ɪ', word: 'sheep', otherWord: 'ship'),
    mouthTip:
        'Spread your lips as if smiling, with the front of your tongue high and '
        'close to the roof of your mouth. Keep the sound long and tense.',
    pitfall:
        "Shortening it to the vowel of 'ship', so 'sheep' sounds like 'ship'.",
  ),
  IpaSound(
    symbol: 'ɪ',
    group: IpaGroup.vowels,
    lexicalSet: 'KIT',
    keyword: 'sit',
    examples: [IpaExample('sh{i}p'), IpaExample('b{i}t'), IpaExample('k{i}t')],
    contrast: IpaContrast(otherSymbol: 'iː', word: 'ship', otherWord: 'sheep'),
    mouthTip:
        'Keep your lips relaxed, not spread, and let your tongue sit a little '
        'lower and further back than for /iː/. Keep the sound short and quick.',
    pitfall: "Stretching it into the long vowel of 'sheep', so 'ship' sounds like 'sheep'.",
  ),
  IpaSound(
    symbol: 'ɛ',
    group: IpaGroup.vowels,
    lexicalSet: 'DRESS',
    keyword: 'bed',
    examples: [IpaExample('b{e}d'), IpaExample('h{ea}d'), IpaExample('p{e}n')],
    contrast: IpaContrast(otherSymbol: 'æ', word: 'bed', otherWord: 'bad'),
    mouthTip:
        'Let your jaw drop a little, with the front of your tongue at mid height '
        'and your lips relaxed. Keep the sound short and flat, with no glide.',
    pitfall:
        "Adding a glide, so 'bed' sounds like 'bayed' (the vowel of 'bay').",
  ),
  IpaSound(
    symbol: 'æ',
    group: IpaGroup.vowels,
    lexicalSet: 'TRAP',
    keyword: 'cat',
    examples: [IpaExample('c{a}t'), IpaExample('b{a}d'), IpaExample('h{a}t')],
    contrast: IpaContrast(otherSymbol: 'ɛ', word: 'bad', otherWord: 'bed'),
    mouthTip:
        'Drop your jaw clearly, with the front of your tongue low and forward. '
        'Keep your lips slightly spread, not rounded.',
    pitfall: "Raising the vowel too far, so 'bad' sounds like 'bed'.",
  ),
  IpaSound(
    symbol: 'ɑː',
    group: IpaGroup.vowels,
    lexicalSet: 'START',
    keyword: 'car',
    examples: [
      IpaExample('b{a}th'),
      IpaExample('st{ar}t'),
      IpaExample('f{a}ther'),
    ],
    contrast: IpaContrast(otherSymbol: 'æ', word: 'cart', otherWord: 'cat'),
    mouthTip:
        'Open your mouth wide, with your tongue low and pulled back. Keep your '
        'lips relaxed and unrounded, and hold the sound long.',
    pitfall:
        "Using the short vowel of 'cat', or adding an r after it when no vowel "
        "follows. In British English the r in 'car' is silent.",
  ),
  IpaSound(
    symbol: 'ɒ',
    group: IpaGroup.vowels,
    lexicalSet: 'LOT',
    keyword: 'hot',
    examples: [IpaExample('h{o}t'), IpaExample('l{o}t'), IpaExample('w{a}tch')],
    contrast: IpaContrast(otherSymbol: 'ʌ', word: 'hot', otherWord: 'hut'),
    mouthTip:
        'Round your lips a little and drop your jaw, with your tongue low and '
        'back. Keep the sound short and clean.',
    pitfall:
        "Rounding too much and holding it as long as the vowel of 'thought'.",
  ),
  IpaSound(
    symbol: 'ɔː',
    group: IpaGroup.vowels,
    lexicalSet: 'THOUGHT',
    keyword: 'saw',
    examples: [
      IpaExample('th{ough}t'),
      IpaExample('s{aw}'),
      IpaExample('d{oor}'),
    ],
    contrast: IpaContrast(otherSymbol: 'ɒ', word: 'caught', otherWord: 'cot'),
    mouthTip:
        'Round your lips into a small, firm shape, with the back of your tongue '
        'raised. Hold the sound long and steady, with no glide.',
    pitfall: "Shortening it to the vowel of 'cot', so 'caught' and 'cot' sound alike.",
  ),
  IpaSound(
    symbol: 'ʊ',
    group: IpaGroup.vowels,
    lexicalSet: 'FOOT',
    keyword: 'put',
    examples: [IpaExample('f{oo}t'), IpaExample('p{u}t'), IpaExample('g{oo}d')],
    contrast: IpaContrast(otherSymbol: 'uː', word: 'pull', otherWord: 'pool'),
    mouthTip:
        'Round your lips gently without pushing them forward. Keep your tongue '
        'high and back, a little lower than for /uː/, and keep the sound short.',
    pitfall: "Making it long like 'pool', so 'pull' sounds like 'pool'.",
  ),
  IpaSound(
    symbol: 'uː',
    group: IpaGroup.vowels,
    lexicalSet: 'GOOSE',
    keyword: 'too',
    examples: [IpaExample('t{oo}'), IpaExample('f{oo}d'), IpaExample('bl{ue}')],
    contrast: IpaContrast(otherSymbol: 'ʊ', word: 'pool', otherWord: 'pull'),
    mouthTip:
        'Round your lips into a small circle and push them slightly forward, with '
        'your tongue high and at the back. Keep the sound long.',
    pitfall: "Spreading the lips as for 'see', so 'food' sounds like 'feed'.",
  ),
  IpaSound(
    symbol: 'ʌ',
    group: IpaGroup.vowels,
    lexicalSet: 'STRUT',
    keyword: 'cup',
    examples: [IpaExample('c{u}p'), IpaExample('b{u}s'), IpaExample('l{o}ve')],
    contrast: IpaContrast(otherSymbol: 'æ', word: 'cup', otherWord: 'cap'),
    mouthTip:
        'Open your mouth to a relaxed middle position, with your tongue central '
        'and your lips neutral, not rounded. Keep the sound short.',
    pitfall:
        "Opening too wide, so 'cup' sounds like 'cap', or rounding the lips, so "
        "it sounds like 'cop'.",
  ),
  IpaSound(
    symbol: 'ɜː',
    group: IpaGroup.vowels,
    lexicalSet: 'NURSE',
    keyword: 'bird',
    examples: [
      IpaExample('b{ir}d'),
      IpaExample('w{or}k'),
      IpaExample('h{ur}t'),
    ],
    contrast: IpaContrast(otherSymbol: 'ɔː', word: 'bird', otherWord: 'bored'),
    mouthTip:
        'Keep your lips relaxed and your tongue in the middle of your mouth, and '
        'hold the sound long. In British English do not sound an r after it.',
    pitfall:
        'Adding a strong r after it, as in American English, or using the short '
        "vowel of 'bud'.",
  ),
  IpaSound(
    symbol: 'ə',
    group: IpaGroup.vowels,
    lexicalSet: 'schwa',
    keyword: 'about',
    examples: [
      IpaExample('{a}bout'),
      IpaExample('sof{a}'),
      IpaExample('banan{a}'),
    ],
    contrast: IpaContrast(otherSymbol: 'ʌ', word: 'about', otherWord: 'cup'),
    mouthTip:
        'Keep your mouth loose and neutral, with no lip rounding and little tongue '
        'movement. It is the weakest vowel and appears only in unstressed syllables.',
    pitfall:
        "Giving it the full 'uh' of 'cup' in every unstressed syllable, so the "
        'word sounds stressed.',
  ),

  // Diphthongs.
  IpaSound(
    symbol: 'eɪ',
    group: IpaGroup.diphthongs,
    lexicalSet: 'FACE',
    keyword: 'say',
    examples: [
      IpaExample('st{ay}'),
      IpaExample('pl{a}ce'),
      IpaExample('g{a}me'),
    ],
    contrast: IpaContrast(otherSymbol: 'ɛ', word: 'bait', otherWord: 'bet'),
    mouthTip:
        "Start with your tongue mid-front, as in 'bed', and glide up towards the "
        "'ee' of 'see'. Keep your lips relaxed.",
    pitfall: "Keeping it flat with no glide, so 'bait' sounds like 'bet'.",
  ),
  IpaSound(
    symbol: 'aɪ',
    group: IpaGroup.diphthongs,
    lexicalSet: 'PRICE',
    keyword: 'my',
    examples: [IpaExample('m{y}'), IpaExample('h{igh}'), IpaExample('l{i}ke')],
    contrast: IpaContrast(otherSymbol: 'ɔɪ', word: 'tie', otherWord: 'toy'),
    mouthTip:
        "Start with an open 'ah' with your jaw dropped, then glide up and in "
        "towards 'ee'.",
    pitfall: "Stopping the glide early, so 'high' sounds like 'ha'.",
  ),
  IpaSound(
    symbol: 'ɔɪ',
    group: IpaGroup.diphthongs,
    lexicalSet: 'CHOICE',
    keyword: 'boy',
    examples: [
      IpaExample('b{oy}'),
      IpaExample('v{oi}ce'),
      IpaExample('c{oi}n'),
    ],
    contrast: IpaContrast(otherSymbol: 'aɪ', word: 'toy', otherWord: 'tie'),
    mouthTip:
        "Start with rounded lips, as for the vowel in 'thought', then glide up "
        "and in towards 'ee'.",
    pitfall: "Losing the rounded start, so 'boy' sounds like 'buy'.",
  ),
  IpaSound(
    symbol: 'əʊ',
    group: IpaGroup.diphthongs,
    lexicalSet: 'GOAT',
    keyword: 'go',
    examples: [IpaExample('g{o}'), IpaExample('b{oa}t'), IpaExample('kn{ow}')],
    contrast: IpaContrast(otherSymbol: 'ɔː', word: 'boat', otherWord: 'bought'),
    mouthTip:
        "Start with a relaxed, central 'uh' sound, then round your lips into 'oo' "
        'as you glide.',
    pitfall:
        "Holding one pure 'o' with no glide, so 'boat' sounds like 'bought'.",
  ),
  IpaSound(
    symbol: 'aʊ',
    group: IpaGroup.diphthongs,
    lexicalSet: 'MOUTH',
    keyword: 'now',
    examples: [IpaExample('n{ow}'), IpaExample('h{ou}se'), IpaExample('c{ow}')],
    contrast: IpaContrast(otherSymbol: 'əʊ', word: 'now', otherWord: 'no'),
    mouthTip:
        "Start with an open 'ah' with your jaw dropped, then glide to 'oo' as "
        'your lips round.',
    pitfall:
        "Starting with the rounded 'o' of 'go', so 'now' sounds like 'no'.",
  ),
  IpaSound(
    symbol: 'ɪə',
    group: IpaGroup.diphthongs,
    lexicalSet: 'NEAR',
    keyword: 'here',
    examples: [
      IpaExample('h{ere}'),
      IpaExample('b{eer}'),
      IpaExample('n{ear}'),
    ],
    contrast: IpaContrast(otherSymbol: 'eə', word: 'peer', otherWord: 'pair'),
    mouthTip:
        "Start with a short 'i' as in 'sit', then glide towards a relaxed schwa. "
        'Do not sound the r unless a vowel follows.',
    pitfall: 'Ending with a hard r sound, which makes it sound American.',
  ),
  IpaSound(
    symbol: 'eə',
    group: IpaGroup.diphthongs,
    lexicalSet: 'SQUARE',
    keyword: 'hair',
    examples: [
      IpaExample('h{air}'),
      IpaExample('squ{are}'),
      IpaExample('c{are}'),
    ],
    contrast: IpaContrast(otherSymbol: 'ɪə', word: 'pair', otherWord: 'peer'),
    mouthTip:
        "Start with an open-mid vowel, as in 'bed', and glide towards a relaxed "
        'schwa. The r stays silent unless a vowel follows.',
    pitfall: "Making it a long, flat 'air' with a strong r at the end, as in American English.",
  ),
  IpaSound(
    symbol: 'ʊə',
    group: IpaGroup.diphthongs,
    lexicalSet: 'CURE',
    keyword: 'tour',
    examples: [
      IpaExample('t{our}'),
      IpaExample('p{oor}'),
      IpaExample('s{ure}'),
    ],
    contrast: IpaContrast(otherSymbol: 'ɔː', word: 'poor', otherWord: 'pour'),
    mouthTip:
        "Start with a short 'oo' as in 'put', with your lips rounded, then glide "
        'towards a relaxed schwa.',
    pitfall: "Making it as long as 'pour', or adding a strong r at the end.",
  ),

  // Plosives.
  IpaSound(
    symbol: 'p',
    group: IpaGroup.consonants,
    manner: IpaManner.plosive,
    voiced: false,
    keyword: 'pin',
    examples: [IpaExample('{p}ie'), IpaExample('ca{p}'), IpaExample('sto{p}')],
    contrast: IpaContrast(otherSymbol: 'b', word: 'pin', otherWord: 'bin'),
    mouthTip:
        'Press your lips together, build up a little air pressure, then release '
        'it with a small puff. Keep your vocal cords still.',
    pitfall: "Leaving out the puff of air, so 'pin' sounds like 'bin'.",
  ),
  IpaSound(
    symbol: 'b',
    group: IpaGroup.consonants,
    manner: IpaManner.plosive,
    voiced: true,
    keyword: 'bin',
    examples: [IpaExample('{b}ig'), IpaExample('ru{b}'), IpaExample('la{b}')],
    contrast: IpaContrast(otherSymbol: 'p', word: 'bin', otherWord: 'pin'),
    mouthTip:
        'Close your lips as for /p/, but let your vocal cords buzz as you release. '
        'There is little or no puff of air.',
    pitfall: "Devoicing it at the end of a word, so 'rub' sounds like 'rup'.",
  ),
  IpaSound(
    symbol: 't',
    group: IpaGroup.consonants,
    manner: IpaManner.plosive,
    voiced: false,
    keyword: 'tea',
    examples: [IpaExample('{t}ea'), IpaExample('si{t}'), IpaExample('ca{t}')],
    contrast: IpaContrast(otherSymbol: 'd', word: 'tie', otherWord: 'die'),
    mouthTip:
        'Touch the tip of your tongue to the ridge just behind your top teeth, '
        'then release with a small puff of air. Keep your vocal cords still.',
    pitfall:
        "Replacing it with a soft 'd' or a quick tap like the 'tt' in American "
        "'water', so 'tea' sounds like 'dee'.",
  ),
  IpaSound(
    symbol: 'd',
    group: IpaGroup.consonants,
    manner: IpaManner.plosive,
    voiced: true,
    keyword: 'do',
    examples: [IpaExample('{d}ay'), IpaExample('bi{d}'), IpaExample('la{d}')],
    contrast: IpaContrast(otherSymbol: 't', word: 'dip', otherWord: 'tip'),
    mouthTip:
        'Touch your tongue in the same place as for /t/, but let your vocal cords '
        'buzz. The release is soft, with no puff.',
    pitfall: "Devoicing it at the end of a word, so 'bed' sounds like 'bet'.",
  ),
  IpaSound(
    symbol: 'k',
    group: IpaGroup.consonants,
    manner: IpaManner.plosive,
    voiced: false,
    keyword: 'cat',
    examples: [IpaExample('{c}at'), IpaExample('ba{ck}'), IpaExample('{k}ey')],
    contrast: IpaContrast(otherSymbol: 'ɡ', word: 'coat', otherWord: 'goat'),
    mouthTip:
        'Raise the back of your tongue to touch the soft palate, then release '
        'with a small puff of air. Keep your vocal cords still.',
    pitfall: "Dropping it at the end of a word, so 'back' sounds like 'bah'.",
  ),
  IpaSound(
    symbol: 'ɡ',
    group: IpaGroup.consonants,
    manner: IpaManner.plosive,
    voiced: true,
    keyword: 'go',
    examples: [IpaExample('{g}o'), IpaExample('ba{g}'), IpaExample('{g}ame')],
    contrast: IpaContrast(otherSymbol: 'k', word: 'goat', otherWord: 'coat'),
    mouthTip:
        'Make the same tongue position as /k/, but voice the sound so your throat '
        'buzz. Release it softly.',
    pitfall: "Devoicing it at the end of a word, so 'bag' sounds like 'back'.",
  ),

  // Fricatives.
  IpaSound(
    symbol: 'f',
    group: IpaGroup.consonants,
    manner: IpaManner.fricative,
    voiced: false,
    keyword: 'fan',
    examples: [
      IpaExample('{f}an'),
      IpaExample('lea{f}'),
      IpaExample('ph{o}ne'),
    ],
    contrast: IpaContrast(otherSymbol: 'v', word: 'fan', otherWord: 'van'),
    mouthTip:
        'Rest your top teeth lightly on your bottom lip and push air through the '
        'gap. Keep your vocal cords still.',
    pitfall: "Using both lips, as for /p/, or saying /v/ instead, so 'fan' sounds like 'van'.",
  ),
  IpaSound(
    symbol: 'v',
    group: IpaGroup.consonants,
    manner: IpaManner.fricative,
    voiced: true,
    keyword: 'van',
    examples: [
      IpaExample('{v}an'),
      IpaExample('lo{ve}'),
      IpaExample('se{v}en'),
    ],
    contrast: IpaContrast(otherSymbol: 'f', word: 'van', otherWord: 'fan'),
    mouthTip:
        'Use the same position as /f/, with your top teeth on your bottom lip, but '
        'voice it so you feel a buzz on your lip.',
    pitfall: "Devoicing it at the end of a word, so 'save' sounds like 'safe'.",
  ),
  IpaSound(
    symbol: 'θ',
    group: IpaGroup.consonants,
    manner: IpaManner.fricative,
    voiced: false,
    keyword: 'thin',
    examples: [
      IpaExample('{th}in'),
      IpaExample('ba{th}'),
      IpaExample('{th}ing'),
    ],
    contrast: IpaContrast(otherSymbol: 's', word: 'thin', otherWord: 'sin'),
    mouthTip:
        'Put the tip of your tongue lightly between your top and bottom teeth, '
        'and blow air gently over it. Do not use your voice.',
    pitfall: "Using /f/ or /t/ instead, so 'thin' sounds like 'fin' or 'tin'.",
  ),
  IpaSound(
    symbol: 'ð',
    group: IpaGroup.consonants,
    manner: IpaManner.fricative,
    voiced: true,
    keyword: 'this',
    examples: [
      IpaExample('{th}is'),
      IpaExample('bre{th}e'),
      IpaExample('ei{th}er'),
    ],
    contrast: IpaContrast(
      otherSymbol: 'd',
      word: 'breathe',
      otherWord: 'breed',
    ),
    mouthTip:
        'Use the same tongue position as /θ/, but voice it: let the air buzz '
        'as it passes your tongue tip.',
    pitfall: "Using /d/ or /z/ instead, so 'this' sounds like 'dis'.",
  ),
  IpaSound(
    symbol: 's',
    group: IpaGroup.consonants,
    manner: IpaManner.fricative,
    voiced: false,
    keyword: 'sun',
    examples: [IpaExample('{s}un'), IpaExample('bu{s}'), IpaExample('pa{ss}')],
    contrast: IpaContrast(otherSymbol: 'θ', word: 'sin', otherWord: 'thin'),
    mouthTip:
        'Place your tongue tip close to the ridge behind your top teeth, leaving a '
        'narrow gap, so air hisses through. Do not use your voice.',
    pitfall:
        'Putting the tongue between the teeth, which makes it sound lisped.',
  ),
  IpaSound(
    symbol: 'z',
    group: IpaGroup.consonants,
    manner: IpaManner.fricative,
    voiced: true,
    keyword: 'zoo',
    examples: [IpaExample('{z}oo'), IpaExample('bu{zz}'), IpaExample('ro{s}e')],
    contrast: IpaContrast(otherSymbol: 's', word: 'buzz', otherWord: 'bus'),
    mouthTip:
        'Use the same position as /s/, but add a buzz in your throat while you keep '
        'the hiss.',
    pitfall: "Devoicing it to /s/ at the end of a word, so 'his' sounds like 'hiss'.",
  ),
  IpaSound(
    symbol: 'ʃ',
    group: IpaGroup.consonants,
    manner: IpaManner.fricative,
    voiced: false,
    keyword: 'ship',
    examples: [
      IpaExample('{sh}ip'),
      IpaExample('fi{sh}'),
      IpaExample('wi{sh}'),
    ],
    contrast: IpaContrast(otherSymbol: 's', word: 'ship', otherWord: 'sip'),
    mouthTip:
        'Round your lips slightly and draw your tongue back a little from the /s/ '
        'position, so the air hisses over a wider groove. Do not use your voice.',
    pitfall: "Keeping the lips spread as for /s/, so 'shoe' sounds like 'sue'.",
  ),
  IpaSound(
    symbol: 'ʒ',
    group: IpaGroup.consonants,
    manner: IpaManner.fricative,
    voiced: true,
    keyword: 'vision',
    examples: [
      IpaExample('vi{s}ion'),
      IpaExample('mea{s}ure'),
      IpaExample('{g}enre'),
    ],
    contrast: IpaContrast(
      otherSymbol: 'ʃ',
      word: 'pleasure',
      otherWord: 'pressure',
    ),
    mouthTip:
        'Use the same lip and tongue position as /ʃ/, but voice it: keep the hiss '
        'and feel a buzz in your throat.',
    pitfall: "Devoicing it to /ʃ/, so 'vision' sounds like 'mission'.",
  ),
  IpaSound(
    symbol: 'h',
    group: IpaGroup.consonants,
    manner: IpaManner.fricative,
    voiced: false,
    keyword: 'hat',
    examples: [
      IpaExample('{h}at'),
      IpaExample('be{h}ind'),
      IpaExample('a{h}ead'),
    ],
    contrast: IpaContrast(word: 'hat', otherWord: 'at'),
    mouthTip:
        'Breathe out gently from your throat, as if you were misting a mirror. Keep '
        'your tongue and lips free, and open for the vowel that follows.',
    pitfall:
        "Dropping it at the start of a word, so 'hat' sounds like 'at', or adding "
        "one before a vowel, so 'apple' sounds like 'happle'.",
  ),

  // Affricates.
  IpaSound(
    symbol: 'tʃ',
    group: IpaGroup.consonants,
    manner: IpaManner.affricate,
    voiced: false,
    keyword: 'chip',
    examples: [
      IpaExample('{ch}ip'),
      IpaExample('mat{ch}'),
      IpaExample('wat{ch}'),
    ],
    contrast: IpaContrast(otherSymbol: 'ʃ', word: 'chip', otherWord: 'ship'),
    mouthTip:
        'Start with the tip of your tongue touching the ridge behind your top '
        'teeth, as for /t/, then release slowly into a /ʃ/ hiss. Do not use your voice.',
    pitfall:
        "Saying just /ʃ/, so 'chip' sounds like 'ship', or splitting it into a /t/ "
        'and an /s/.',
  ),
  IpaSound(
    symbol: 'dʒ',
    group: IpaGroup.consonants,
    manner: IpaManner.affricate,
    voiced: true,
    keyword: 'jump',
    examples: [
      IpaExample('{j}ump'),
      IpaExample('{g}em'),
      IpaExample('bri{dg}e'),
    ],
    contrast: IpaContrast(otherSymbol: 'j', word: 'jack', otherWord: 'yak'),
    mouthTip:
        'As for /tʃ/, but voiced: start with your tongue tip at the ridge behind '
        'your top teeth, and release into a buzzing /ʒ/.',
    pitfall: "Saying a plain /j/, so 'jam' sounds like 'yam'.",
  ),

  // Nasals.
  IpaSound(
    symbol: 'm',
    group: IpaGroup.consonants,
    manner: IpaManner.nasal,
    voiced: true,
    keyword: 'man',
    examples: [
      IpaExample('{m}an'),
      IpaExample('ha{m}'),
      IpaExample('si{m}ple'),
    ],
    contrast: IpaContrast(otherSymbol: 'b', word: 'mat', otherWord: 'bat'),
    mouthTip:
        'Close your lips and let the sound hum through your nose while your vocal '
        'cords buzz. Keep your lips closed until the vowel.',
    pitfall: "Ending the word with /n/ instead, so 'time' sounds like 'tine'.",
  ),
  IpaSound(
    symbol: 'n',
    group: IpaGroup.consonants,
    manner: IpaManner.nasal,
    voiced: true,
    keyword: 'no',
    examples: [IpaExample('{n}o'), IpaExample('ca{n}'), IpaExample('su{n}')],
    contrast: IpaContrast(otherSymbol: 'm', word: 'sun', otherWord: 'sum'),
    mouthTip:
        'Touch the tip of your tongue to the ridge behind your top teeth, block the '
        'mouth there, and let the sound hum through your nose.',
    pitfall: "Using /ŋ/ at the end of the word, so 'sun' sounds like 'sung'.",
  ),
  IpaSound(
    symbol: 'ŋ',
    group: IpaGroup.consonants,
    manner: IpaManner.nasal,
    voiced: true,
    keyword: 'sing',
    examples: [
      IpaExample('si{ng}'),
      IpaExample('ba{ng}'),
      IpaExample('lo{ng}'),
    ],
    contrast: IpaContrast(otherSymbol: 'n', word: 'sing', otherWord: 'sin'),
    mouthTip:
        'Like /n/, but the back of your tongue touches the soft palate instead of '
        'the ridge behind your teeth. Keep the tongue tip down.',
    pitfall: "Adding a hard /ɡ/ after it, so 'sing' sounds like 'sing-g'.",
  ),

  // Approximants.
  IpaSound(
    symbol: 'l',
    group: IpaGroup.consonants,
    manner: IpaManner.approximant,
    voiced: true,
    keyword: 'light',
    examples: [
      IpaExample('{l}ight'),
      IpaExample('{l}eaf'),
      IpaExample('ba{ll}'),
    ],
    contrast: IpaContrast(otherSymbol: 'ɹ', word: 'light', otherWord: 'right'),
    mouthTip:
        'Touch the tip of your tongue to the ridge behind your top teeth, and let '
        'the air flow around the sides. At the start of a word, keep it clear.',
    pitfall:
        "Using the heavy, back 'l' of 'ball' at the start of words, so 'light' "
        'sounds dark.',
  ),
  IpaSound(
    symbol: 'ɹ',
    group: IpaGroup.consonants,
    manner: IpaManner.approximant,
    voiced: true,
    keyword: 'red',
    examples: [
      IpaExample('{r}ed'),
      IpaExample('{r}ight'),
      IpaExample('ca{r}ry'),
    ],
    contrast: IpaContrast(otherSymbol: 'l', word: 'right', otherWord: 'light'),
    mouthTip:
        'Raise the tip of your tongue towards the ridge behind your top teeth, '
        'without touching it, and round your lips slightly. Sound r only before a vowel.',
    pitfall:
        'Curling the tongue back or trilling it, or sounding an r at the end of a '
        "word like 'car'.",
  ),
  IpaSound(
    symbol: 'j',
    group: IpaGroup.consonants,
    manner: IpaManner.approximant,
    voiced: true,
    keyword: 'yes',
    examples: [IpaExample('{y}es'), IpaExample('{y}ou'), IpaExample('vi{ew}')],
    contrast: IpaContrast(otherSymbol: 'dʒ', word: 'yak', otherWord: 'jack'),
    mouthTip:
        'Raise the front of your tongue towards the roof of your mouth, as at the '
        "start of 'ee', then glide quickly into the next vowel.",
    pitfall: "Replacing it with /dʒ/, so 'yes' sounds like 'jess'.",
  ),
  IpaSound(
    symbol: 'w',
    group: IpaGroup.consonants,
    manner: IpaManner.approximant,
    voiced: true,
    keyword: 'wet',
    examples: [IpaExample('{w}et'), IpaExample('{w}ay'), IpaExample('a{w}ay')],
    contrast: IpaContrast(otherSymbol: 'v', word: 'wine', otherWord: 'vine'),
    mouthTip:
        'Round your lips into a small circle, then move quickly into the next vowel. '
        'The back of your tongue rises towards the soft palate.',
    pitfall:
        "Using the teeth-on-lip position of /v/, so 'wine' sounds like 'vine'.",
  ),
];

/// Sounds in [group], in display order.
List<IpaSound> ipaSoundsIn(IpaGroup group) => [
  for (final s in ipaSounds)
    if (s.group == group) s,
];

/// The sound with [symbol], or null when no lesson covers it.
IpaSound? ipaSoundFor(String symbol) {
  for (final s in ipaSounds) {
    if (s.symbol == symbol) return s;
  }
  return null;
}

/// Total number of lesson sounds (44).
int get ipaSoundCount => ipaSounds.length;
