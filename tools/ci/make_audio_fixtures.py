"""Generate the WAV fixtures in test/fixtures/audio/ (dev-side only, never shipped).

Speech comes from eSpeak NG (GPL-3.0; allowed in tools/ only, its audio output is not
covered by the GPL). Noise and silence are generated with a fixed seed, so the output
is reproducible. All files are 16 kHz mono 16-bit PCM, like the app's recordings.

    ESPEAK_NG=/path/to/espeak-ng python tools/ci/make_audio_fixtures.py

Also writes test/fixtures/audio/manifest.json describing each clip.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 16000
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test" / "fixtures" / "audio"
SENTENCE = "On Thursday we walked by the river."
# "Tursday": the θ in Thursday said as /t/ (a classic substitution).
MISPRONOUNCED = "On Tursday we walked by the river."


def read_wav(path: Path) -> tuple[np.ndarray, int]:
    """Reads a 16-bit mono WAV as float32 in [-1, 1]."""
    with wave.open(str(path), "rb") as w:
        if w.getsampwidth() != 2 or w.getnchannels() != 1:
            raise ValueError(f"{path}: expected 16-bit mono")
        rate = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
    return data.astype(np.float32) / 32768.0, rate


def write_wav(path: Path, audio: np.ndarray, rate: int = SAMPLE_RATE) -> None:
    """Writes float audio in [-1, 1] as 16-bit mono PCM."""
    pcm = np.clip(np.round(audio * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())


def resample(audio: np.ndarray, src: int, dst: int) -> np.ndarray:
    """FFT resampling (band-limited); fine for short clips."""
    if src == dst:
        return audio.astype(np.float32)
    n_out = int(round(len(audio) * dst / src))
    spectrum = np.fft.rfft(audio)
    keep = n_out // 2 + 1
    if keep <= len(spectrum):
        spectrum = spectrum[:keep]
    else:
        spectrum = np.pad(spectrum, (0, keep - len(spectrum)))
    return (np.fft.irfft(spectrum, n_out) * (n_out / len(audio))).astype(np.float32)


def peak_dbfs(audio: np.ndarray) -> float:
    """Peak level in dBFS (-inf for digital silence)."""
    peak = float(np.max(np.abs(audio))) if len(audio) else 0.0
    return float("-inf") if peak == 0 else 20 * np.log10(peak)


def rms(audio: np.ndarray) -> float:
    """Root mean square level."""
    return float(np.sqrt(np.mean(np.square(audio, dtype=np.float64))))


def speak(text: str, espeak: str) -> np.ndarray:
    """Synthesises British English speech at 16 kHz with eSpeak NG."""
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "speech.wav"
        cmd = [espeak, "-v", "en-gb", "-s", "150", "-w", str(wav), text]
        data_path = os.environ.get("ESPEAK_DATA")
        if data_path:
            cmd[1:1] = ["--path", data_path]
        subprocess.run(cmd, check=True, capture_output=True)
        audio, rate = read_wav(wav)
    audio = resample(audio, rate, SAMPLE_RATE)
    return audio / max(1e-9, float(np.max(np.abs(audio)))) * 0.7  # peak ~ -3 dBFS


def silence(seconds: float, rng: np.random.Generator) -> np.ndarray:
    """Near-silence: +-1 LSB dither, like a real quiet room after a gain stage."""
    n = int(seconds * SAMPLE_RATE)
    return (rng.integers(-1, 2, n) / 32768.0).astype(np.float32)


def noise(seconds: float, level_dbfs: float, rng: np.random.Generator) -> np.ndarray:
    """White noise with the given RMS level."""
    n = int(seconds * SAMPLE_RATE)
    white = rng.standard_normal(n).astype(np.float32)
    return white / rms(white) * (10 ** (level_dbfs / 20))


def speech_regions(audio: np.ndarray, threshold_dbfs: float = -35.0) -> list[list[int]]:
    """Rough speech regions in ms from 20 ms frame energy (for documentation only)."""
    frame = SAMPLE_RATE // 50
    regions: list[list[int]] = []
    start = None
    for i in range(0, len(audio) - frame + 1, frame):
        level = rms(audio[i : i + frame])
        loud = level > 0 and 20 * np.log10(level) > threshold_dbfs
        ms = i * 1000 // SAMPLE_RATE
        if loud and start is None:
            start = ms
        elif not loud and start is not None:
            regions.append([start, ms])
            start = None
    if start is not None:
        regions.append([start, len(audio) * 1000 // SAMPLE_RATE])
    merged: list[list[int]] = []
    for r in regions:  # merge gaps shorter than 300 ms (word gaps)
        if merged and r[0] - merged[-1][1] < 300:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    return merged


def build(espeak: str, out: Path = OUT) -> dict[str, dict]:
    """Builds every fixture into [out] and returns the manifest."""
    rng = np.random.default_rng(20261018)
    out.mkdir(parents=True, exist_ok=True)
    lead, tail = silence(0.3, rng), silence(0.5, rng)
    clean = np.concatenate([lead, speak(SENTENCE, espeak), tail])
    wrong = np.concatenate([lead, speak(MISPRONOUNCED, espeak), tail])
    quiet = clean * (10 ** (-40 / 20) / 0.7)  # peak -40 dBFS
    speech_rms = rms(clean[np.abs(clean) > 0.01])
    noisy = clean + noise(len(clean) / SAMPLE_RATE, 20 * np.log10(speech_rms) - 5, rng)
    clips = {
        "clean_read.wav": (clean, "ok", SENTENCE),
        "mispronounced_thursday.wav": (wrong, "ok", MISPRONOUNCED),
        "read_then_silence.wav": (
            np.concatenate([clean, silence(2.5, rng)]),
            "ok",
            SENTENCE + " Then 3 s of silence (silenceDetected after 2 s).",
        ),
        "quiet_read.wav": (quiet, "tooQuiet", SENTENCE + " Peak -40 dBFS."),
        "noisy_read.wav": (noisy, "tooNoisy", SENTENCE + " White noise, SNR ~5 dB."),
        "silence.wav": (silence(2.0, rng), "tooQuiet", "2 s of near-silence."),
        "noise.wav": (noise(2.0, -20, rng), "tooNoisy", "2 s of white noise, -20 dBFS RMS."),
    }
    manifest: dict[str, dict] = {}
    for name, (audio, quality, text) in clips.items():
        audio = np.clip(audio, -1.0, 1.0)
        write_wav(out / name, audio)
        manifest[name] = {
            "text": text,
            "durationMs": len(audio) * 1000 // SAMPLE_RATE,
            "sampleRate": SAMPLE_RATE,
            "peakDbfs": round(peak_dbfs(audio), 1),
            "expectedQuality": quality,
            "approxSpeechMs": speech_regions(audio) if quality == "ok" else [],
        }
    (out / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--espeak", default=os.environ.get("ESPEAK_NG", "espeak-ng"))
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args(argv)
    manifest = build(args.espeak, args.out)
    for name, meta in manifest.items():
        print(f"{name}: {meta['durationMs']} ms, peak {meta['peakDbfs']} dBFS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
