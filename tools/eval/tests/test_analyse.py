import csv
import json

import pytest

from tools.eval import analyse as an
from tools.eval.tests.conftest import word_row


def rows():
    return [
        word_row(item="a", word="cat", status="good"),
        word_row(item="a", word_index=1, word="the", status="fix", score=40,
                 expected="ð ə", stress="0 0", heard="ð ∅", phoneme_scores="90 0"),
        word_row(item="a", word_index=2, word="hot", status="close", score=70,
                 expected="h ɒ t", stress="0 1 0", heard="h ɑː ɾ", phoneme_scores="90 30 40"),
        word_row(item="a", word_index=3, word="store", status="close", score=65,
                 expected="s t ɔː", stress="0 0 1", heard="s t ɔːɹ", phoneme_scores="90 90 45"),
        word_row(item="a", word_index=4, word="zork", status="notScored", heard="",
                 phoneme_scores="", expected=""),
        word_row(item="b", speaker="p2", split="heldout", status="missed", score=0, heard="",
                 phoneme_scores=""),
        word_row(item="a.swap", kind="swap", is_target=1, status="fix"),
        word_row(item="a.swap", kind="swap", word_index=1, status="good"),
        word_row(item="a.sub", kind="sub", is_target=1, status="close"),
        word_row(item="b.sub", kind="sub", split="heldout", is_target=1, status="missed"),
    ]  # fmt: skip


def test_rates_and_native():
    r = an.native_rates(rows())
    assert r["words"] == 5
    assert r["red"] == pytest.approx(2 / 5) and r["amber"] == pytest.approx(2 / 5)
    assert r["function_words"]["words"] == 1 and r["content_words"]["words"] == 4
    assert set(r["by_speaker"]) == {"p1", "p2"}
    assert an.native_rates(rows(), "heldout")["missed"] == 1.0
    assert an.rates([])["red"] == 0.0


def test_probe_detection_and_pairs():
    d = an.probe_detection(rows())
    assert d["swap"] == {"items": 1, "red": 1.0, "not_green": 1.0}
    assert d["sub"]["items"] == 2 and d["sub"]["red"] == 0.5 and d["sub"]["not_green"] == 1.0
    assert d["all"]["red"] == pytest.approx(2 / 3)
    assert an.probe_detection(rows(), "heldout")["swap"]["items"] == 0
    pairs = an.sub_pairs(rows(), {"a.sub": "hot:ɒ->əʊ", "b.sub": "cat:æ->ɛ"})
    assert pairs == {"æ->ɛ": {"items": 1, "red": 1.0}, "ɒ->əʊ": {"items": 1, "red": 0.0}}


def test_phoneme_stats_and_known_issues():
    stats = an.phoneme_stats(rows(), min_count=1)
    by = {s["phoneme"]: s for s in stats}
    assert by["ɒ"]["low"] == 1.0 and by["ɒ"]["heard_as"] == [("ɑː", 1)]
    assert by["ə"]["heard_as"] == [("∅", 1)]
    assert stats[0]["low"] >= stats[-1]["low"]
    bad = word_row(heard="k æ", phoneme_scores="1 2 3")  # length mismatch: ignored
    assert an.phoneme_stats([bad], min_count=1) == []
    k = an.known_issues(rows() + [bad])
    assert k["lot_heard_as_ah"] == {"count": 1, "of": 1}
    assert k["vowel_heard_with_r"] == {"phonemes": 1, "words": 1}
    assert k["t_heard_as_flap"]["count"] == 1


def clip(**kw):
    c = {"item": "a", "kind": "native", "probe": "", "model_ms": "500", "recognise_ms": "550",
         "audio_ms": "2000", "score_ms": "3.5"}  # fmt: skip
    c.update(kw)
    return c


def test_timing():
    t = an.timing([clip(), clip(model_ms="1000", audio_ms="2000"), clip(kind="swap")])
    assert t["clips"] == 3 - 1 + 0 or t["clips"] == 2
    assert t["rtf_median"] == pytest.approx(0.375)
    assert t["est_25s_passage_s"] == pytest.approx(0.375 * 25)
    assert an.timing([clip(model_ms="")]) == {}


def test_summary_and_cli(tmp_path, capsys):
    s = an.summarise(rows(), [clip()])
    text = an.format_summary(s)
    assert "heldout" in text and "timing" in text
    run = tmp_path / "run"
    run.mkdir()
    with open(run / "words_default.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows()[0]))
        w.writeheader()
        w.writerows(rows())
    out = tmp_path / "s.json"
    assert an.main([str(run), "--json", str(out)]) == 0
    assert json.loads(out.read_text())["native"]["all"]["words"] == 5
    assert "weak phonemes" in capsys.readouterr().out
