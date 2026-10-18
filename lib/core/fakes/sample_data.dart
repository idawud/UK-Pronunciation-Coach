/// Fixed sample data for fakes, tests, goldens and fixtures. Pure Dart.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../models/models.dart';

/// Matches the words of a text: letters with an optional apostrophe part ("don't").
final RegExp wordPattern = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");

/// Parses a space-separated IPA transcription where a leading `ˈ` marks primary stress
/// and `ˌ` secondary stress, e.g. `"θ ˈɜː z d eɪ"`.
List<PhonemeSpec> parseIpa(String ipa) => [
  for (final p in ipa.split(' ').where((p) => p.isNotEmpty))
    if (p.startsWith('ˈ'))
      PhonemeSpec(ipa: p.substring(1), stress: 1)
    else if (p.startsWith('ˌ'))
      PhonemeSpec(ipa: p.substring(1), stress: 2)
    else
      PhonemeSpec(ipa: p),
];

/// Builds a [Passage] from [text] and one IPA transcription per word (see [parseIpa]);
/// an empty transcription marks the word not scorable. Offsets are computed from [text].
Passage buildPassage({
  required String id,
  required int level,
  required String title,
  required String text,
  required List<String> ipa,
  List<String> soundTags = const [],
}) {
  final matches = wordPattern.allMatches(text).toList();
  if (matches.length != ipa.length) {
    throw ArgumentError(
      '$id: ${matches.length} words but ${ipa.length} transcriptions',
    );
  }
  return Passage(
    id: id,
    level: level,
    title: title,
    text: text,
    soundTags: soundTags,
    words: [
      for (var i = 0; i < matches.length; i++)
        WordSpec(
          text: matches[i].group(0)!,
          index: i,
          offset: matches[i].start,
          phonemes: parseIpa(ipa[i]),
          scorable: ipa[i].isNotEmpty,
        ),
    ],
  );
}

/// Level 1 sample passage.
final Passage teaPassage = buildPassage(
  id: 'sample-l1-tea',
  level: 1,
  title: 'Morning tea',
  text: 'I like a cup of tea in the morning.',
  ipa: [
    'ˈaɪ', 'l ˈaɪ k', 'ə', 'k ˈʌ p', 'ə v', 't ˈiː', 'ˈɪ n', 'ð ə', //
    'm ˈɔː n ɪ ŋ',
  ],
  soundTags: ['ʌ', 'iː', 'ɔː'],
);

/// Level 3 sample passage "A walk by the river" (Thursday, castle and bath are red in
/// [cannedRiverAttempt]).
final Passage riverPassage = buildPassage(
  id: 'sample-l3-river',
  level: 3,
  title: 'A walk by the river',
  text:
      'On Thursday we walked by the river. We passed an old castle and a farm. '
      'At home I had a hot bath and a cup of tea.',
  ipa: [
    'ˈɒ n', 'θ ˈɜː z d eɪ', 'w ˈiː', 'w ˈɔː k t', 'b ˈaɪ', 'ð ə', //
    'ɹ ˈɪ v ə', 'w ˈiː', 'p ˈɑː s t', 'ə n', 'ˈəʊ l d', 'k ˈɑː s ə l', //
    'ə n d', 'ə', 'f ˈɑː m', 'ə t', 'h ˈəʊ m', 'ˈaɪ', 'h ˈæ d', 'ə', //
    'h ˈɒ t', 'b ˈɑː θ', 'ə n d', 'ə', 'k ˈʌ p', 'ə v', 't ˈiː',
  ],
  soundTags: ['θ', 'ɑː', 'ɔː', 'ɜː'],
);

/// Level 5 sample passage.
final Passage linkingPassage = buildPassage(
  id: 'sample-l5-linking',
  level: 5,
  title: 'Linking words',
  text: 'Linking your words together makes your speech sound natural and relaxed.',
  ipa: [
    'l ˈɪ ŋ k ɪ ŋ', 'j ˈɔː', 'w ˈɜː d z', 't ə ɡ ˈɛ ð ə', 'm ˈeɪ k s', //
    'j ˈɔː', 's p ˈiː tʃ', 's ˈaʊ n d', 'n ˈæ tʃ ə ɹ ə l', 'ə n d', //
    'ɹ ɪ l ˈæ k s t',
  ],
  soundTags: ['ŋ', 'ɜː', 'linking'],
);

/// The three sample passages (levels 1, 3 and 5; also the sample placement set).
final List<Passage> samplePassages = [teaPassage, riverPassage, linkingPassage];

/// Extra dictionary words for `FakeContentRepository.lookup`.
final Map<String, List<PhonemeSpec>> sampleExtraLexicon = {
  'hello': parseIpa('h ə l ˈəʊ'),
  'world': parseIpa('w ˈɜː l d'),
  'think': parseIpa('θ ˈɪ ŋ k'),
  'this': parseIpa('ð ˈɪ s'),
  'ship': parseIpa('ʃ ˈɪ p'),
  'sheep': parseIpa('ʃ ˈiː p'),
  'cot': parseIpa('k ˈɒ t'),
  'caught': parseIpa('k ˈɔː t'),
  'full': parseIpa('f ˈʊ l'),
  'fool': parseIpa('f ˈuː l'),
  'car': parseIpa('k ˈɑː'),
};

