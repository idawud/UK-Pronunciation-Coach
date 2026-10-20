"""Audio loading for model tools: any soundfile-readable bytes/path -> 16 kHz mono float32."""

from __future__ import annotations

import io
from pathlib import Path

import numpy as np
import soundfile as sf

SAMPLE_RATE = 16000
HALF_TAPS = 32  # windowed-sinc half width (input samples at the lower rate)
CHUNK = 1 << 15


def resample(audio: np.ndarray, sr_in: int, sr_out: int, fast: bool = True) -> np.ndarray:
    """Band-limited resampling with a Kaiser-windowed sinc (numpy only; scipy's wheel
    metadata trips the licence check). Cut-off is 0.95 x the lower Nyquist frequency."""
    if sr_in == sr_out:
        return audio.astype(np.float32)
    ratio = sr_out / sr_in
    cutoff = 0.95 * min(1.0, ratio)  # in units of the input Nyquist
    n_out = int(np.ceil(audio.size * ratio))
    half = int(np.ceil(HALF_TAPS / min(1.0, ratio)))
    offsets = np.arange(-half + 1, half + 1)
    padded = np.concatenate([np.zeros(half), audio, np.zeros(half + 1)])
    window = np.kaiser(2 * half + 1, 8.6)
    if fast and sr_in % sr_out == 0:
        # integer decimation (48 kHz -> 16 kHz): output samples sit on input samples, so the
        # same kernel is a fixed FIR; correlate once and keep every factor-th sample
        dist = -offsets
        taps = cutoff * np.sinc(cutoff * dist) * window[dist + half]
        full = np.correlate(padded[1:], taps, mode="valid")
        return full[:: sr_in // sr_out][:n_out].astype(np.float32)
    out = np.empty(n_out, dtype=np.float64)
    for start in range(0, n_out, CHUNK):
        t = np.arange(start, min(start + CHUNK, n_out)) / ratio  # input-sample positions
        base = np.floor(t).astype(np.int64)
        idx = base[:, None] + offsets[None, :]
        dist = t[:, None] - idx
        win = np.interp(dist, np.arange(-half, half + 1), window, left=0.0, right=0.0)
        kernel = cutoff * np.sinc(cutoff * dist) * win
        out[start : start + t.size] = (padded[idx + half] * kernel).sum(axis=1)
    return out.astype(np.float32)


def to_mono_16k(audio: np.ndarray, sr: int) -> np.ndarray:
    """Downmixes to mono and resamples to 16 kHz (polyphase), as float32."""
    audio = np.asarray(audio, dtype=np.float32)
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    return resample(audio, sr, SAMPLE_RATE)


def load_audio(source: bytes | str | Path) -> np.ndarray:
    """Reads WAV/FLAC/OGG from a path or raw bytes into 16 kHz mono float32."""
    if isinstance(source, bytes | bytearray):
        source = io.BytesIO(source)
    audio, sr = sf.read(source, dtype="float32", always_2d=False)
    return to_mono_16k(audio, sr)


def normalise(audio: np.ndarray) -> np.ndarray:
    """Zero-mean, unit-variance (Wav2Vec2FeatureExtractor `do_normalize`, A2 does the same)."""
    audio = np.asarray(audio, dtype=np.float32)
    return ((audio - audio.mean()) / np.sqrt(audio.var() + 1e-7)).astype(np.float32)
