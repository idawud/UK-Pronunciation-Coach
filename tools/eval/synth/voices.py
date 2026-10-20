"""TTS voices for the synthetic set, their pinned files, and the two ONNX engines.

Licences were checked at the sources on 2026-10-20 (details in tools/eval/SOURCES.md):

* Kokoro-82M v1.0 (hexgrad), Apache-2.0 weights; trained only on permissive /
  public-domain / consented synthetic audio. ONNX export and voice packs from
  `onnx-community/Kokoro-82M-v1.0-ONNX` (Apache-2.0, base model hexgrad/Kokoro-82M).
* Piper `en_GB-cori-medium` / `-high` (rhasspy/piper-voices, MIT), trained from scratch by
  Bryce Beattie on public-domain LibriVox recordings.

Only the ONNX models are used (via onnxruntime, MIT). We do NOT use the `kokoro` /
`misaki` text front-ends or the Piper runtime (piper1-gpl): phonemes come from
`phonemes.py`. Nothing here ships in the app; the files live in the git-ignored
`tools/eval/data/voices/`.
"""

from __future__ import annotations

import hashlib
import json
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import numpy as np

DEFAULT_DIR = Path(__file__).resolve().parents[1] / "data" / "voices"

KOKORO_REPO = (
    "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/"
    "1939ad2a8e416c0acfeecc08a694d14ef25f2231/"
)
PIPER_REPO = (
    "https://huggingface.co/rhasspy/piper-voices/resolve/"
    "c10ece1aade47bb51c153c893d14e5bf8e5b7117/en/en_GB/cori/"
)

# local path -> (url, sha256)
FILES: dict[str, tuple[str, str]] = {
    "kokoro/model.onnx": (
        KOKORO_REPO + "onnx/model.onnx",
        "8fbea51ea711f2af382e88c833d9e288c6dc82ce5e98421ea61c058ce21a34cb",
    ),
    "kokoro/tokenizer.json": (
        KOKORO_REPO + "tokenizer.json",
        "77a02c8e164413299b4b4c403b14f8e0e1c1b727db4d46a09d6327b861060a34",
    ),
    "kokoro/voices/bf_alice.bin": (
        KOKORO_REPO + "voices/bf_alice.bin",
        "08afa6ba24da61ea5e8efa139e5aadc938d83f0a6da5a900adaf763ac1da5573",
    ),
    "kokoro/voices/bf_emma.bin": (
        KOKORO_REPO + "voices/bf_emma.bin",
        "669fe0647f9dd04fcab92f1439a40eeb4c8b4ab1f82e4996fe3d918ce4a63b73",
    ),
    "kokoro/voices/bf_isabella.bin": (
        KOKORO_REPO + "voices/bf_isabella.bin",
        "3754352c4aaa46d17f27654ab7518d65b62ad6163a0f55a5f4330c2da2c4e94f",
    ),
    "kokoro/voices/bf_lily.bin": (
        KOKORO_REPO + "voices/bf_lily.bin",
        "5e0ee32ebe64a467124976b14e69590746f1c4ce41a12b587a50c862edfea335",
    ),
    "kokoro/voices/bm_daniel.bin": (
        KOKORO_REPO + "voices/bm_daniel.bin",
        "6b3194bbceffb746733cbc22c8f593dd44e401a71d53895a2dca891bc595a1e8",
    ),
    "kokoro/voices/bm_fable.bin": (
        KOKORO_REPO + "voices/bm_fable.bin",
        "f889083196807b4adb15e9204252165f503b8d33d3982e681c52443c49d798f1",
    ),
    "kokoro/voices/bm_george.bin": (
        KOKORO_REPO + "voices/bm_george.bin",
        "c4b235a4c1f2cd3b939fed08b899ce9385638b763f7b73a59616c4fc9bd6c9bc",
    ),
    "kokoro/voices/bm_lewis.bin": (
        KOKORO_REPO + "voices/bm_lewis.bin",
        "b8f671cef828c30e66fdf0b0756a76bba58f6bb3398cbbf27058642acbcedb97",
    ),
    "piper/en_GB-cori-medium.onnx": (
        PIPER_REPO + "medium/en_GB-cori-medium.onnx",
        "1899f98e5fb8310154f3c2973f4b8a929ba7245e722b3d3a85680b833d95f10d",
    ),
    "piper/en_GB-cori-medium.onnx.json": (
        PIPER_REPO + "medium/en_GB-cori-medium.onnx.json",
        "e262c16d7f192f69d4edd6b4ef8a5915379e67495fcc402f1ab15eeb33da3d36",
    ),
    "piper/en_GB-cori-high.onnx": (
        PIPER_REPO + "high/en_GB-cori-high.onnx",
        "470b4dd634c98f8a4850d7626ffc3dfc90774628eeef6605a6dd8f88f30a5903",
    ),
    "piper/en_GB-cori-high.onnx.json": (
        PIPER_REPO + "high/en_GB-cori-high.onnx.json",
        "9e7fb5b5671612c22f3c81cbe46c1ae87b031a4632bcb509e499dad6f1e2adec",
    ),
}


@dataclass(frozen=True)
class Voice:
    name: str
    engine: str  # "kokoro" or "piper"
    sex: str
    split: str  # "tune" or "heldout"
    speaker: str  # voices of one person share a speaker (cori medium / high)
    files: tuple[str, ...]


def _kokoro(name: str, sex: str, split: str) -> Voice:
    return Voice(
        name,
        "kokoro",
        sex,
        split,
        name,
        ("kokoro/model.onnx", "kokoro/tokenizer.json", f"kokoro/voices/{name}.bin"),
    )


