import json

import numpy as np
import pytest

from tools.models import evaluate as ev
from tools.models.tests.conftest import VOCAB


def test_read_manifest_and_spread(clips_dir):
    rows = ev.read_manifest(clips_dir / "manifest.tsv")
    assert rows[0]["path"] == str(clips_dir / "wav" / "c1.wav")
    assert len(ev.read_manifest(clips_dir / "manifest.tsv", 2)) == 2
    many = [{"speaker": s, "id": f"{s}{i}"} for s in "ab" for i in range(3)]
    assert [r["id"] for r in ev.spread(many, 3)] == ["a0", "b0", "a1"]


def test_compare_logits():
    a = np.array([[1.0, 0.0], [0.0, 2.0]])
    same = ev.compare_logits(a, a + 1.0)  # a constant shift keeps log-probs
    assert same["max_abs"] == 1.0 and same["max_abs_logprob"] < 1e-9
    assert same["argmax_agree"] == 1.0
    with pytest.raises(ValueError):
        ev.compare_logits(a, a[:1])
    flipped = ev.compare_logits(a, a[:, ::-1])
    assert flipped["argmax_agree"] == 0.0
    assert ev.summarise([same, flipped])["clips"] == 2


def test_decode_drops_blank_and_specials():
    tokens = ["<pad>", "<s>", "a", "b"]
    logits = np.eye(4)[[2, 2, 0, 2, 1, 3]]
    assert ev.decode(logits, tokens, 0) == ["a", "a", "b"]


def test_evaluate_end_to_end_on_tiny_model(tiny_model, tiny_export, clips_dir):
    release, work, _ = tiny_export
    rows = ev.read_manifest(clips_dir / "manifest.tsv")
    report = ev.evaluate(
        tiny_model,
        VOCAB,
        release,
        work / "model.fp32.onnx",
        rows,
        rows,
        labeler=lambda text: ["p", "l"],
        threads=(1,),
        bench_seconds=1.0,
    )
    assert report["opset"] == 17 and report["blank_index"] == 0
    assert report["verify"]["fp32"]["max_abs"] < 1e-4
    assert report["verify"]["int8"]["clips"] == 3
    assert 0 <= report["per"]["int8"]["per"]
    assert report["per"]["fp32"]["ref_phonemes"] == 6
    assert set(report["cpu_seconds"]) == {"fp32_1_threads", "int8_1_threads"}
    assert report["eval_speakers"] == ["p90", "p91", "p92"]


def test_main_writes_report(tiny_model_dir, tiny_export, clips_dir, espeak, monkeypatch):
    release, work, _ = tiny_export
    monkeypatch.setattr(ev.ph.subprocess, "run", espeak)
    code = ev.main(
        [
            "--model", str(tiny_model_dir), "--release", str(release), "--work", str(work),
            "--verify-clips", str(clips_dir / "manifest.tsv"),
            "--eval-clips", str(clips_dir / "manifest.tsv"), "--bench-seconds", "0.5",
        ]
    )  # fmt: skip
    assert code == 0
    report = json.loads((work / "report.json").read_text(encoding="utf-8"))
    assert report["per"]["int8"]["ref_phonemes"] == 12 + 3 + 4
    assert report["ref_voice"] == "en-gb-x-rp"
