/// Static content for the Coach "Describe it" section: circumlocution prompts (describe
/// a word without saying it) and high-value fluent phrases. Nothing here is loaded
/// from disk or the network, so the section works offline.
library;

/// Kind of target word, shown as a filter-free label on each prompt.
enum DescribeCategory {
  /// Everyday objects.
  object('Objects'),

  /// Abstract ideas and feelings.
  concept('Ideas'),

  /// Things people do.
  action('Actions');

  const DescribeCategory(this.label);

  /// Label shown on the prompt card.
  final String label;
}

/// One circumlocution prompt: the user describes [target] without saying it, using
/// [hints] as optional cues.
class CircumlocutionPrompt {
  /// Creates a prompt. Ids are stable keys in the Coach store, so never reuse one.
  const CircumlocutionPrompt({
    required this.id,
    required this.target,
    required this.hints,
    required this.category,
  });

  /// Stable key stored under `circ.doneIds`.
  final String id;

  /// The word the user must describe. Never shown in [hints].
  final String target;

  /// Exactly three short cue words or ideas, revealed one tap at a time.
  final List<String> hints;

  /// Kind of target.
  final DescribeCategory category;
}

/// Group of a [PhraseChunk], used for the filter chips on the Phrases tab.
enum PhraseCategory {
  /// Ways to start a turn.
  opening('Opening'),

  /// Ways to join ideas.
  linking('Linking'),

  /// Ways to soften a claim.
  hedging('Hedging'),

  /// Ways to disagree politely.
  disagreeing('Disagreeing'),

  /// Ways to restate or make a point clearer.
  clarifying('Clarifying');

  const PhraseCategory(this.label);

  /// Chip label.
  final String label;
}

/// One fluent phrase the user drills by listening and repeating.
class PhraseChunk {
  /// Creates a phrase. Ids are stable keys in the Coach store, so never reuse one.
  const PhraseChunk({
    required this.id,
    required this.text,
    required this.category,
  });

  /// Stable key stored under `chunks.counts`.
  final String id;

  /// The phrase as the coach speaks it.
  final String text;

  /// Group the phrase belongs to.
  final PhraseCategory category;
}

