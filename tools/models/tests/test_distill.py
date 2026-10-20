"""CPU distillation end to end on a tiny random teacher: student init, teacher cache,
KL training with checkpoint/resume, export to uint8 ONNX, ONNX Runtime load, manifest."""

from __future__ import annotations

import json
import random

import numpy as np
import pytest
import torch

from tools.models import distill as d
from tools.models import evaluate as ev
from tools.models import export_onnx as ex
from tools.models import manifest as mf
from tools.models.audio import normalise
from tools.models.tests.conftest import VOCAB, tone
from tools.models.train_light import tiny_config


@pytest.fixture(scope="module")
def teacher():
    """Tiny stable-layer-norm teacher (the full model's layout) with 4 layers."""
    from transformers import Wav2Vec2ForCTC

    torch.manual_seed(1)
    cfg = tiny_config(
        len(VOCAB),
        num_hidden_layers=4,
        do_stable_layer_norm=True,
        feat_extract_norm="layer",
        mask_time_prob=0.05,
    )
    return Wav2Vec2ForCTC(cfg).eval()


@pytest.fixture(scope="module")
def teacher_dir(tmp_path_factory, teacher):
    out = tmp_path_factory.mktemp("teacher")
    teacher.save_pretrained(out)
    (out / "vocab.json").write_text(json.dumps(VOCAB, ensure_ascii=False), encoding="utf-8")
    return out


@pytest.fixture
def cache(tmp_path, teacher, clips_dir):
    c = d.FrameCache(tmp_path / "cache", teacher.config.conv_dim[-1], len(VOCAB))
    d.prepare(teacher, ev.read_manifest(clips_dir / "manifest.tsv"), c, log=lambda m: None)
    return c


def test_parse_layers():
    assert d.parse_layers("0, 3,7") == (0, 3, 7)
    for bad in ("", "3,1", "2,2"):
        with pytest.raises(ValueError):
            d.parse_layers(bad)


@pytest.mark.parametrize("stable", [False, True])
def test_forward_from_features_matches_model(stable):
    from transformers import Wav2Vec2ForCTC

    torch.manual_seed(0)
    cfg = tiny_config(
        len(VOCAB),
        do_stable_layer_norm=stable,
        feat_extract_norm="layer" if stable else "group",
    )
    model = Wav2Vec2ForCTC(cfg).eval()
    audio = normalise(tone(1.1, 250))
    with torch.no_grad():
        mine = d.logits_from_features(model, d.conv_features(model, audio))
    assert np.abs(mine[0].numpy() - ex.torch_logits(model, audio)).max() < 1e-5


def test_make_student_copies_chosen_layers(teacher):
    student = d.make_student(teacher, (1, 3), dropout=0.0)
    assert student.config.num_hidden_layers == 2
    assert student.config.distill_keep_layers == [1, 3]
    t, s = teacher.state_dict(), student.state_dict()
    for i, j in ((1, 0), (3, 1)):
        key = "wav2vec2.encoder.layers.{}.feed_forward.output_dense.weight"
        assert torch.equal(t[key.format(i)], s[key.format(j)])
    assert torch.equal(t["lm_head.weight"], s["lm_head.weight"])
    assert not any(p.requires_grad for p in student.wav2vec2.feature_extractor.parameters())
    assert d.count_params(student) < d.count_params(teacher)
    with pytest.raises(ValueError):
        d.make_student(teacher, (0, 9))


def test_make_student_without_spec_augment_embed():
    from transformers import Wav2Vec2ForCTC

    plain = Wav2Vec2ForCTC(tiny_config(len(VOCAB), num_hidden_layers=3)).eval()
    student = d.make_student(plain, (0, 2), mask_time_prob=0.05)
    assert hasattr(student.wav2vec2, "masked_spec_embed")


def test_full_layer_student_reproduces_teacher(teacher, cache):
    student = d.make_student(teacher, (0, 1, 2, 3), dropout=0.0)
    res = d.compare_to_teacher(student, cache)
    assert res["clips"] == 3
    assert res["argmax_agree"] == 1.0
    assert res["teacher_per"] == 0.0
    assert res["kl"] < 1e-3


