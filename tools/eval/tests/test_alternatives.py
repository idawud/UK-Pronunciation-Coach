import json

from tools.eval import build_set as bs
from tools.eval.alternatives import Alternatives, add_alternatives, plain
from tools.eval.synth import build as B
from tools.eval.synth.voices import VOICES

TABLE = Alternatives({"the": ["ð ə", "ð iː"], "been": ["b iː n", "b ɪ n"], "cat": ["k ˈæ t"]})


def word(text, phonemes, index=0, scorable=True):
    return {
        "text": text,
        "index": index,
        "scorable": scorable,
        "phonemes": [{"ipa": p} for p in phonemes.split()],
    }


def test_plain_strips_stress():
    assert plain(["ˈæ", "t"]) == "æ t"
    assert plain([{"ipa": "ˌɪ"}]) == "ɪ"


def test_forms_skip_own_form_and_unscorable():
    assert TABLE.forms(word("The", "ð ə")) == [[{"ipa": "ð"}, {"ipa": "iː"}]]
    assert TABLE.forms(word("cat", "k æ t")) == []
    assert TABLE.forms(word("the", "ð ə", scorable=False)) == []
    assert TABLE.accepts("Been", ["b", "ɪ", "n"])
    assert not TABLE.accepts("been", ["b", "æ", "n"])


def test_add_alternatives_excludes_targets():
    passages = [
        {"id": "a", "words": [word("the", "ð ə"), word("been", "b iː n", 1)]},
        {"id": "b", "words": [word("the", "ð ə")]},
    ]
    assert add_alternatives(passages, exclude={"b": 0}, table=TABLE) == 2
    assert passages[0]["words"][1]["alternatives"] == [[{"ipa": "b"}, {"ipa": "ɪ"}, {"ipa": "n"}]]
    assert passages[1]["words"][0]["alternatives"] == []


def test_for_words_uses_c1_rules():
    t = Alternatives.for_words(["from", "Wednesday", "zzzz"])
    assert len(t.table["from"]) > 1  # weak form
    assert any(p.split()[-1].endswith("eɪ") for p in t.table["wednesday"])  # -day rule
    assert "zzzz" not in t.table


def test_build_set_writes_alternatives_but_not_for_probe_targets(tmp_path, lexicon):
    rows = [("p1_001", "p1", "tune", "Ask her to bring these things from the store.")]
    bs.write_items(rows, lexicon, tmp_path)
    passages = {p["id"]: p for p in json.loads((tmp_path / "passages.json").read_text())}
    manifest = bs.read_tsv(tmp_path / "manifest.tsv")
    native = passages["p1_001"]["words"]
    assert any(w["alternatives"] for w in native)
    for m in manifest:
        if m["target"]:
            assert passages[m["passage"]]["words"][int(m["target"])]["alternatives"] == []
    bs.write_items(rows, lexicon, tmp_path, alternatives=False)
    plain_p = json.loads((tmp_path / "passages.json").read_text())
    assert all("alternatives" not in w for p in plain_p for w in p["words"])


def test_synth_plan_relabels_accepted_forms(tmp_path):
    passage = {
        "id": "s1",
        "level": 1,
        "title": "s1",
        "text": "been",
        "words": [{**word("been", "b iː n"), "offset": 0}],
    }
    voices = [VOICES["bf_emma"]]
    accept_all = Alternatives({"been": ["b iː n", "b ɪ n", "b iː"]})
    _, labels, _ = B.plan_items([passage], voices, 1, accept_all.accepts)
    err = [r for r in labels if r["read"] == "error"]
    assert err[0]["label"] == "right" and "(accepted form)" in err[0]["notes"]
    _, labels, _ = B.plan_items([passage], voices, 1)
    assert [r for r in labels if r["read"] == "error"][0]["label"] == "wrong"
    B.write_plan(tmp_path, [passage], voices, 1, accept_all)
    out = json.loads((tmp_path / "passages.json").read_text())
    assert out[0]["words"][0]["alternatives"][0] == [{"ipa": "b"}, {"ipa": "ɪ"}, {"ipa": "n"}]