/// The circumlocution prompts, in display order.
const List<CircumlocutionPrompt> circumlocutionPrompts = [
  // Objects
  CircumlocutionPrompt(
    id: 'stapler',
    target: 'stapler',
    hints: ['papers', 'office desk', 'metal staples'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'umbrella',
    target: 'umbrella',
    hints: ['rain', 'held overhead', 'wet weather'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'kettle',
    target: 'kettle',
    hints: ['boil', 'water', 'cup of tea'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'colander',
    target: 'colander',
    hints: ['pasta', 'drain', 'little holes'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'wardrobe',
    target: 'wardrobe',
    hints: ['clothes', 'bedroom', 'hanging rail'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'toaster',
    target: 'toaster',
    hints: ['bread', 'breakfast', 'goes brown'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'doormat',
    target: 'doormat',
    hints: ['wipe your shoes', 'front door', 'welcome'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'thermos',
    target: 'thermos',
    hints: ['flask', 'hot drink', 'keeps warm'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'spatula',
    target: 'spatula',
    hints: ['flip', 'pancake', 'kitchen utensil'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'padlock',
    target: 'padlock',
    hints: ['key', 'gate', 'bicycle chain'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'hammer',
    target: 'hammer',
    hints: ['nails', 'tool', 'bang'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'binoculars',
    target: 'binoculars',
    hints: ['birdwatching', 'far away', 'two eyepieces'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'calculator',
    target: 'calculator',
    hints: ['numbers', 'sums', 'buttons'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'ladder',
    target: 'ladder',
    hints: ['climb', 'roof', 'rungs'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'dishwasher',
    target: 'dishwasher',
    hints: ['plates', 'after dinner', 'machine'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'saucepan',
    target: 'saucepan',
    hints: ['cooking', 'hob', 'long handle'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'envelope',
    target: 'envelope',
    hints: ['letter', 'stamp', 'post'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'backpack',
    target: 'backpack',
    hints: ['school books', 'shoulder straps', 'hiking'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'scissors',
    target: 'scissors',
    hints: ['cut', 'paper', 'two blades'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'torch',
    target: 'torch',
    hints: ['dark', 'batteries', 'light beam'],
    category: DescribeCategory.object,
  ),
  CircumlocutionPrompt(
    id: 'dustbin',
    target: 'dustbin',
    hints: ['rubbish', 'bin bags', 'lid'],
    category: DescribeCategory.object,
  ),
  // Ideas
  CircumlocutionPrompt(
    id: 'nostalgia',
    target: 'nostalgia',
    hints: ['missing the past', 'memories', 'sentimental'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'procrastinate',
    target: 'procrastinate',
    hints: ['delay', 'putting off', 'tomorrow'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'serendipity',
    target: 'serendipity',
    hints: ['lucky find', 'by chance', 'happy accident'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'bureaucracy',
    target: 'bureaucracy',
    hints: ['forms', 'red tape', 'officials'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'empathy',
    target: 'empathy',
    hints: ['understanding feelings', 'in their shoes', 'compassion'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'deadline',
    target: 'deadline',
    hints: ['finish by', 'due date', 'time limit'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'commute',
    target: 'commute',
    hints: ['travel to work', 'every morning', 'journey'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'queue',
    target: 'queue',
    hints: ['waiting', 'in a line', 'at the shop'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'mortgage',
    target: 'mortgage',
    hints: ['house loan', 'bank', 'monthly payments'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'insomnia',
    target: 'insomnia',
    hints: ['cannot sleep', 'at night', 'awake'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'hangover',
    target: 'hangover',
    hints: ['too much drink', 'morning after', 'headache'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'awkward',
    target: 'awkward',
    hints: ['uncomfortable', 'long silence', 'embarrassing'],
    category: DescribeCategory.concept,
  ),
  CircumlocutionPrompt(
    id: 'genuine',
    target: 'genuine',
    hints: ['real', 'sincere', 'not fake'],
    category: DescribeCategory.concept,
  ),
  // Actions
  CircumlocutionPrompt(
    id: 'whisk',
    target: 'whisk',
    hints: ['eggs', 'beat', 'cream'],
    category: DescribeCategory.action,
  ),
  CircumlocutionPrompt(
    id: 'haggle',
    target: 'haggle',
    hints: ['price', 'market', 'bargain'],
    category: DescribeCategory.action,
  ),
  CircumlocutionPrompt(
    id: 'reminisce',
    target: 'reminisce',
    hints: ['old times', 'recall', 'chat about the past'],
    category: DescribeCategory.action,
  ),
  CircumlocutionPrompt(
    id: 'stroll',
    target: 'stroll',
    hints: ['walk', 'slowly', 'park'],
    category: DescribeCategory.action,
  ),
  CircumlocutionPrompt(
    id: 'snooze',
    target: 'snooze',
    hints: ['alarm', 'a little sleep', 'button'],
    category: DescribeCategory.action,
  ),
  CircumlocutionPrompt(
    id: 'gossip',
    target: 'gossip',
    hints: ['rumours', 'about others', 'chatting'],
    category: DescribeCategory.action,
  ),
  CircumlocutionPrompt(
    id: 'fidget',
    target: 'fidget',
    hints: ['restless', 'hands', 'cannot keep still'],
    category: DescribeCategory.action,
  ),
  CircumlocutionPrompt(
    id: 'babysit',
    target: 'babysit',
    hints: ['children', 'parents out', 'evening'],
    category: DescribeCategory.action,
  ),
];

/// The fluent phrases, grouped by [PhraseCategory], in display order.
const List<PhraseChunk> phraseChunks = [
  // Opening
  PhraseChunk(
    id: 'to-begin-with',
    text: 'To begin with',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'let-me-start',
    text: 'Let me start by saying',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'first-thing',
    text: 'The first thing to say is',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'id-like-to-begin',
    text: "I'd like to begin by",
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'way-i-see-it',
    text: 'The way I see it',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'right-so',
    text: 'Right, so',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'the-thing-is',
    text: 'The thing is',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'set-the-scene',
    text: 'Let me set the scene',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'short-answer',
    text: 'The short answer is',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'main-point',
    text: 'The main point is',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'what-happened',
    text: 'What happened was',
    category: PhraseCategory.opening,
  ),
  PhraseChunk(
    id: 'picture-this',
    text: 'Picture this',
    category: PhraseCategory.opening,
  ),
  // Linking
  PhraseChunk(
    id: 'on-the-other-hand',
    text: 'On the other hand',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(
    id: 'in-addition',
    text: 'In addition',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(
    id: 'as-a-result',
    text: 'As a result',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(
    id: 'that-said',
    text: 'That said',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(
    id: 'having-said-that',
    text: 'Having said that',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(
    id: 'furthermore',
    text: 'Furthermore',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(
    id: 'mind-you',
    text: 'Mind you',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(id: 'even-so', text: 'Even so', category: PhraseCategory.linking),
  PhraseChunk(
    id: 'for-example',
    text: 'For example',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(
    id: 'mainly-because',
    text: 'Mainly because',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(
    id: 'which-means',
    text: 'Which means that',
    category: PhraseCategory.linking,
  ),
  PhraseChunk(
    id: 'meanwhile',
    text: 'Meanwhile',
    category: PhraseCategory.linking,
  ),
  // Hedging
  PhraseChunk(
    id: 'to-be-honest',
    text: 'To be honest',
    category: PhraseCategory.hedging,
  ),
  PhraseChunk(
    id: 'i-suppose',
    text: 'I suppose',
    category: PhraseCategory.hedging,
  ),
  PhraseChunk(
    id: 'it-depends-on',
    text: 'It depends on',
    category: PhraseCategory.hedging,
  ),
  PhraseChunk(id: 'id-say', text: "I'd say", category: PhraseCategory.hedging),
  PhraseChunk(
    id: 'more-or-less',
    text: 'More or less',
    category: PhraseCategory.hedging,
  ),
  PhraseChunk(id: 'sort-of', text: 'Sort of', category: PhraseCategory.hedging),
  PhraseChunk(
    id: 'as-far-as-i-can-tell',
    text: 'As far as I can tell',
    category: PhraseCategory.hedging,
  ),
  PhraseChunk(
    id: 'not-entirely-sure',
    text: "I'm not entirely sure, but",
    category: PhraseCategory.hedging,
  ),
  PhraseChunk(
    id: 'arguably',
    text: 'Arguably',
    category: PhraseCategory.hedging,
  ),
  PhraseChunk(
    id: 'if-im-not-mistaken',
    text: "If I'm not mistaken",
    category: PhraseCategory.hedging,
  ),
  PhraseChunk(
    id: 'probably',
    text: 'Probably',
    category: PhraseCategory.hedging,
  ),
  PhraseChunk(
    id: 'i-tend-to-think',
    text: 'I tend to think',
    category: PhraseCategory.hedging,
  ),
  // Disagreeing
  PhraseChunk(
    id: 'see-what-you-mean',
    text: 'I see what you mean, but',
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'not-so-sure',
    text: "I'm not so sure about that",
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'id-argue',
    text: "I'd argue that",
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'one-way-of-looking',
    text: "That's one way of looking at it",
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'afraid-i-disagree',
    text: "I'm afraid I disagree",
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'on-reflection',
    text: "On reflection, I'd say",
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'not-quite-right',
    text: "That's not quite right",
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'take-your-point',
    text: 'I take your point, however',
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'why-youd-say-that',
    text: "I can see why you'd say that, but",
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'not-necessarily',
    text: 'Not necessarily',
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'push-back',
    text: "I'd push back on that",
    category: PhraseCategory.disagreeing,
  ),
  PhraseChunk(
    id: 'surely-not',
    text: 'Surely not',
    category: PhraseCategory.disagreeing,
  ),
  // Clarifying
  PhraseChunk(
    id: 'what-i-mean-is',
    text: 'What I mean is',
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'in-other-words',
    text: 'In other words',
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'another-way',
    text: 'To put it another way',
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'let-me-rephrase',
    text: 'Let me rephrase that',
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'do-you-mean',
    text: 'Do you mean',
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'so-what-youre-saying',
    text: "So what you're saying is",
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'to-be-specific',
    text: 'To be specific',
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'that-is-to-say',
    text: 'That is to say',
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'put-simply',
    text: 'Put simply',
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'point-im-making',
    text: "The point I'm making is",
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'just-to-clarify',
    text: 'Just to clarify',
    category: PhraseCategory.clarifying,
  ),
  PhraseChunk(
    id: 'by-that-i-mean',
    text: 'By that I mean',
    category: PhraseCategory.clarifying,
  ),
];
