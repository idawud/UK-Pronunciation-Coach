"""Audio loading for model tools: any soundfile-readable bytes/path -> 16 kHz mono float32."""

from __future__ import annotations

import io
from math import gcd
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

SAMPLE_RATE = 16000


def to_mono_16k(audio: np.ndarray, sr: int) -> np.ndarray:
    """Downmixes to mono and resamples to 16 kHz (polyphase), as float32."""
    audio = np.asarray(audio, dtype=np.float32)
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    if sr != SAMPLE_RATE:
        g = gcd(sr, SAMPLE_RATE)
        audio = resample_poly(audio, SAMPLE_RATE // g, sr // g).astype(np.float32)
    return audio


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
