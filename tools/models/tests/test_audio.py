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
