import json

from tools.ci import check_content as cc


def passage(pid="l1-001", level=1, **overrides):
    p = {
        "id": pid,
        "level": level,
        "title": "Tea",
        "text": "I like tea.",
        "words": [
            {"text": "I", "index": 0, "phonemes": [{"ipa": "aɪ", "stress": 1}], "offset": 0},
            {"text": "like", "index": 1, "phonemes": [{"ipa": "l"}, {"ipa": "aɪ"}], "offset": 2},
            {"text": "tea", "index": 2, "phonemes": [{"ipa": "t"}, {"ipa": "iː"}], "offset": 7},
        ],
        "soundTags": ["iː"],
    }
    p.update(overrides)
    return p


def library():
    return [passage(f"l{lv}-{i:03}", lv) for lv in range(1, 7) for i in range(20)]


def test_valid_library_passes():
    assert cc.check_bundle(library(), 20) == []
    assert cc.check_bundle({"passages": library()}, 20) == []


def test_bad_shapes():
    assert cc.check_bundle("nope", 20) == [
        "bundle must be a list of passages or {'passages': [...]}"
    ]
    errors = cc.check_bundle([passage(), passage(), "x"], None)
    assert "duplicate id 'l1-001'" in errors
    assert "passage #2: not an object" in errors


def test_field_errors():
    bad = passage(level=9, soundTags="θ")
    errors = cc.check_passage(bad, 0)
    assert any("level" in e for e in errors) and any("soundTags" in e for e in errors)
    assert cc.check_passage(passage(title=3), 0) == ["passage 'l1-001': 'title' must be a str"]
    assert cc.check_passage(passage(words=[]), 0) == ["passage 'l1-001': no words"]


def test_word_errors():
    p = passage()
    p["words"][1]["index"] = 5
    p["words"][1]["offset"] = 3
    p["words"][2]["phonemes"] = []
    p["words"][0]["phonemes"] = [{"ipa": "ˈaɪ", "stress": 4}, {"stress": 1}]
    p["words"].append({"index": 3})
    p["words"].append({"text": "x", "index": 4, "phonemes": "nope"})
    errors = cc.check_passage(p, 0)
    joined = "\n".join(errors)
    assert "index is 5, expected 1" in joined
    assert "offset 3" in joined
    assert "scorable word has no phonemes" in joined
    assert "stress marks belong" in joined
    assert "stress must be 0, 1 or 2" in joined
    assert "needs a non-empty 'ipa'" in joined
    assert "needs non-empty 'text'" in joined
    assert "phonemes must be a list" in joined
    p2 = passage()
    p2["words"][2] = {**p2["words"][2], "scorable": False, "phonemes": []}
    assert cc.check_passage(p2, 0) == []


def test_level_counts():
    errors = cc.check_bundle(library()[:-1], 20)
    assert errors == ["level 6: 19 passages, expected 20"]


def test_pairs():
    pair = {"contrast": "ɪ-iː", "wordA": "ship", "wordB": "sheep"}
    assert cc.check_pairs([pair] * 40) == []
    assert cc.check_pairs({"pairs": [pair] * 40}) == []
    assert cc.check_pairs("x") == ["minimal pairs must be a list or {'pairs': [...]}"]
    errors = cc.check_pairs([pair, {"contrast": "x"}])
    assert "minimal pairs: 2, expected at least 40" in errors
    assert "minimal pair #1: needs contrast, wordA and wordB" in errors


def test_main(tmp_path, capsys):
    assert cc.main(["--root", str(tmp_path)]) == 0
    assert cc.main(["--root", str(tmp_path), "--require"]) == 1
    content = tmp_path / "assets" / "content"
    content.mkdir(parents=True)
    (content / "passages.v1.json").write_text(json.dumps(library()), encoding="utf-8")
    assert cc.main(["--root", str(tmp_path)]) == 0
    (content / "minimal_pairs.json").write_text("[]", encoding="utf-8")
    assert cc.main(["--root", str(tmp_path)]) == 1
    assert "FAILED" in capsys.readouterr().out
