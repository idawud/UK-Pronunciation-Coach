import hashlib
import io
import json

import numpy as np
import pytest

from tools.eval.synth import voices as V


class FakeSession:
    def __init__(self, out):
        self.out = out
        self.calls = []

    def run(self, names, feeds):
        self.calls.append(feeds)
        return [self.out]


def kokoro_root(tmp_path):
    k = tmp_path / "kokoro"
    (k / "voices").mkdir(parents=True)
    vocab = {c: i for i, c in enumerate("$ abdkstˈɪŋθ.", start=0)}
    (k / "tokenizer.json").write_text(json.dumps({"model": {"vocab": vocab}}))
    styles = np.arange(5 * 256, dtype=np.float32).reshape(5, 1, 256)
    styles.tofile(k / "voices" / "bf_emma.bin")
    return tmp_path


def test_registry():
    assert len(V.VOICES) == 10
    held = {v.name for v in V.VOICES.values() if v.split == "heldout"}
    assert held == {"bm_george", "bf_isabella", "cori_medium", "cori_high"}
    assert {V.VOICES[n].sex for n in held} == {"M", "F"}
    assert {v.speaker for v in V.VOICES.values() if v.engine == "piper"} == {"cori"}
    for v in V.VOICES.values():
        assert all(f in V.FILES and V.FILES[f][1] for f in v.files)


def test_kokoro_engine_ids_style_and_speed(tmp_path):
    root = kokoro_root(tmp_path)
    sess = FakeSession(np.ones((1, 480), np.float32))
    eng = V.KokoroEngine(root, session=sess)
    audio, sr = eng.synth("θˈɪŋk.", "bf_emma", speed=1.1)
    assert sr == 24000 and audio.shape == (480,)
    feeds = sess.calls[0]
    ids = feeds["input_ids"][0].tolist()
    assert ids[0] == 0 and ids[-1] == 0 and len(ids) == 8
    assert feeds["style"].shape == (1, 256)
    assert feeds["style"][0, 0] == 4 * 256  # style row = token count (clamped to 4)
    assert feeds["speed"].tolist() == pytest.approx([1.1])
    with pytest.raises(ValueError, match="vocab"):
        eng.ids("ʘ")
    with pytest.raises(ValueError, match="too long"):
        eng.ids("a" * 511)


def piper_model(tmp_path):
    cfg = {
        "audio": {"sample_rate": 22050},
        "inference": {"noise_scale": 0.5, "noise_w": 0.7},
        "phoneme_id_map": {"_": [0], "^": [1], "$": [2], "a": [5], "t": [6]},
    }
    model = tmp_path / "v.onnx"
    model.with_name("v.onnx.json").write_text(json.dumps(cfg))
    return model


def test_piper_engine_ids_with_pads_and_scales(tmp_path):
    sess = FakeSession(np.ones((1, 1, 1, 300), np.float32))
    eng = V.PiperEngine(piper_model(tmp_path), session=sess)
    assert eng.ids("at") == [1, 0, 5, 0, 6, 0, 2]
    audio, sr = eng.synth("at", speed=0.8)
    assert sr == 22050 and audio.shape == (300,)
    feeds = sess.calls[0]
    assert feeds["input_lengths"].tolist() == [7]
    assert feeds["scales"].tolist() == pytest.approx([0.5, 1.25, 0.7])
    with pytest.raises(ValueError, match="phoneme map"):
        eng.ids("x")


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def test_fetch_downloads_checks_and_skips_existing(tmp_path, monkeypatch):
    data = {"m.onnx": b"model", "m.onnx.json": b"{}"}
    monkeypatch.setattr(
        V,
        "FILES",
        {k: (f"https://x/{k}", hashlib.sha256(v).hexdigest()) for k, v in data.items()},
    )
    monkeypatch.setitem(V.VOICES, "t", V.Voice("t", "piper", "F", "tune", "t", tuple(data)))
    calls = []

    def opener(url):
        calls.append(url)
        return FakeResponse(data[url.rsplit("/", 1)[1]])

    assert V.fetch(["t"], tmp_path, opener) == sorted(data)
    assert (tmp_path / "m.onnx").read_bytes() == b"model"
    assert V.available(V.VOICES["t"], tmp_path)
    V.fetch(["t"], tmp_path, opener)
    assert len(calls) == 2  # cached the second time

    monkeypatch.setitem(V.FILES, "m.onnx", ("https://x/m.onnx", "0" * 64))
    with pytest.raises(ValueError, match="SHA-256"):
        V.fetch(["t"], tmp_path, opener)
    assert not (tmp_path / "m.onnx").exists()
    assert not V.available(V.VOICES["t"], tmp_path)
