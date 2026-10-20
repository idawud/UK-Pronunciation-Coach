"""Seeded realism augmentation for synthetic clips (numpy only).

Per clip: a speaking-rate change of up to +-10% (applied by the TTS engine itself, see
`Profile.speed`), lead / tail silence, then optionally additive noise at 10-30 dB SNR,
mild reverb and a 300-3400 Hz phone band, and finally 16 kHz mono.

Noise is generated here (white, pink or brown Gaussian noise from numpy's seeded RNG):
no recorded noise, so there is no third-party audio to license. Reverb uses a
synthetic room impulse response (exponentially decaying noise), also generated here.
"""

from __future__ import annotations

import random
from dataclasses import asdict, dataclass

import numpy as np

TARGET_SR = 16000
NOISE_KINDS = ("white", "pink", "brown")


@dataclass(frozen=True)
class Profile:
    speed: float = 1.0
    lead_ms: int = 150
    tail_ms: int = 150
    noise: str = ""  # "" = none, else one of NOISE_KINDS
    snr_db: float = 0.0
    rt60: float = 0.0  # 0 = no reverb
    wet: float = 0.0
    phone: bool = False
    gain_db: float = -3.0

    def describe(self) -> str:
        parts = [f"speed={self.speed:.2f}"]
        if self.noise:
            parts.append(f"{self.noise}@{self.snr_db:.0f}dB")
        if self.rt60:
            parts.append(f"reverb={self.rt60:.2f}s")
        if self.phone:
            parts.append("phone")
        return ",".join(parts)

    def to_dict(self) -> dict:
        return asdict(self)


def draw_profile(
    rng: random.Random,
    p_noise: float = 0.7,
    p_reverb: float = 0.3,
    p_phone: float = 0.25,
) -> Profile:
    """A random profile; probabilities are per clip."""
    speed = round(rng.uniform(0.9, 1.1), 3)
    lead, tail = rng.randint(80, 300), rng.randint(80, 300)
    noise, snr = "", 0.0
    if rng.random() < p_noise:
        noise, snr = rng.choice(NOISE_KINDS), round(rng.uniform(10, 30), 1)
    rt60, wet = 0.0, 0.0
    if rng.random() < p_reverb:
        rt60, wet = round(rng.uniform(0.2, 0.5), 2), round(rng.uniform(0.1, 0.3), 2)
    phone = rng.random() < p_phone
    gain = round(rng.uniform(-12, -1), 1)
    return Profile(speed, lead, tail, noise, snr, rt60, wet, phone, gain)


def resample(x: np.ndarray, sr_in: int, sr_out: int) -> np.ndarray:
    """FFT resampling with a raised-cosine taper below the lower Nyquist."""
    x = np.asarray(x, dtype=np.float64)
    if sr_in == sr_out or len(x) == 0:
        return x.copy()
    n_out = int(round(len(x) * sr_out / sr_in))
    spec = np.fft.rfft(x)
    m = n_out // 2 + 1
    if m <= len(spec):
        spec = spec[:m].copy()
    else:
        spec = np.concatenate([spec, np.zeros(m - len(spec), dtype=complex)])
    cutoff = min(sr_in, sr_out) / 2
    freqs = np.arange(m) * sr_out / n_out
    lo = 0.9 * cutoff
    taper = np.ones(m)
    band = (freqs > lo) & (freqs < cutoff)
    taper[band] = 0.5 * (1 + np.cos(np.pi * (freqs[band] - lo) / (cutoff - lo)))
    taper[freqs >= cutoff] = 0.0
    return np.fft.irfft(spec * taper, n_out) * (n_out / len(x))


def coloured_noise(n: int, kind: str, rng: np.random.Generator) -> np.ndarray:
    """Unit-RMS white (flat), pink (1/f power) or brown (1/f^2 power) noise."""
    white = rng.standard_normal(n)
    if kind == "white":
        out = white
    else:
        spec = np.fft.rfft(white)
        f = np.arange(len(spec), dtype=np.float64)
        f[0] = 1.0
        spec = spec / (np.sqrt(f) if kind == "pink" else f)
        out = np.fft.irfft(spec, n)
    out = out - out.mean()
    return out / (np.sqrt(np.mean(out**2)) + 1e-12)


def active_rms(x: np.ndarray, sr: int, floor_db: float = -35.0) -> float:
    """RMS over 20 ms frames within [floor_db] of the loudest frame (speech, not the
    silence padding)."""
    hop = max(1, sr // 50)
    frames = [x[i : i + hop] for i in range(0, len(x) - hop + 1, hop)] or [x]
    e = np.array([np.mean(f**2) for f in frames])
    if e.max() <= 0:
        return 0.0
    keep = e >= e.max() * 10 ** (floor_db / 10)
    return float(np.sqrt(e[keep].mean()))


def add_noise(
    x: np.ndarray, sr: int, snr_db: float, kind: str, rng: np.random.Generator
) -> np.ndarray:
    n = coloured_noise(len(x), kind, rng)
    rms = active_rms(x, sr)
    return x + n * rms / 10 ** (snr_db / 20)


def reverb(x: np.ndarray, sr: int, rt60: float, wet: float, rng: np.random.Generator) -> np.ndarray:
    """Mixes in a synthetic room response: decaying noise reaching -60 dB at [rt60]."""
    n = max(1, int(rt60 * sr))
    t = np.arange(n) / sr
    ir = rng.standard_normal(n) * np.exp(-6.9078 * t / rt60)
    ir[0] = 0.0
    ir /= np.sqrt(np.sum(ir**2)) + 1e-12
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    tail = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    return (1 - wet) * x + wet * tail


def phone_band(x: np.ndarray, sr: int, lo: float = 300.0, hi: float = 3400.0) -> np.ndarray:
    """Telephone band-pass (FFT mask with 100 Hz cosine edges)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    g = np.zeros_like(f)
    g[(f >= lo) & (f <= hi)] = 1.0
    up = (f > lo - 100) & (f < lo)
    g[up] = 0.5 * (1 - np.cos(np.pi * (f[up] - (lo - 100)) / 100))
    down = (f > hi) & (f < hi + 100)
    g[down] = 0.5 * (1 + np.cos(np.pi * (f[down] - hi) / 100))
    return np.fft.irfft(spec * g, len(x))


def apply(x: np.ndarray, sr: int, p: Profile, seed: int) -> np.ndarray:
    """TTS output at [sr] -> augmented 16 kHz mono float in [-1, 1]."""
    rng = np.random.default_rng(seed)
    y = resample(np.asarray(x, dtype=np.float64).reshape(-1), sr, TARGET_SR)
    y = np.concatenate(
        [np.zeros(p.lead_ms * TARGET_SR // 1000), y, np.zeros(p.tail_ms * TARGET_SR // 1000)]
    )
    if p.rt60:
        y = reverb(y, TARGET_SR, p.rt60, p.wet, rng)
    if p.noise:
        y = add_noise(y, TARGET_SR, p.snr_db, p.noise, rng)
    if p.phone:
        y = phone_band(y, TARGET_SR)
    peak = np.max(np.abs(y)) or 1.0
    return y / peak * 10 ** (p.gain_db / 20)


def clean(x: np.ndarray, sr: int, lead_ms: int = 150, tail_ms: int = 150) -> np.ndarray:
    """The dry version: just 16 kHz, padding and -3 dBFS peak."""
    return apply(x, sr, Profile(lead_ms=lead_ms, tail_ms=tail_ms), seed=0)