/// Sample minimal pairs.
final List<MinimalPair> sampleMinimalPairs = [
  MinimalPair(
    contrast: 'ɒ-ɔː',
    wordA: 'cot',
    wordB: 'caught',
    phonemesA: sampleExtraLexicon['cot']!,
    phonemesB: sampleExtraLexicon['caught']!,
  ),
  MinimalPair(
    contrast: 'ɪ-iː',
    wordA: 'ship',
    wordB: 'sheep',
    phonemesA: sampleExtraLexicon['ship']!,
    phonemesB: sampleExtraLexicon['sheep']!,
  ),
  MinimalPair(
    contrast: 'ʊ-uː',
    wordA: 'full',
    wordB: 'fool',
    phonemesA: sampleExtraLexicon['full']!,
    phonemesB: sampleExtraLexicon['fool']!,
  ),
];

/// CTC blank symbol used by the sample vocab (as in wav2vec2's vocab.json).
const String sampleBlank = '<pad>';

/// A small IPA vocab (blank first) covering the sample passages and common competitors.
const List<String> sampleVocab = [
  sampleBlank,
  'ɪ', 'ʊ', 'ɛ', 'æ', 'ʌ', 'ɒ', 'ə', 'ɜː', 'ɑː', 'ɔː', 'iː', 'uː', //
  'eɪ', 'aɪ', 'ɔɪ', 'əʊ', 'aʊ', 'ɪə', 'eə', 'ʊə', 'oʊ', 'ɚ', //
  'p', 'b', 't', 'd', 'k', 'ɡ', 'f', 'v', 'θ', 'ð', 's', 'z', 'ʃ', 'ʒ', //
  'h', 'tʃ', 'dʒ', 'm', 'n', 'ŋ', 'l', 'ɹ', 'w', 'j',
];

/// Frames of silence (blank) before and after speech in synthetic posteriors.
const int syntheticEdgeFrames = 10;

/// Frames per phoneme in synthetic posteriors.
const int syntheticFramesPerPhoneme = 4;

/// Blank frames between words in synthetic posteriors.
const int syntheticGapFrames = 2;

/// Frame span `[start, end)` of each phoneme of each word in synthetic posteriors for
/// [passage]; `null` for words that are missed or not scorable.
List<List<(int, int)>?> syntheticLayout(
  Passage passage, {
  Set<int> missedWords = const {},
}) {
  var t = syntheticEdgeFrames;
  final layout = <List<(int, int)>?>[];
  for (final w in passage.words) {
    if (!w.scorable || missedWords.contains(w.index)) {
      layout.add(null);
      continue;
    }
    final spans = <(int, int)>[];
    for (var i = 0; i < w.phonemes.length; i++) {
      spans.add((t, t + syntheticFramesPerPhoneme));
      t += syntheticFramesPerPhoneme;
    }
    layout.add(spans);
    t += syntheticGapFrames;
  }
  return layout;
}

/// Synthetic log-posteriors for a reading of [passage] where the answer is known:
/// each spoken phoneme gets [syntheticFramesPerPhoneme] frames with probability
/// [peak] on it (or on its substitute), blanks elsewhere.
///
/// - [substitutions]: word index -> phoneme index -> IPA heard instead.
/// - [missedWords]: word indexes not said at all (no frames).
PhonemePosteriors syntheticPosteriors(
  Passage passage, {
  Map<int, Map<int, String>> substitutions = const {},
  Set<int> missedWords = const {},
  double peak = 0.9,
  ModelTier tier = ModelTier.full,
  List<String> vocab = sampleVocab,
}) {
  final layout = syntheticLayout(passage, missedWords: missedWords);
  var total = syntheticEdgeFrames;
  for (final spans in layout) {
    if (spans != null && spans.isNotEmpty) total = spans.last.$2;
  }
  total += syntheticEdgeFrames;
  final ids = List<int>.filled(total, vocab.indexOf(sampleBlank));
  for (var w = 0; w < layout.length; w++) {
    final spans = layout[w];
    if (spans == null) continue;
    final word = passage.words[w];
    for (var p = 0; p < spans.length; p++) {
      final ipa = substitutions[w]?[p] ?? word.phonemes[p].ipa;
      final id = vocab.indexOf(ipa);
      if (id < 0) throw ArgumentError('"$ipa" is not in the vocab');
      for (var f = spans[p].$1; f < spans[p].$2; f++) {
        ids[f] = id;
      }
    }
  }
  final hi = math.log(peak);
  final lo = math.log((1 - peak) / (vocab.length - 1));
  return PhonemePosteriors(
    vocab: vocab,
    blankIndex: vocab.indexOf(sampleBlank),
    tier: tier,
    frames: [
      for (final id in ids)
        Float32List(vocab.length)
          ..fillRange(0, vocab.length, lo)
          ..[id] = hi,
    ],
  );
}

