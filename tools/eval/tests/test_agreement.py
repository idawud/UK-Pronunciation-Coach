import csv
import json

import pytest

from tools.eval import agreement as ag
from tools.eval.tests.conftest import word_row


def test_parse_label():
    assert ag.parse_label("Right") is True
    assert ag.parse_label(" wrong ") is False
    assert ag.parse_label("") is None and ag.parse_label("maybe") is None


def labels():
    return [
        {"item": "a", "word_index": "0", "label": "right"},
        {"item": "a", "word_index": "1", "label": "wrong"},
        {"item": "a", "word_index": "2", "label": "right"},
        {"item": "a", "word_index": "3", "label": "wrong"},
        {"item": "a", "word_index": "4", "label": ""},
        {"item": "zz", "word_index": "0", "label": "right"},
    ]


def words():
    return [
        word_row(item="a", word_index=0, status="good"),
        word_row(item="a", word_index=1, status="fix"),
        word_row(item="a", word_index=2, status="close"),
        word_row(item="a", word_index=3, status="close"),
        word_row(item="a", word_index=4, status="missed"),
    ]


def test_score_counts_and_kappa():
    r = ag.score(labels(), words())
    assert r["words"] == 4 and r["unmatched"] == 1
    assert r["agreement"] == 0.75
    assert r["engine_right_teacher_wrong"] == 1 and r["engine_wrong_teacher_wrong"] == 1
    assert r["false_red_on_right_words"] == 0.0 and r["recall_of_wrong_words"] == 0.5
    assert 0 < r["kappa"] < 1
    strict = ag.score(labels(), words(), amber_wrong=True)
    assert strict["agreement"] == 0.75 and strict["engine_wrong_teacher_right"] == 1
    assert ag.score([], words()) == {"words": 0, "unmatched": 0}


def test_score_perfect_kappa():
    lab = [{"item": "a", "word_index": "0", "label": "right"}]
    assert ag.score(lab, words())["kappa"] == pytest.approx(1.0)


def write_csv(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def test_template(tmp_path):
    manifest = tmp_path / "m.tsv"
    manifest.write_text(
        "item\twav\tpassage\tspeaker\tkind\n"
        "a\twav/a.wav\ta\tp1\tnative\n"
        "a.swap\twav/a.wav\ta.swap\tp1\tswap\n"
        "l1\twav/l1.wav\ta\tlearner7\tlearner\n",
        encoding="utf-8",
    )
    passages = tmp_path / "p.json"
    passages.write_text(json.dumps([
        {"id": "a", "words": [{"index": 0, "text": "Ask"},
                              {"index": 1, "text": "Zork", "scorable": False}]},
        {"id": "a.swap", "words": [{"index": 0, "text": "Book"}]},
    ]))  # fmt: skip
    out = tmp_path / "labels.csv"
    assert ag.main(["template", "--manifest", str(manifest), "--passages", str(passages),
                    "--out", str(out)]) == 0  # fmt: skip
    rows = list(csv.DictReader(open(out, encoding="utf-8")))
    assert [(r["item"], r["word"]) for r in rows] == [("a", "Ask"), ("l1", "Ask")]
    assert list(rows[0]) == ag.LABEL_FIELDS and rows[0]["label"] == ""


def test_score_cli_paths(tmp_path, capsys):
    lab, wd = tmp_path / "labels.csv", tmp_path / "words.csv"
    base = ["score", "--labels", str(lab), "--words", str(wd)]
    assert ag.main(base) == 0 and "SKIPPED" in capsys.readouterr().out
    assert ag.main([*base, "--require-labels"]) == 1
    write_csv(lab, [{"item": "a", "word_index": "0", "label": ""}])
    assert ag.main(base) == 0 and "no labelled" in capsys.readouterr().out
    write_csv(lab, labels())
    assert ag.main(base) == 0 and "no harness output" in capsys.readouterr().out
    write_csv(wd, words())
    out = tmp_path / "r.json"
    assert ag.main([*base, "--json", str(out)]) == 1  # 75% < 80%
    assert "NO-GO" in capsys.readouterr().out
    assert json.loads(out.read_text())["agreement"] == 0.75
    assert ag.main([*base, "--threshold", "0.7"]) == 0
    assert "GO" in capsys.readouterr().out
    write_csv(lab, [{"item": "zz", "word_index": "9", "label": "right"}])
    assert ag.main(base) == 0 and "matched" in capsys.readouterr().out