def test_cache_roundtrip_resume_and_truncation(tmp_path, teacher, clips_dir, cache):
    assert len(cache) == 3 and cache.ids == {"c1", "c2", "c3"}
    feats, logp = cache.get(1)
    assert feats.shape == (cache.entries[1]["frames"], teacher.config.conv_dim[-1])
    assert logp.shape == (feats.shape[0], len(VOCAB))
    assert np.allclose(np.exp(logp).sum(-1), 1, atol=1e-2)
    rows = ev.read_manifest(clips_dir / "manifest.tsv")
    assert d.prepare(teacher, rows, cache, log=lambda m: None) == 0  # nothing new
    # simulate a crash mid-append: junk bytes plus a torn index line
    (cache.root / "feats.f16").open("ab").write(b"\0" * 1000)
    (cache.root / "index.jsonl").open("a").write('{"id": "c4", "fra')
    reopened = d.FrameCache(cache.root)
    assert len(reopened) == 3
    assert (cache.root / "feats.f16").stat().st_size == reopened.frames * 32 * 2
    assert np.array_equal(reopened.get(2)[0], cache.get(2)[0])
    with pytest.raises(FileNotFoundError):
        d.FrameCache(tmp_path / "missing")
    with pytest.raises(ValueError):
        cache.append("bad", np.zeros((3, 32)), np.zeros((2, len(VOCAB))))


def test_frame_batches_respect_budget():
    rng = random.Random(0)
    lengths = [rng.randint(20, 300) for _ in range(500)]
    batches = d.frame_batches(lengths, 1000, random.Random(1))
    assert sorted(i for b in batches for i in b) == list(range(500))
    for b in batches:
        assert len(b) == 1 or len(b) * max(lengths[i] for i in b) <= 1000


def test_collate_and_loss():
    a = (np.ones((5, 4), np.float32), np.log(np.full((5, 3), 1 / 3, np.float32)))
    b = (np.ones((2, 4), np.float32), np.log(np.full((2, 3), 1 / 3, np.float32)))
    feats, logp, mask = d.collate_frames([a, b])
    assert feats.shape == (2, 5, 4) and mask.sum() == 7
    loss, parts = d.distill_loss(logp.clone(), logp, mask)
    assert abs(float(loss)) < 1e-6 and set(parts) == {"kl"}
    wrong = torch.zeros(2, 5, 3)
    wrong[..., 1] = 5.0
    loss2, parts2 = d.distill_loss(wrong, logp, mask, temperature=2.0, ctc_weight=0.5)
    assert float(loss2) > 0 and "ctc" in parts2


def test_lr_schedule():
    assert d.lr_at(0, 100, 10, 1.0) == pytest.approx(0.1)
    assert d.lr_at(10, 100, 10, 1.0) == pytest.approx(1.0)
    assert d.lr_at(100, 100, 10, 1.0) == pytest.approx(0.05)
    assert d.lr_at(55, 100, 10, 1.0) < 1.0


def test_train_checkpoint_resume_and_improves(tmp_path, teacher, cache):
    student = d.make_student(teacher, (0, 3), dropout=0.0, mask_time_prob=0.0)
    before = student.lm_head.weight.detach().clone()
    out = tmp_path / "student"
    logs: list[str] = []
    hist = d.train(
        student, cache, out, steps=6, max_frames=200, lr=3e-3, warmup=1,
        eval_cache=cache, eval_every=3, ckpt_minutes=0.0, log=logs.append,
    )  # fmt: skip
    assert len(hist) == 6 and "val" in hist[2] and "val" in hist[5]
    assert (out / d.CKPT).exists()
    assert len((out / "train_log.jsonl").read_text().splitlines()) == 6
    assert not torch.equal(student.lm_head.weight.detach(), before)
    assert all(np.isfinite(h["loss"]) for h in hist)
    # resume: a fresh student picks up the checkpoint and continues to step 9
    again = d.make_student(teacher, (0, 3), dropout=0.0, mask_time_prob=0.0)
    hist2 = d.train(again, cache, out, steps=9, max_frames=200, lr=3e-3, warmup=1,
                    log=logs.append)  # fmt: skip
    assert any("resumed at step 6" in m for m in logs)
    assert [h["step"] for h in hist2] == list(range(1, 10))
    # nothing left to do: returns immediately
    assert len(d.train(again, cache, out, steps=9, log=logs.append)) == 9