/// Speech segment covering all spoken frames of [posteriors] built by
/// [syntheticPosteriors], padded by 150 ms like the real VAD.
List<Segment> syntheticSpeech(PhonemePosteriors posteriors) {
  final end =
      posteriors.duration - Duration(milliseconds: syntheticEdgeFrames * 20);
  const start = Duration(milliseconds: syntheticEdgeFrames * 20);
  const pad = Duration(milliseconds: 150);
  return [Segment(start: start - pad, end: end + pad)];
}

/// Word index -> phoneme index -> heard IPA for the canned river reading.
const Map<int, Map<int, String>> riverSubstitutions = {
  1: {0: 't'}, // Thursday: θ heard as t
  11: {1: 'æ'}, // castle: ɑː heard as æ
  21: {1: 'æ', 2: 'f'}, // bath: ɑː heard as æ, θ as f
};

/// Posteriors matching [cannedRiverAttempt] (same layout and substitutions).
final PhonemePosteriors riverPosteriors = syntheticPosteriors(
  riverPassage,
  substitutions: riverSubstitutions,
);

/// Phoneme scores of the canned river reading, by word index (others are uniform).
const Map<int, List<int>> _riverPhonemeScores = {
  1: [20, 55, 70, 75, 70], // Thursday -> 58 fix
  3: [80, 60, 75, 70], // walked -> 70 close
  6: [70, 60, 70, 65], // river -> 66 close
  11: [80, 25, 70, 60, 65], // castle -> 57 fix
  21: [75, 30, 40], // bath -> 46 fix
};

/// Word score as A3 defines it: weighted mean of phoneme scores, stressed vowels 1.5.
int weightedWordScore(List<PhonemeSpec> phonemes, List<int> scores) {
  var sum = 0.0;
  var weight = 0.0;
  for (var i = 0; i < phonemes.length; i++) {
    final w = phonemes[i].stress == 1 ? 1.5 : 1.0;
    sum += scores[i] * w;
    weight += w;
  }
  return weight == 0 ? 0 : (sum / weight).round();
}

/// Builds an attempt for [passage] with the given per-word phoneme scores
/// (uniform [defaultScore] where absent), timed with [syntheticLayout].
AttemptResult buildAttempt(
  Passage passage, {
  required String id,
  required DateTime at,
  Map<int, List<int>> phonemeScores = const {},
  Map<int, Map<int, String>> heard = const {},
  Set<int> missedWords = const {},
  int Function(int wordIndex)? defaultScore,
  int fluency = 76,
  ModelTier tier = ModelTier.full,
  String? audioPath,
}) {
  final layout = syntheticLayout(passage, missedWords: missedWords);
  Duration ms(int frame) => Duration(milliseconds: frame * 20);
  final words = <WordResult>[];
  for (final w in passage.words) {
    final spans = layout[w.index];
    if (!w.scorable) {
      words.add(
        WordResult(
          index: w.index,
          text: w.text,
          score: 0,
          status: WordStatus.notScored,
        ),
      );
      continue;
    }
    if (spans == null) {
      words.add(
        WordResult(
          index: w.index,
          text: w.text,
          score: 0,
          status: WordStatus.missed,
        ),
      );
      continue;
    }
    final base = defaultScore?.call(w.index) ?? 85 + (w.index * 7) % 11;
    final scores =
        phonemeScores[w.index] ?? List<int>.filled(w.phonemes.length, base);
    final score = weightedWordScore(w.phonemes, scores);
    words.add(
      WordResult(
        index: w.index,
        text: w.text,
        score: score,
        status: WordStatus.fromScore(score),
        phonemes: [
          for (var p = 0; p < w.phonemes.length; p++)
            PhonemeResult(
              expected: w.phonemes[p].ipa,
              heard: heard[w.index]?[p],
              score: scores[p],
              start: ms(spans[p].$1),
              end: ms(spans[p].$2),
            ),
        ],
      ),
    );
  }
  final scored = words.where((w) => w.status != WordStatus.notScored).toList();
  final accuracy = scored.isEmpty
      ? 0
      : (scored.map((w) => w.score).reduce((a, b) => a + b) / scored.length)
            .round();
  return AttemptResult(
    id: id,
    passageId: passage.id,
    at: at,
    overall: (0.7 * accuracy + 0.3 * fluency).round(),
    accuracy: accuracy,
    fluency: fluency,
    words: words,
    audioPath: audioPath,
    tier: tier,
  );
}

/// Canned result for [riverPassage]: Thursday, castle and bath red; walked and river
/// amber; the rest green.
final AttemptResult cannedRiverAttempt = buildAttempt(
  riverPassage,
  id: 'sample-attempt-river',
  at: DateTime(2026, 10, 15, 8, 30),
  phonemeScores: _riverPhonemeScores,
  heard: riverSubstitutions,
);

/// A good reading (every word 90) of [passage].
AttemptResult goodAttempt(
  Passage passage, {
  required String id,
  required DateTime at,
  int score = 90,
  int fluency = 90,
}) => buildAttempt(
  passage,
  id: id,
  at: at,
  defaultScore: (_) => score,
  fluency: fluency,
);