def _piper(quality: str) -> Voice:
    base = f"piper/en_GB-cori-{quality}.onnx"
    return Voice(f"cori_{quality}", "piper", "F", "heldout", "cori", (base, base + ".json"))


# Held out of every tuning step: bm_george (M), bf_isabella (F) and cori (F, a different
# engine and a real reader's voice), both qualities, since they are one speaker.
VOICES: dict[str, Voice] = {
    v.name: v
    for v in (
        _kokoro("bf_alice", "F", "tune"),
        _kokoro("bf_emma", "F", "tune"),
        _kokoro("bf_isabella", "F", "heldout"),
        _kokoro("bf_lily", "F", "tune"),
        _kokoro("bm_daniel", "M", "tune"),
        _kokoro("bm_fable", "M", "tune"),
        _kokoro("bm_george", "M", "heldout"),
        _kokoro("bm_lewis", "M", "tune"),
        _piper("medium"),
        _piper("high"),
    )
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def available(voice: Voice, root: Path = DEFAULT_DIR) -> bool:
    return all((root / f).exists() for f in voice.files)


def fetch(names: list[str], root: Path = DEFAULT_DIR, opener=None) -> list[str]:
    """Downloads (if missing) and SHA-256-checks the files of [names]; returns paths."""
    opener = opener or urllib.request.urlopen
    paths = sorted({f for n in names for f in VOICES[n].files})
    for rel in paths:
        url, digest = FILES[rel]
        path = root / rel
        if not path.exists() or (digest and sha256(path) != digest):
            path.parent.mkdir(parents=True, exist_ok=True)
            tmp = path.with_suffix(path.suffix + ".part")
            with opener(url) as r, open(tmp, "wb") as f:
                while chunk := r.read(1 << 20):
                    f.write(chunk)
            tmp.replace(path)
        if digest and sha256(path) != digest:
            path.unlink()
            raise ValueError(f"{rel}: SHA-256 mismatch")
    return paths


def _session(path: Path, threads: int):  # pragma: no cover - needs onnxruntime + model
    import onnxruntime as ort

    so = ort.SessionOptions()
    so.intra_op_num_threads = threads
    so.inter_op_num_threads = 1
    return ort.InferenceSession(str(path), so, providers=["CPUExecutionProvider"])


class KokoroEngine:
    """Kokoro-82M ONNX: phoneme string (misaki GB symbols) + voice style -> 24 kHz."""

    SAMPLE_RATE = 24000
    MAX_TOKENS = 510

    def __init__(self, root: Path = DEFAULT_DIR, threads: int = 1, session=None):
        self.root = root
        tok = json.loads((root / "kokoro" / "tokenizer.json").read_text(encoding="utf-8"))
        self.vocab: dict[str, int] = tok["model"]["vocab"]
        self.session = session or _session(root / "kokoro" / "model.onnx", threads)
        self._styles: dict[str, np.ndarray] = {}

    def style(self, voice: str) -> np.ndarray:
        if voice not in self._styles:
            raw = np.fromfile(self.root / "kokoro" / "voices" / f"{voice}.bin", np.float32)
            self._styles[voice] = raw.reshape(-1, 1, 256)
        return self._styles[voice]

    def ids(self, phonemes: str) -> list[int]:
        missing = sorted({c for c in phonemes if c not in self.vocab})
        if missing:
            raise ValueError(f"not in the Kokoro vocab: {missing}")
        ids = [self.vocab[c] for c in phonemes]
        if len(ids) > self.MAX_TOKENS:
            raise ValueError(f"too long for Kokoro: {len(ids)} tokens")
        return ids

    def synth(self, phonemes: str, voice: str, speed: float = 1.0) -> tuple[np.ndarray, int]:
        ids = self.ids(phonemes)
        styles = self.style(voice)
        ref = styles[min(len(ids), len(styles) - 1)]
        audio = self.session.run(
            None,
            {
                "input_ids": np.array([[0, *ids, 0]], dtype=np.int64),
                "style": ref.astype(np.float32),
                "speed": np.array([speed], dtype=np.float32),
            },
        )[0]
        return np.asarray(audio, dtype=np.float32).reshape(-1), self.SAMPLE_RATE


class PiperEngine:
    """Piper VITS ONNX: eSpeak-style phoneme string -> ids (with pads, as Piper does)."""

    def __init__(self, model: Path, threads: int = 1, session=None):
        cfg = json.loads(Path(str(model) + ".json").read_text(encoding="utf-8"))
        self.id_map: dict[str, list[int]] = cfg["phoneme_id_map"]
        self.sample_rate = int(cfg["audio"]["sample_rate"])
        inf = cfg.get("inference", {})
        self.noise_scale = float(inf.get("noise_scale", 0.667))
        self.noise_w = float(inf.get("noise_w", 0.8))
        self.session = session or _session(model, threads)

    def ids(self, phonemes: str) -> list[int]:
        missing = sorted({c for c in phonemes if c not in self.id_map})
        if missing:
            raise ValueError(f"not in the Piper phoneme map: {missing}")
        pad = self.id_map["_"]
        out = [*self.id_map["^"], *pad]
        for c in phonemes:
            out += [*self.id_map[c], *pad]
        return [*out, *self.id_map["$"]]

    def synth(self, phonemes: str, voice: str = "", speed: float = 1.0) -> tuple[np.ndarray, int]:
        ids = self.ids(phonemes)
        audio = self.session.run(
            None,
            {
                "input": np.array([ids], dtype=np.int64),
                "input_lengths": np.array([len(ids)], dtype=np.int64),
                "scales": np.array([self.noise_scale, 1.0 / speed, self.noise_w], np.float32),
            },
        )[0]
        return np.asarray(audio, dtype=np.float32).reshape(-1), self.sample_rate
