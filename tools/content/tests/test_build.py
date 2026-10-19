import json
import shutil
from pathlib import Path

import pytest

from tools.content import build as b
from tools.content.lexicon import Lexicon

HERE = Path(b.__file__).resolve().parent


def test_parse_sources():
    text = """# comment
=== l1-001 | Tea
focus: ʌ short-vowels
source: Somewhere

A cup of tea,
please.

Second para.
=== placement-l3 | Two
Hello.
"""
    s = b.parse_sources(text, "f.txt")
    assert [x.id for x in s] == ["l1-001", "placement-l3"]
    assert s[0].level == 1 and s[1].level == 3
    assert s[0].title == "Tea"
    assert s[0].focus == ["ʌ", "short-vowels"]
    assert s[0].source == "Somewhere"
    assert s[0].text == "A cup of tea, please.\n\nSecond para."
    assert s[1].text == "Hello."


@pytest.mark.parametrize(
    "text",
    ["stray\n=== l1-001 | x\nHi.", "=== l1-001 no title\nHi.", "=== x-1 | t\nHi."],
)
def test_parse_sources_errors(text):
    with pytest.raises(b.BuildError):
        b.parse_sources(text)


def test_overrides_round_trip(tmp_path):
    p = tmp_path / "o.tsv"
    entries = {"priya": {"ipa": "p ɹ ˈiː j ə", "source": "espeak", "reviewed": "no"}}
    b.write_overrides(entries, p)
    assert b.load_overrides(p) == entries
    assert b.load_overrides(tmp_path / "none.tsv") == {}
    p.write_text("bad line\n", "utf-8")
    with pytest.raises(b.BuildError):
        b.load_overrides(p)


def test_sentence_count():
    assert b.sentence_count("One. Two! Three?") == 3
    assert b.sentence_count('He said "hi." Then left.') == 2
    assert b.sentence_count("no stop") == 1


def words_for(text, lex=None):
    src = b.Source("l1-001", 1, "t", text)
    return b.build_words(src, lex or Lexicon.load())


def test_build_words_and_unknown():
    words, unknown = words_for("The cat sat. Zzqv")
    assert [w["text"] for w in words] == ["The", "cat", "sat", "Zzqv"]
    assert [w["offset"] for w in words] == [0, 4, 8, 13]
    assert words[3]["scorable"] is False and words[3]["phonemes"] == []
    assert unknown == ["Zzqv"]


def test_check_source_rules():
    lex = Lexicon.load()

    def errs(level, text, focus=()):
        src = b.Source(f"l{level}-001", level, "T", text, list(focus), file="f")
        return b.check_source(src, b.build_words(src, lex)[0], lex, True)

    assert errs(1, "The red bus stops at the end of this street.") == []
    assert any("words" in e for e in errs(1, "Too short."))
    assert any("digits" in e for e in errs(1, "I have 2 cats and a dog in the flat."))
    assert any("abbreviation" in e for e in errs(1, "Mr. Smith has a big red bus today."))
    assert any("sentences" in e for e in errs(1, "I sat on a mat. It was red and big."))
    assert any("focus" in e for e in errs(1, "The red bus stops at the end of it.", ["θ"]))
    assert any("short vowels" in e for e in errs(1, "We see three trees by the sea today."))
    assert any("θ" in e for e in errs(2, " ".join(["Cats sat."] * 13)))
    assert any("silent r" in e for e in errs(3, "We see a cat. " * 15))
    assert any("long vowels" in e for e in errs(3, "I sit. " * 25))
    assert any("weak forms" in e for e in errs(4, "Cats sit. " * 45))
    assert any("title" in e for e in b.check_source(b.Source("l1-001", 1, "", "x"), [], lex, True))


def test_non_rhotic_and_weak_forms():
    lex = Lexicon.load()
    words, _ = words_for("The car park for her and a red rose", lex)
    assert b.non_rhotic_words(words) == ["car", "park", "for", "her"]
    assert b.weak_form_count(words, lex) >= 2


def test_near_duplicates():
    s = [
        b.Source("l1-001", 1, "a", "green apples taste sweet"),
        b.Source("l1-002", 1, "b", "green apples taste sweet today"),
        b.Source("l2-001", 2, "c", "green apples taste sweet"),
        b.Source("l1-003", 1, "d", "the a"),
    ]
    assert b.near_duplicates(s) == [("l1-001", "l1-002", 0.8)]


def test_pairs():
    lex = Lexicon.load()
    pairs = b.parse_pairs("# c\nɪ-iː: ship sheep, bit beat\nθ-t: thin cat\n")
    assert len(pairs) == 3
    out, errs = b.build_pairs(pairs + [("ɪ-iː", "zzq", "sheep")], lex)
    assert [p["wordA"] for p in out] == ["ship", "bit"]
    assert out[0]["phonemesB"][1] == {"ipa": "iː", "stress": 1}
    assert any("thin/cat" in e for e in errs)
    assert any("zzq" in e for e in errs)
    with pytest.raises(b.BuildError):
        b.parse_pairs("ɪ-iː: ship\n")


