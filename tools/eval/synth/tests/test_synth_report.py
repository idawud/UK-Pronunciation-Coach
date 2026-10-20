import csv
import json

import pytest

from tools.eval.synth import report as R
from tools.eval.synth.tests.conftest import word_row

LABEL_FIELDS = ["item", "speaker", "passage", "word_index", "word", "label", "teacher",
                "notes", "error", "voice", "split", "read", "aug"]  # fmt: skip


def lab(item, idx, label, error="", split="tune", read="clean", voice="v1", aug="speed=1.00"):
    return {
        "item": item,
        "speaker": voice,
        "passage": "s1",
        "word_index": str(idx),
        "word": "w",
        "label": label,
        "teacher": "synthetic",
        "notes": "",
        "error": error,
        "voice": voice,
        "split": split,
        "read": read,
        "aug": aug,
    }


def dataset():
    labels = [
        lab("c1", 0, "right"),
        lab("c1", 1, "right"),
        lab("e1", 0, "wrong", "θ->t", read="error", aug="speed=1.00,white@20dB"),
        lab("e1", 1, "right", read="error", aug="speed=1.00,white@20dB"),
        lab("c2", 0, "right", split="heldout", voice="v2", aug="speed=1.00,phone"),
        lab("e2", 0, "wrong", "added_r", split="heldout", read="error", voice="v2"),
        lab("e2", 1, "wrong", "ɪ->iː", split="heldout", read="error", voice="v2"),
    ]
    words = [
        word_row(item="c1", word_index=0, status="good"),
        word_row(item="c1", word_index=1, status="fix"),  # false red on a clean read
        word_row(item="e1", word_index=0, status="fix"),
        word_row(item="e1", word_index=1, status="good"),
        word_row(item="c2", word_index=0, status="good"),
        word_row(item="e2", word_index=0, status="close"),
        word_row(item="e2", word_index=1, status="missed"),
    ]
    return labels, words


def test_summarise():
    s = R.summarise(*dataset())
    assert s["all"]["words"] == 7
    assert s["all"]["agreement"] == pytest.approx(5 / 7)
    assert s["all_amber_wrong"]["agreement"] == pytest.approx(6 / 7)
    assert s["by_split"]["heldout"]["agreement"] == pytest.approx(2 / 3)
    assert set(s["by_voice"]) == {"v1", "v2"}
    assert s["clean_false_red"] == pytest.approx(1 / 3)
    assert s["clean_false_red_by_split"] == {"heldout": 0.0, "tune": 0.5}
    det = s["detection_by_error"]
    assert det["θ->t"] == {"words": 1, "red": 1.0, "not_green": 1.0}
    assert det["added_r"] == {"words": 1, "red": 0.0, "not_green": 1.0}
    assert s["detection_by_class"]["vowel"]["red"] == 1.0
    assert s["by_augmentation"]["noise"]["words"] == 2
    assert s["by_augmentation"]["phone-band"]["words"] == 1
    assert s["status_by_read"]["clean"] == {"good": 2, "fix": 1}
    assert "voice v2" in R.format_summary(s)


def test_join_skips_unscored_and_unknown():
    labels, words = dataset()
    words[0]["status"] = "notScored"
    assert len(R._join(labels + [lab("zz", 0, "right")], words)) == 6


def write(tmp_path, labels, words):
    lp, wp = tmp_path / "labels.csv", tmp_path / "words.csv"
    for path, rows in ((lp, labels), (wp, words)):
        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, list(rows[0]), lineterminator="\n")
            w.writeheader()
            w.writerows(rows)
    return lp, wp


def test_main_gate(tmp_path, capsys):
    lp, wp = write(tmp_path, *dataset())
    out = tmp_path / "s.json"
    assert R.main(["--labels", str(lp), "--words", str(wp), "--json", str(out)]) == 1
    assert "NO-GO" in capsys.readouterr().out
    assert json.loads(out.read_text())["all"]["words"] == 7
    assert R.main(["--labels", str(lp), "--words", str(wp), "--threshold", "0.6"]) == 0
    assert (
        R.main(["--labels", str(lp), "--words", str(wp), "--gate", "all", "--threshold", "0.7"])
        == 0
    )
    assert R.main(["--labels", str(lp), "--words", str(wp), "--gate", "nope"]) == 0
    assert "SKIPPED" in capsys.readouterr().out


def test_main_skips_without_inputs(tmp_path, capsys):
    assert R.main(["--labels", str(tmp_path / "x.csv"), "--words", str(tmp_path / "y")]) == 0
    assert "SKIPPED" in capsys.readouterr().out


def test_format_handles_empty_groups():
    s = R.summarise([], [])
    assert "(no words)" in R.format_summary(s)