def test_train_stops_on_time_budget(tmp_path, teacher, cache):
    student = d.make_student(teacher, (0,), dropout=0.0, mask_time_prob=0.0)
    hist = d.train(student, cache, tmp_path / "s", steps=1000, hours=1e-9, log=lambda m: None)
    assert len(hist) == 1


def test_multi_cache(tmp_path, teacher, cache):
    other = d.FrameCache(tmp_path / "other", teacher.config.conv_dim[-1], len(VOCAB))
    other.append("x", np.zeros((4, 32)), np.zeros((4, len(VOCAB))))
    both = d._merge([cache, other], tmp_path)
    assert len(both) == 4 and both.frames == cache.frames + 4
    assert both.get(3)[0].shape == (4, 32)


def test_cli_end_to_end_export_quantise_load_manifest(tmp_path, teacher_dir, clips_dir, capsys):
    """prepare -> init-check -> train -> compare -> export uint8 -> ORT -> manifest."""
    manifest = clips_dir / "manifest.tsv"
    common = ["--teacher", str(teacher_dir), "--threads", "2"]
    cache = tmp_path / "cache"
    assert d.main(["prepare", *common, "--manifest", str(manifest), "--cache", str(cache),
                   "--exclude-speakers", "p92"]) == 0  # fmt: skip
    assert len(d.FrameCache(cache)) == 2
    assert d.main(["init-check", *common, "--cache", str(cache), "--candidates", "0,3", "1"]) == 0
    out = tmp_path / "student"
    assert d.main(["train", *common, "--cache", str(cache), str(cache), "--eval-cache",
                   str(cache), "--out", str(out), "--keep-layers", "0,3", "--steps", "3",
                   "--max-frames", "200", "--eval-every", "2", "--warmup", "1"]) == 0  # fmt: skip
    hf = out / "hf"
    assert json.loads((hf / "vocab.json").read_text(encoding="utf-8")) == VOCAB
    capsys.readouterr()
    assert d.main(["compare", "--model", str(hf), "--cache", str(cache)]) == 0
    assert "argmax_agree" in capsys.readouterr().out

    release = tmp_path / "release"
    assert ex.main(["--model", str(hf), "--out", str(release / "light"), "--work",
                    str(tmp_path / "work"), "--quantise-conv", "--quant-exclude",
                    "conv_layers.0/"]) == 0  # fmt: skip
    summary = json.loads((tmp_path / "work" / "export.json").read_text())
    assert summary["quant_exclude"] == ["conv_layers.0/"]
    import onnx

    graph = onnx.load(str(release / "light" / "model.onnx")).graph
    ops = [n.op_type for n in graph.node]
    assert "ConvInteger" in ops and "Conv" in ops  # first conv kept float32
    sess = ex.session(release / "light" / "model.onnx", threads=1)
    logits = ex.onnx_logits(sess, normalise(tone(1.0, 300)))
    assert logits.shape == (49, len(VOCAB))
    m = mf.build_manifest(release)
    assert {f["name"] for f in m["files"]} == {"light-model.onnx", "light-vocab.json"}
    assert all(f["bundle"] for f in m["files"])
    mf.write_manifest(release, m)
    assert mf.verify_manifest(release) == []


def test_nodes_matching_empty_patterns(tmp_path):
    assert ex.nodes_matching(tmp_path / "unused.onnx", ()) == []
