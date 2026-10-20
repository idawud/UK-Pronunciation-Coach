import pytest

from tools.eval.synth import phonemes as ph

# Kokoro's misaki-GB vocab characters used here and Piper's eSpeak `en` inventory
# (subsets of the real tokenizer.json / phoneme_id_map).
KOKORO_VOCAB = set("AIWYQabdfhijklmnpstuvwzðŋɑɒɔəɛɜɡɪɹʃʊʌʒʤʧθˈˌː ,.?!;:")
ESPEAK_VOCAB = set("abdefhijklmnpstuvwzðŋɑɒɔəɛɜɡɪɹʃʊʌʒθˈˌː ,.?!;:")


@pytest.mark.parametrize(
    ("phones", "kokoro", "espeak"),
    [
        ([("θ", 0), ("ɪ", 1), ("ŋ", 0), ("k", 0)], "θˈɪŋk", "θˈɪŋk"),
        ([("k", 0), ("æ", 1), ("t", 0)], "kˈat", "kˈat"),
        ([("h", 0), ("eə", 1)], "hˈɛː", "hˈeə"),
        ([("h", 0), ("ɛə", 1)], "hˈɛː", "hˈeə"),  # Britfone spelling
        ([("n", 0), ("ɪə", 1)], "nˈɪə", "nˈiə"),
        ([("ɡ", 0), ("əʊ", 1)], "ɡˈQ", "ɡˈəʊ"),
        ([("g", 0), ("əʊ", 2)], "ɡˌQ", "ɡˌəʊ"),
        ([("d", 0), ("eɪ", 1)], "dˈA", "dˈeɪ"),
        ([("b", 0), ("aɪ", 1)], "bˈI", "bˈaɪ"),
        ([("b", 0), ("ɔɪ", 1)], "bˈY", "bˈɔɪ"),
        ([("n", 0), ("aʊ", 1)], "nˈW", "nˈaʊ"),
        ([("tʃ", 0), ("ɜː", 1), ("tʃ", 0)], "ʧˈɜːʧ", "tʃˈɜːtʃ"),
        ([("dʒ", 0), ("ɐ", 1), ("dʒ", 0)], "ʤˈʌʤ", "dʒˈʌdʒ"),
        ([("k", 0), ("ɑː", 1), ("ɹ", 0)], "kˈɑːɹ", "kˈɑːɹ"),
        ([("l", 0), ("ɒ", 1), ("x", 0)], "lˈɒk", "lˈɒk"),
        ([("h", 0), ("æ", 1), ("p", 0), ("i", 0)], "hˈapi", "hˈapi"),
        ([("ð", 0), ("ə", 0)], "ðə", "ðə"),
        ([("b", 0), ("ɛ", 1), ("d", 0)], "bˈɛd", "bˈɛd"),
        ([("b", 0), ("e", 1), ("d", 0)], "bˈɛd", "bˈɛd"),
    ],
)
def test_word_mapping(phones, kokoro, espeak):
    assert ph.kokoro_word(phones) == kokoro
    assert ph.espeak_word(phones) == espeak
    ph.check_vocab(kokoro, KOKORO_VOCAB)
    ph.check_vocab(espeak, ESPEAK_VOCAB)


def test_every_ssbe_phoneme_maps_into_both_vocabs():
    for p in sorted(ph.VOWELS | ph.CONSONANTS):
        ph.check_vocab(ph.kokoro_word([(p, 1)]), KOKORO_VOCAB)
        ph.check_vocab(ph.espeak_word([(p, 1)]), ESPEAK_VOCAB)


def test_stress_marks_only_on_vowels():
    assert ph.kokoro_word([("t", 1), ("ɪ", 2)]) == "tˌɪ"


def test_unknown_phoneme_raises():
    with pytest.raises(ValueError, match="unknown"):
        ph.kokoro_word([("ʘ", 0)])


def test_check_vocab_names_missing_symbols():
    with pytest.raises(ValueError, match="ʘ"):
        ph.check_vocab("aʘ", {"a"})


def test_separators_keep_punctuation_and_end_with_full_stop():
    text = "Sorry, I think so"
    words = ["Sorry", "I", "think", "so"]
    offsets = [0, 7, 9, 15]
    assert ph.separators(text, offsets, words) == [", ", " ", " ", "."]
    assert ph.separators("Is it?", [0, 3], ["Is", "it"]) == [" ", "?"]
    assert ph.separators("twenty-five", [0, 7], ["twenty", "five"]) == [" ", "."]


def test_render_sentence():
    words = [[("ð", 0), ("ə", 0)], [("k", 0), ("æ", 1), ("t", 0)]]
    assert ph.render(words, [" ", "."], "kokoro") == "ðə kˈat."
    assert ph.render(words, [" ", "?"], "espeak") == "ðə kˈat?"


def test_is_vowel_normalises():
    assert ph.is_vowel("ɐ") and ph.is_vowel("ɛə") and not ph.is_vowel("g")
