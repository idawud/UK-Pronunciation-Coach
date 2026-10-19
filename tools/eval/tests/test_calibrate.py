import csv
import json

import pytest

from tools.eval import calibrate as cb
from tools.eval.tests.conftest import word_row


def probe_score(gop: float) -> int:
    return round((gop - cb.PROBE_LO) * 100 / (cb.PROBE_HI - cb.PROBE_LO))


def test_interp_and_round():
    c = cb.DEFAULT_CURVE
    assert cb.interp(c, -100) == 0 and cb.interp(c, 100) == 100
    assert cb.interp(c, 0.5) == pytest.approx(57.5)
    assert cb.dart_round(2.5) == 3 and cb.dart_round(-2.5) == -3 and cb.dart_round(2.4) == 2


def test_shifted_curve():
    c = cb.shifted_curve(1, 2)
    assert c[3] == (-1.0, 50)  # x=0 -> 0/2 - 1
    assert cb.shifted_curve(0, 1) == [(float(x), y) for x, y in cb.DEFAULT_CURVE]


def obs_rows():
    return [
        # good word: gop 4 everywhere
        word_row(item="n1", phoneme_scores=" ".join(str(probe_score(4)) for _ in range(3))),
        # one bad phoneme (gop -2): red under default curve thanks to the cap
        word_row(item="n2", phoneme_scores=f"{probe_score(4)} {probe_score(-2)} {probe_score(4)}"),
        # dropped + intrusive r
        word_row(item="n3", expected="s t ɔː", stress="0 0 1", heard="s ∅ ɔːɹ",
                 phoneme_scores=f"{probe_score(4)} 50 {probe_score(4)}"),
        word_row(item="n4", status="missed", heard="", phoneme_scores=""),
        word_row(item="t1", kind="sub", is_target=1,
                 phoneme_scores=f"{probe_score(4)} {probe_score(-8)} {probe_score(4)}"),
        word_row(item="t2", kind="swap", is_target=1, split="heldout",
                 phoneme_scores=f"{probe_score(-1)} {probe_score(-1)} {probe_score(-1)}"),
    ]  # fmt: skip


def test_observe_flags():
    w = cb.observe(obs_rows())
    assert w[0].phones[1].stressed and w[0].phones[0].gop == pytest.approx(4, abs=0.2)
    assert w[2].phones[1].dropped and w[2].phones[2].intrusive
    assert w[3].phones == []


def test_word_status_matches_dart_rules():
    w = cb.observe(obs_rows())
    p = cb.Params()
    assert cb.word_status(w[0], p)[0] == "good"
    status, score = cb.word_status(w[1], p)
    # (91 + 1.5 * 20 + 91) / 3.5 = 60.6 (stressed middle phoneme), under the cap of 70
    assert status == "close" and score == 61
    assert cb.word_status(w[2], p) == ("fix", 45)  # min(mean, 0 + 50) with r cap 45
    assert cb.word_status(w[3], p) == ("missed", 0)
    lenient = cb.Params(word_max_above_worst=100, dropped_score=100, intrusive_r_score=100)
    assert cb.word_status(w[2], lenient)[0] == "good"


def test_simulate_metrics_search():
    w = cb.observe(obs_rows())
    m = cb.metrics(cb.simulate(w, cb.Params()), "tune")
    assert m["red"] == pytest.approx(2 / 4)  # n3 fix, n4 missed
    assert m["detect"] == 1.0 and m["detect_sub"] == 1.0 and m["detect_swap"] == 0.0
    best, bm, tried = cb.search(w, cb.candidates(dropped=(0, 100), r_scores=(45, 100)), max_red=0.3)
    assert bm["red"] <= 0.3 and len(tried) > 1
    # nothing meets an impossible target (n4 is always missed): lowest red wins
    best2, bm2, _ = cb.search(w, cb.candidates(shifts=(0,), scales=(1,)), max_red=0.0)
    assert bm2["red"] == min(t[0]["red"] for t in _)


def test_agreement_and_params_round_trip():
    sim = [word_row(item="a", status="good"), word_row(item="b", status="fix")]
    dart = [word_row(item="a", status="good"), word_row(item="b", status="close")]
    assert cb.agreement(sim, dart) == 0.5
    assert cb.agreement(sim, []) == 0.0
    p = cb.Params(word_max_above_worst=60, intrusive_r_score=70)
    q = cb.params_from_config(json.loads(json.dumps(p.to_config())))
    assert q == cb.Params(curve=[(float(x), y) for x, y in p.curve], word_max_above_worst=60,
                          intrusive_r_score=70)  # fmt: skip


def write_rows(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def test_cli(tmp_path, capsys):
    assert cb.main(["probe-config"]) == 0
    assert json.loads(capsys.readouterr().out) == cb.PROBE_CONFIG
    probe = tmp_path / "words_probe.csv"
    write_rows(probe, obs_rows())
    extra = tmp_path / "extra.json"
    extra.write_text(json.dumps({"extraAccepted": {"ɒ": ["ɑ"]}}))
    out = tmp_path / "tuned.json"
    assert cb.main(["search", str(probe), "--out", str(out), "--max-red", "0.5",
                    "--extra", str(extra)]) == 0  # fmt: skip
    cfg = json.loads(out.read_text())
    assert cfg["extraAccepted"] == {"ɒ": ["ɑ"]} and "calibration" in cfg
    assert "heldout" in capsys.readouterr().out
    dart = tmp_path / "words_dart.csv"
    write_rows(dart, cb.simulate(cb.observe(obs_rows()), cb.params_from_config(cfg)))
    assert cb.main(["check", str(probe), str(out), str(dart)]) == 0
    assert "1.0000" in capsys.readouterr().out
