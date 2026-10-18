/// British (SSBE, Britfone-style) phoneme -> phoneme-model symbols. Pure data.
///
/// Each value lists the model symbols that count as saying the key correctly, best
/// first. An entry with spaces is a sequence, used only when the model's vocab has
/// none of the single symbols (e.g. a vocab without diphthong tokens). Symbols the
/// vocab lacks are ignored, so the table works with any IPA vocab; it was written
/// against the espeak vocab of facebook/wav2vec2-lv-60-espeak-cv-ft (392 symbols,
/// `<pad>` blank, IPA with length marks, diphthongs and r-coloured vowels as single
/// tokens).
///
/// Keys are normalised IPA (see `normalizeIpa`): no stress marks, `ː` for length.
/// Accepting a symbol means the model may label that British sound with it, e.g. the
/// espeak training labels write GOAT as `oʊ` and reduced vowels as `ɐ` / `ᵻ`. r-coloured
/// vowels (`ɚ`, `ɑːɹ`, ...) are deliberately **not** accepted for British vowels: they
/// are reported as heard so the "don't sound the r" tip can fire.
library;

/// The mapping table. I2-eval can extend it via `ScoringConfig.extraAccepted`.
const Map<String, List<String>> ssbePhonemeMap = {
  // Short vowels.
  'ɪ': ['ɪ', 'ᵻ'],
  'ɛ': ['ɛ', 'e'],
  'e': ['ɛ', 'e'],
  'æ': ['æ', 'a'],
  'ʌ': ['ʌ', 'ɐ'],
  'ɒ': ['ɒ', 'ɔ'],
  'ʊ': ['ʊ'],
  'ə': ['ə', 'ɐ', 'ᵻ', 'əl'],
  'ɐ': ['ɐ', 'ə'],
  'i': ['i', 'iː', 'ɪ'], // happY
  'u': ['u', 'uː', 'ʊ'],
  // Long vowels.
  'iː': ['iː', 'i'],
  'ɑː': ['ɑː', 'ɑ', 'aː'],
  'ɔː': ['ɔː', 'ɔ', 'oː'],
  'uː': ['uː', 'u', 'ʉ'],
  'ɜː': ['ɜː', 'ɜ'],
  // Diphthongs.
  'eɪ': ['eɪ', 'e ɪ', 'ɛ ɪ'],
  'aɪ': ['aɪ', 'a ɪ'],
  'ɔɪ': ['ɔɪ', 'oɪ', 'ɔ ɪ'],
  'əʊ': ['əʊ', 'oʊ', 'ə ʊ', 'o ʊ'],
  'oʊ': ['oʊ', 'əʊ', 'o ʊ'],
  'aʊ': ['aʊ', 'a ʊ'],
  'ɪə': ['ɪə', 'iə', 'ɪ ə'],
  'eə': ['eə', 'ɛː', 'e ə', 'ɛ ə'],
  'ɛə': ['eə', 'ɛː', 'e ə', 'ɛ ə'],
  'ɛː': ['ɛː', 'eə', 'ɛ'],
  'ʊə': ['ʊə', 'ʊ ə'],
  // Consonants.
  'p': ['p'],
  'b': ['b'],
  't': ['t'],
  'd': ['d'],
  'k': ['k'],
  'ɡ': ['ɡ'],
  'g': ['ɡ'],
  'f': ['f'],
  'v': ['v'],
  'θ': ['θ'],
  'ð': ['ð'],
  's': ['s'],
  'z': ['z'],
  'ʃ': ['ʃ'],
  'ʒ': ['ʒ'],
  'h': ['h'],
  'x': ['x', 'k'],
  'tʃ': ['tʃ', 't ʃ'],
  'ʧ': ['tʃ', 't ʃ'],
  'dʒ': ['dʒ', 'd ʒ'],
  'ʤ': ['dʒ', 'd ʒ'],
  'm': ['m'],
  'n': ['n', 'n̩'],
  'ŋ': ['ŋ'],
  'l': ['l', 'ɫ', 'l̩', 'əl'],
  'ɫ': ['ɫ', 'l'],
  'ɹ': ['ɹ', 'r'],
  'r': ['ɹ', 'r'],
  'j': ['j'],
  'w': ['w'],
  'ʔ': ['ʔ', 't'],
  // Syllabic consonants.
  'l̩': ['l̩', 'əl', 'l', 'ə l'],
  'n̩': ['n̩', 'n', 'ə n'],
  'm̩': ['m', 'ə m'],
};

/// British vowel keys of [ssbePhonemeMap] (used for stress weighting and the
/// intrusive-r check).
const Set<String> ssbeVowels = {
  'ɪ', 'ɛ', 'e', 'æ', 'ʌ', 'ɒ', 'ʊ', 'ə', 'ɐ', 'i', 'u', //
  'iː', 'ɑː', 'ɔː', 'uː', 'ɜː', //
  'eɪ', 'aɪ', 'ɔɪ', 'əʊ', 'oʊ', 'aʊ', 'ɪə', 'eə', 'ɛə', 'ɛː', 'ʊə',
};

/// Model symbols that mean an r was sounded: plain r and r-coloured vowels.
const Set<String> rhoticSymbols = {
  'ɹ', 'r', 'ɚ', 'ɑːɹ', 'ɔːɹ', 'oːɹ', 'ɛɹ', 'ɪɹ', 'ʊɹ', 'aɪɚ', 'ɝ', //
};