def test_rule_and_extra_variants():
    assert b.rule_variants("thursday", "θ ˈɜː z d i") == ["θ ˈɜː z d eɪ"]
    assert b.rule_variants("mondays", "m ˈʌ n d eɪ z") == ["m ˈʌ n d i z"]
    assert b.rule_variants("expect", "ɪ k s p ˈɛ k t") == ["ɛ k s p ˈɛ k t"]
    assert b.rule_variants("exit", "ˈɛ ɡ z ɪ t") == []
    assert b.rule_variants("cat", "k ˈæ t") == []
    extra = b.load_extra_variants()
    assert "f ɹ ə m" in extra["from"]
    alts = b.alternatives({"from", "cat", "the", "zzq"}, Lexicon.load(), extra)
    assert alts["from"] == ["f ɹ ˈɒ m", "f ɹ ə m"]
    assert "ð i" in alts["the"]
    assert "cat" not in alts and "zzq" not in alts


def test_real_build_is_up_to_date():
    assert b.main(["--check"]) == 0


def test_real_build_contents():
    out = b.build()
    bundle = json.loads(out.files[b.ROOT / b.ASSETS / "passages.v1.json"])
    assert len(bundle["passages"]) == 120
    assert [p["level"] for p in bundle["placement"]] == [1, 3, 5]
    assert all(p["soundTags"] for p in bundle["passages"])
    pairs = json.loads(out.files[b.ROOT / b.ASSETS / "minimal_pairs.json"])["pairs"]
    assert len(pairs) >= 40
    assert out.stats["unknown"] == 0
    assert out.stats["britfone"] / out.stats["tokens"] > 0.9


def copy_inputs(tmp_path):
    src = tmp_path / "passages"
    shutil.copytree(HERE / "passages", src)
    pairs = tmp_path / "pairs.txt"
    shutil.copy(HERE / "minimal_pairs.txt", pairs)
    return src, pairs


def test_build_fails_on_unknown_word_without_espeak(tmp_path):
    src, pairs = copy_inputs(tmp_path)
    p = src / "level1.txt"
    p.write_text(p.read_text("utf-8").replace("busy street", "busy zzqstreet"), "utf-8")
    with pytest.raises(b.BuildError, match="zzqstreet"):
        b.build(tmp_path, sources_dir=src, pairs_src=pairs)


def test_build_uses_espeak_for_unknown_words(tmp_path):
    src, pairs = copy_inputs(tmp_path)
    p = src / "level1.txt"
    p.write_text(p.read_text("utf-8").replace("busy street", "busy zzqstreet"), "utf-8")
    logs = []
    out = b.build(
        tmp_path,
        use_espeak=True,
        runner=lambda w: "z_ˈɪ_k",
        sources_dir=src,
        pairs_src=pairs,
        log=logs.append,
    )
    assert out.overrides["zzqstreet"] == {
        "ipa": "z ˈɪ k",
        "source": "espeak-ng en-gb-x-rp",
        "reviewed": "no",
    }
    assert any("zzqstreet" in m for m in logs)
    review = out.files[tmp_path / "tools" / "content" / "review.md"]
    assert "| zzqstreet | /z ˈɪ k/ |" in review


def test_build_reports_structure_errors(tmp_path):
    src, pairs = copy_inputs(tmp_path)
    (src / "placement.txt").write_text("=== placement-l1 | A\nThe red bus is hot.\n", "utf-8")
    lvl = src / "level2.txt"
    lvl.write_text(lvl.read_text("utf-8") + "\n=== l1-001 | Dup\nThe cat sat on the mat.\n")
    with pytest.raises(b.BuildError) as e:
        b.build(tmp_path, sources_dir=src, pairs_src=pairs)
    msg = str(e.value)
    assert "placement.txt" in msg
    assert "belongs in level1.txt" in msg
    assert "duplicate id l1-001" in msg


def test_main_writes_and_checks(tmp_path, monkeypatch, capsys):
    assert b.main(["--root", str(tmp_path), "--check"]) == 1
    assert "stale" in capsys.readouterr().out
    written = []
    monkeypatch.setattr(b, "write_overrides", lambda entries: written.append(entries))
    assert b.main(["--root", str(tmp_path), "--espeak"]) == 0
    assert written  # --espeak rewrites the overrides file
    assert (tmp_path / "assets/content/passages.v1.json").exists()
    assert b.main(["--root", str(tmp_path), "--check"]) == 0


def test_main_reports_build_errors(monkeypatch, capsys):
    def boom(*a, **k):
        raise b.BuildError("broken")

    monkeypatch.setattr(b, "build", boom)
    assert b.main([]) == 1
    assert "broken" in capsys.readouterr().err
