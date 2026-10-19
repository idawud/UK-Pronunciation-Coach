import io

import pytest

from tools.eval import lexicon as lx
from tools.eval.tests.conftest import fake_espeak


def test_parse_britfone_first_variant_and_stress(lexicon):
    a = lexicon.entries["A"]
    assert [p.ipa for p in a] == ["ə"]
    think = lexicon.entries["THINK"]
    assert [(p.ipa, p.stress) for p in think] == [("θ", 0), ("ɪ", 1), ("ŋ", 0), ("k", 0)]


def test_lookup_case_and_plural_possessive(lexicon):
    assert lexicon.lookup("Think").source == "britfone"
    cats = lexicon.lookup("cats")
    assert cats.source == "britfone+s" and cats.phonemes[-1].ipa == "s"
    dogs = lexicon.lookup("dog's")
    assert dogs.phonemes[-1].ipa == "z"
    churches = lexicon.lookup("churches")
    assert [p.ipa for p in churches.phonemes[-2:]] == ["ɪ", "z"]
    assert lexicon.lookup("as") is None  # short stem: no plural guess
    assert lexicon.lookup("zork") is None  # no eSpeak configured
    assert lexicon.lookup("zork") is None  # cached


def test_espeak_fallback_is_flagged_and_converted(lexicon_espeak):
    p = lexicon_espeak.lookup("zork")
    assert p.source == "espeak"
    assert [(x.ipa, x.stress) for x in p.phonemes] == [("z", 0), ("ɔː", 1), ("k", 0)]
    bottle = lexicon_espeak.lookup("bottle")
    assert [x.ipa for x in bottle.phonemes] == ["b", "ɒ", "t", "ə", "l"]
    assert lexicon_espeak.lookup("nothing") is None


def test_convert_espeak_maps_symbols():
    out = lx.convert_espeak("ð_ˈeə ɹ_ˌʌ_n ɡ_r_aɪə\n")
    assert [(p.ipa, p.stress) for p in out] == [
        ("ð", 0),
        ("ɛə", 1),
        ("ɹ", 0),
        ("ɐ", 2),
        ("n", 0),
        ("g", 0),
        ("ɹ", 0),
        ("aɪ", 0),
        ("ə", 0),
    ]


def test_espeak_phonemes_command():
    seen = {}

    def runner(cmd, **kw):
        seen["cmd"] = cmd
        return fake_espeak(cmd, **kw)

    lx.espeak_phonemes("zork", "/bin/espeak", runner)
    assert seen["cmd"][:2] == ["/bin/espeak", "-q"] and "en-gb-x-rp" in seen["cmd"]


def test_find_espeak(monkeypatch):
    monkeypatch.setenv("ESPEAK_NG", "/x/espeak-ng")
    assert lx.find_espeak() == "/x/espeak-ng"


def test_tokenize_and_passage_json(lexicon):
    text = "Ask her, to bring these things!"
    words = lx.tokenize(text)
    assert [w.text for w in words] == ["Ask", "her", "to", "bring", "these", "things"]
    assert all(text[w.offset : w.offset + len(w.text)] == w.text for w in words)
    p = lx.passage_json("p1", text + " Zork", lexicon)
    assert p["id"] == "p1" and p["text"].endswith("Zork")
    assert p["words"][0]["phonemes"][0] == {"ipa": "ɑː", "stress": 1}
    assert p["words"][-1]["scorable"] is False and p["words"][-1]["phonemes"] == []


def test_fetch_britfone_checks_sha(tmp_path, monkeypatch):
    payload = {name: name.encode() for name in lx.BRITFONE_FILES}
    monkeypatch.setattr(
        lx, "BRITFONE_FILES", {n: lx.hashlib.sha256(b).hexdigest() for n, b in payload.items()}
    )

    def opener(url):
        return io.BytesIO(payload[url.rsplit("/", 1)[1]])

    path = lx.fetch_britfone(tmp_path, opener)
    assert path.name == "britfone.main.3.0.1.csv" and path.exists()
    # Already present and valid: no download needed.
    assert lx.fetch_britfone(tmp_path, lambda url: pytest.fail("downloaded again")) == path

    def bad(url):
        return io.BytesIO(b"tampered")

    with pytest.raises(ValueError, match="SHA-256"):
        lx.fetch_britfone(tmp_path / "other", bad)
