import io

import numpy as np
import soundfile as sf

from tools.models import audio


def test_load_audio_from_bytes_resamples_and_downmixes():
    buf = io.BytesIO()
    stereo = np.stack([np.full(48000, 0.2), np.full(48000, 0.4)], axis=1)
    sf.write(buf, stereo, 48000, format="WAV")
    out = audio.load_audio(buf.getvalue())
    assert out.dtype == np.float32 and out.shape == (16000,)
    assert abs(float(out[8000]) - 0.3) < 1e-3


def test_load_audio_from_path_keeps_16k(tmp_path):
    path = tmp_path / "a.wav"
    sf.write(path, np.linspace(-0.5, 0.5, 1600), 16000)
    assert audio.load_audio(path).shape == (1600,)


def test_normalise_zero_mean_unit_variance():
    out = audio.normalise(np.array([1.0, 2.0, 3.0, 4.0]))
    assert abs(out.mean()) < 1e-6 and abs(out.std() - 1) < 1e-3


def test_resample_keeps_tones_and_removes_aliases():
    for sr in (48000, 22050, 8000):
        t = np.arange(sr) / sr
        out = audio.resample(np.sin(2 * np.pi * 440 * t), sr, 16000)
        tt = np.arange(out.size) / 16000
        assert out.size == 16000
        assert np.abs(out - np.sin(2 * np.pi * 440 * tt))[200:-200].max() < 0.01
    above_nyquist = np.sin(2 * np.pi * 12000 * np.arange(48000) / 48000)
    assert np.abs(audio.resample(above_nyquist, 48000, 16000))[200:-200].max() < 0.01
    same = np.ones(5)
    assert audio.resample(same, 16000, 16000).dtype == np.float32


def test_integer_decimation_fast_path_matches_general_resampler():
    rng = np.random.default_rng(0)
    for n in (48000, 48001, 48002, 100):
        x = rng.standard_normal(n)
        fast = audio.resample(x, 48000, 16000)
        slow = audio.resample(x, 48000, 16000, fast=False)
        assert fast.shape == slow.shape
        assert np.abs(fast - slow).max() < 1e-5
