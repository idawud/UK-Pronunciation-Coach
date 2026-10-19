"""Shared fixtures: a tiny random wav2vec2 CTC model, synthetic clips, a fake eSpeak."""

from __future__ import annotations

import json
import subprocess

import numpy as np
import pytest
import soundfile as sf

# A small English-like vocab using full-tier token strings; blank `<pad>` = 0.
TOKENS = ["<pad>", "<s>", "</s>", "<unk>", "p", "l", "iː", "z", "k", "ɔː", "s", "t", "ɛ", "ɐ"]
VOCAB = {t: i for i, t in enumerate(TOKENS)}

# Canned eSpeak output (`--ipa --sep=_`) for transcripts used in the tests.
ESPEAK_OUT = {
    "please call stella": "p_l_ˈiː_z k_ˈɔː_l s_t_ˈɛ_l_ɐ\n",
    "call": "k_ˈɔː_l\n",
    "please": "p_l_ˈiː_z\n",
}


def fake_espeak_runner(cmd, **kwargs):
    """Stands in for subprocess.run([espeak-ng, ..., text])."""
    text = cmd[-1].lower().strip(" .")
    return subprocess.CompletedProcess(cmd, 0, stdout=ESPEAK_OUT.get(text, ""), stderr="")


@pytest.fixture
def espeak(monkeypatch):
    """Points ESPEAK_NG at a dummy path and returns the fake runner."""
    monkeypatch.setenv("ESPEAK_NG", "/fake/espeak-ng")
    return fake_espeak_runner


def tone(seconds: float, freq: float, sr: int = 16000, seed: int = 0) -> np.ndarray:
    """A short tone plus a little noise: stands in for speech."""
    t = np.arange(int(sr * seconds)) / sr
    rng = np.random.default_rng(seed)
    return (0.3 * np.sin(2 * np.pi * freq * t) + 0.01 * rng.standard_normal(t.size)).astype(
        np.float32
    )


@pytest.fixture
def clips_dir(tmp_path):
    """Three 16 kHz WAVs with a manifest.tsv (id, path, speaker, text)."""
    out = tmp_path / "clips"
    (out / "wav").mkdir(parents=True)
    rows = [("c1", "Please call Stella.", 220), ("c2", "Call", 330), ("c3", "Please", 440)]
    lines = ["id\tpath\tspeaker\ttext"]
    for i, (cid, text, freq) in enumerate(rows):
        sf.write(out / "wav" / f"{cid}.wav", tone(0.8 + 0.2 * i, freq, seed=i), 16000)
        lines.append(f"{cid}\twav/{cid}.wav\tp9{i}\t{text}")
    (out / "manifest.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


@pytest.fixture(scope="session")
def tiny_model():
    """Tiny random Wav2Vec2ForCTC (eval mode) over VOCAB."""
    import torch

    from tools.models.train_light import tiny_config

    torch.manual_seed(0)
    from transformers import Wav2Vec2ForCTC

    return Wav2Vec2ForCTC(tiny_config(len(VOCAB))).eval()


@pytest.fixture(scope="session")
def tiny_model_dir(tmp_path_factory, tiny_model):
    """The tiny model saved as a HF directory with vocab.json."""
    out = tmp_path_factory.mktemp("tiny_hf")
    tiny_model.save_pretrained(out)
    (out / "vocab.json").write_text(json.dumps(VOCAB, ensure_ascii=False), encoding="utf-8")
    return out


@pytest.fixture(scope="session")
def tiny_export(tmp_path_factory, tiny_model):
    """export_tier run once on the tiny model: (release tier dir, work dir, summary)."""
    from tools.models import export_onnx as ex

    root = tmp_path_factory.mktemp("tiny_export")
    summary = ex.export_tier(tiny_model, VOCAB, root / "release" / "full", root / "work")
    return root / "release" / "full", root / "work", summary
