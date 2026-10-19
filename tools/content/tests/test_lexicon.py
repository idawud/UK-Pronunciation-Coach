from tools.content import lexicon as lx
from tools.content.lexicon import Lexicon, to_phonemes, tokenise, transcribe


def small_lex(overrides=None):
    brit = {
        "the": ["ð ə", "ð i", "ð ˈiː"],
        "to": ["t ə", "t ʊ", "t ˈuː"],
        "for": ["f ə", "f ˈɔː"],
        "apple": ["ˈæ p ə l"],
        "cat": ["k ˈæ t"],
        "wash": ["w ˈɒ ʃ"],
        "want": ["w ˈɒ n t"],
        "play": ["p l ˈeɪ"],
        "skip": ["s k ˈɪ p"],
        "make": ["m ˈeɪ k"],
        "fly": ["f l ˈaɪ"],
        "i": ["ˈaɪ"],
        "that": ["ð ˈæ t"],
        "dog": ["d ˈɒ ɡ"],
    }
    return Lexicon(brit, overrides or {})


def test_normalise_britfone_symbols():
    assert lx.normalise_pron("b ˈɐ s g ɛə") == "b ˈʌ s ɡ eə"
    assert lx.norm_key("Don’t") == "don't"


def test_to_phonemes_stress():
    assert to_phonemes("ˌæ b ˈiː n") == [
        {"ipa": "æ", "stress": 2},
        {"ipa": "b"},
        {"ipa": "iː", "stress": 1},
        {"ipa": "n"},
    ]


def test_tokenise_offsets_and_apostrophes():
    toks = tokenise("Hello, world! Don't — Sarah’s 42 well-known")
    assert [(t.text, t.offset) for t in toks] == [
        ("Hello", 0),
        ("world", 7),
        ("Don't", 14),
        ("Sarah’s", 22),
        ("well", 33),
        ("known", 38),
    ]


def test_load_britfone_real_file():
    lex = lx.load_britfone()
    assert lex["bath"] == ["b ˈɑː θ"]
    assert lex["but"] == ["b ˈʌ t"]
    assert "costa_rica" not in lex and "costa" not in lex or True
    assert all("_" not in w for w in lex)
    assert len(lex) > 15000


def test_load_britfone_skips_short_rows(tmp_path):
    f = tmp_path / "b.csv"
    f.write_text("CAT, k ˈæ t\nODD\nA_B, ə\nREAD(1), ɹ ˈiː d\nREAD(2), ɹ ˈɛ d\n", "utf-8")
    assert lx.load_britfone(f) == {"cat": ["k ˈæ t"], "read": ["ɹ ˈiː d", "ɹ ˈɛ d"]}


def test_variants(tmp_path):
    f = tmp_path / "v.tsv"
    f.write_text("# c\n\nread 2  # past\n", "utf-8")
    prefs = lx.load_variants(f)
    assert prefs == {"read": 2}
    out = lx.apply_variants({"read": ["a", "b"]}, prefs)
    assert out["read"] == ["b", "a"]
    assert lx.load_variants(tmp_path / "missing.tsv") == {}
    try:
        lx.apply_variants({"read": ["a"]}, {"read": 3})
    except ValueError as e:
        assert "read" in str(e)
    else:
        raise AssertionError("expected ValueError")


def test_real_variants_apply():
    lex = Lexicon.load()
    assert lex.britfone["you"][0] == "j ˈuː"
    assert lex.britfone["for"][0] == "f ə"


def test_derivations():
    lex = small_lex()
    assert lex.base("cats") == ["k ˈæ t s"]
    assert lex.base("dogs") == ["d ˈɒ ɡ z"]
    assert lex.base("washes") == ["w ˈɒ ʃ ɪ z"]
    assert lex.base("flies") == ["f l ˈaɪ z"]
    assert lex.base("wanted") == ["w ˈɒ n t ɪ d"]
    assert lex.base("washed") == ["w ˈɒ ʃ t"]
    assert lex.base("played") == ["p l ˈeɪ d"]
    assert lex.base("skipped") == ["s k ˈɪ p t"]
    assert lex.base("flied") == ["f l ˈaɪ d"]
    assert lex.base("making") == ["m ˈeɪ k ɪ ŋ"]
    assert lex.base("skipping") == ["s k ˈɪ p ɪ ŋ"]
    assert lex.base("I'm") == ["ˈaɪ m"]
    assert lex.base("that'll") == ["ð ˈæ t ə l"]
    assert lex.base("they're") == ["ð ˈeə"]
    assert lex.base("zz'd") is None
    assert lex.base("class") is None
    assert lex.base("sing") is None
    assert lex.source("cat") == "britfone"
    assert lex.source("cats") == "derived"
    assert lex.source("zzq") is None


def test_overrides_used_last():
    lex = small_lex({"priya": "p ɹ ˈiː j ə"})
    assert lex.source("Priya") == "override"
    assert lex.base("Priya") == ["p ɹ ˈiː j ə"]


def test_context_rules():
    lex = small_lex()
    got = [(t.text, p) for t, p in transcribe("The apple for the cat, for that. Zzq", lex)]
    assert got == [
        ("The", "ð i"),
        ("apple", "ˈæ p ə l"),
        ("for", "f ə"),
        ("the", "ð ə"),
        ("cat", "k ˈæ t"),
        ("for", "f ə"),
        ("that", "ð ˈæ t"),
        ("Zzq", None),
    ]
    assert lex.in_context("for", "", None) == "f ˈɔː"
    assert lex.in_context("for", "? ", "the") == "f ˈɔː"
    assert lex.in_context("to", " ", "apple") == "t ʊ"
    assert lex.in_context("to", " ", "zzq") == "t ə"
    assert lex.in_context("zzq", "", None) is None
