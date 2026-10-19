"""Light-tier pipeline end to end on a tiny random model and three clips."""

import json
import random

import numpy as np
import torch

from tools.models import export_onnx as ex
from tools.models import train_light as tl
from tools.models.tests.conftest import VOCAB, fake_espeak_runner


def test_collate_pads_audio_and_labels():
    x, mask, y = tl.collate([np.ones(3, np.float32), np.ones(5, np.float32)], [[4], [5, 6]])
    assert x.shape == (2, 5) and mask[0].tolist() == [1, 1, 1, 0, 0]
    assert y.tolist() == [[4, -100], [5, 6]]


def test_batches_cover_every_item_once():
    out = tl.batches(list(range(23)), 4, random.Random(0))
    assert sorted(i for b in out for i in b) == list(range(23))
    assert max(len(b) for b in out) == 4


def test_lr_schedule():
    assert tl.lr_at(0, 100, 10, 1.0) == 0.1
    assert tl.lr_at(9, 100, 10, 1.0) == 1.0
    assert tl.lr_at(55, 100, 10, 1.0) == 0.5
    assert tl.lr_at(100, 100, 10, 1.0) == 0.0


def test_label_rows_skips_empty(espeak):
    rows = [{"text": "Please"}, {"text": "unknown words"}]
    out = tl.label_rows(rows, VOCAB, runner=espeak)
    assert out == [{"text": "Please", "tokens": ["p", "l", "iː", "z"]}]


def test_train_reduces_loss_on_tiny_data(clips_dir, espeak):
    rows = tl.label_rows(tl.read_manifest(clips_dir / "manifest.tsv"), VOCAB, runner=espeak)
    vocab = tl.ph.build_light_vocab([r["tokens"] for r in rows], VOCAB)
    model = tl.build_model(vocab, tiny=True)
    clips = tl.Clips(rows, vocab)
    logs = []
    history = tl.train(
        model, clips, clips, vocab, steps=40, batch_size=3, lr=3e-3, warmup=5,
        eval_every=20, log=logs.append,
    )  # fmt: skip
    assert history[-1]["loss"] < history[0]["loss"]
    assert "val_per" in history[19] and "val_per" in history[-1]
    assert not model.training and logs


def test_main_then_export(clips_dir, tmp_path, monkeypatch):
    monkeypatch.setenv("ESPEAK_NG", "/fake/espeak-ng")
    full_vocab = tmp_path / "full_vocab.json"
    full_vocab.write_text(json.dumps(VOCAB, ensure_ascii=False), encoding="utf-8")
    out = tmp_path / "hf"
    manifest = str(clips_dir / "manifest.tsv")
    args = ["--train", manifest, "--val", manifest, "--full-vocab", str(full_vocab)]
    args += ["--tiny", "--out", str(out), "--steps", "4", "--batch-size", "2", "--eval-every", "2"]
    assert tl.main(args, runner=fake_espeak_runner) == 0
    assert (out / "labels.train.jsonl").exists()
    # cached labels are reused (no eSpeak needed the second time)
    assert len(tl.load_or_label(clips_dir / "manifest.tsv", VOCAB, out / "labels.train.jsonl")) == 3
    vocab = json.loads((out / "vocab.json").read_text(encoding="utf-8"))
    assert vocab["<pad>"] == 0 and set(vocab) <= set(VOCAB)
    assert len(json.loads((out / "train_log.json").read_text())) == 4

    model, loaded = ex.load_model(out)
    summary = ex.export_tier(
        model, loaded, tmp_path / "release" / "light", tmp_path / "work",
        quant_ops=ex.QUANT_OPS_WITH_CONV,
    )  # fmt: skip
    assert summary["vocab_size"] == len(vocab)
    sess = ex.session(tmp_path / "release" / "light" / "model.onnx")
    logits = ex.onnx_logits(sess, np.zeros(16000, np.float32))
    assert logits.shape == (49, len(vocab))
    assert torch.is_grad_enabled()
