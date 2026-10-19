"""Dev-side British lexicon: text -> expected SSBE phonemes for the eval harness.

Primary source: **Britfone 3.0.1** (MIT, Jose Llarena; RP / Standard Southern British),
fetched at a pinned commit and checked against SHA-256 (`fetch_britfone`). Words Britfone
lacks fall back to **eSpeak NG `en-gb-x-rp`**, run as a binary (GPL-3.0: dev-side only,
never shipped). Every fallback is flagged (`source == "espeak"`) so the report can
exclude or inspect them. BEEP is never used.

Phonemes come out in Britfone's symbol set (the one C1 ships), e.g. `ɛ` for DRESS, `ɐ`
for STRUT, `ɛə` for SQUARE, `ɹ`, `g`, with stress 1 / 2 on vowels.
"""

from __future__ import annotations

import hashlib
import re
import shutil
import subprocess
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

BRITFONE_COMMIT = "1062be14adc96c358f2087ac5449d72130c7a6f4"
BRITFONE_URL = f"https://raw.githubusercontent.com/JoseLlarena/Britfone/{BRITFONE_COMMIT}/"
BRITFONE_FILES = {
    "britfone.main.3.0.1.csv": "59f197e98520856d1cc88e380beb54e4314d8712efc4d588b6778819c502d920",
    "LICENSE.txt": "ec93e71cd6fcdced20da7a0137bdfc1ff5fd8ea420d1fab332f95804668f9c49",
}
DEFAULT_DIR = Path(__file__).parent / "data" / "britfone"

VOWELS = {
    "ɪ", "ɛ", "æ", "ɐ", "ɒ", "ʊ", "ə", "i", "u", "iː", "ɑː", "ɔː", "uː", "ɜː",
    "eɪ", "aɪ", "ɔɪ", "əʊ", "aʊ", "ɪə", "ɛə", "ʊə",
}  # fmt: skip

# eSpeak en-gb-x-rp symbol -> Britfone symbol(s).
ESPEAK_TO_BRITFONE = {
    "e": ["ɛ"],
    "eə": ["ɛə"],
    "ʌ": ["ɐ"],
    "ɡ": ["g"],
    "r": ["ɹ"],
    "iə": ["ɪə"],
    "əl": ["ə", "l"],
    "aɪə": ["aɪ", "ə"],
    "aʊə": ["aʊ", "ə"],
    "ɾ": ["t"],
    "ɔ": ["ɒ"],
    "a": ["æ"],
    "ɑ": ["ɑː"],
    "ɚ": ["ə"],
    "o": ["əʊ"],
    "oʊ": ["əʊ"],
    "ᵻ": ["ɪ"],
    "ɬ": ["l"],
    "n̩": ["ə", "n"],
}

WORD_RE = re.compile(r"[A-Za-z0-9]+(?:['’][A-Za-z]+)*")


@dataclass(frozen=True)
class Phoneme:
    ipa: str
    stress: int = 0

    def to_json(self) -> dict:
        return {"ipa": self.ipa, "stress": self.stress}


@dataclass
class Pron:
    phonemes: list[Phoneme]
    source: str  # "britfone", "britfone+s" (derived possessive / plural) or "espeak"


@dataclass
class Word:
    text: str
    index: int
    offset: int
    pron: Pron | None = None

    @property
    def scorable(self) -> bool:
        return self.pron is not None and bool(self.pron.phonemes)


@dataclass
class Lexicon:
    entries: dict[str, list[Phoneme]]
    espeak: str | None = None
    runner: object = subprocess.run
    _cache: dict[str, Pron | None] = field(default_factory=dict)

    @classmethod
    def load(cls, path: Path, espeak: str | None = None) -> Lexicon:
        return cls(parse_britfone(path.read_text(encoding="utf-8")), espeak)

    def lookup(self, word: str) -> Pron | None:
        key = word.upper().replace("’", "'")
        if key not in self._cache:
            self._cache[key] = self._lookup(key)
        return self._cache[key]

    def _lookup(self, key: str) -> Pron | None:
        if key in self.entries:
            return Pron(list(self.entries[key]), "britfone")
        if key.endswith("ES") and key[:-2] in self.entries:
            stem = self.entries[key[:-2]]
            if stem and stem[-1].ipa in SIBILANT:
                return Pron(add_s(stem), "britfone+s")
        for suffix in ("'S", "S'", "S"):
            stem = key[: -len(suffix)]
            if key.endswith(suffix) and stem in self.entries:
                if suffix == "S" and len(stem) < 3:
                    continue
                return Pron(add_s(self.entries[stem]), "britfone+s")
        if self.espeak:
            ph = espeak_phonemes(key.lower(), self.espeak, self.runner)
            if ph:
                return Pron(ph, "espeak")
        return None


def parse_britfone(text: str) -> dict[str, list[Phoneme]]:
    """Britfone main CSV -> {WORD: phonemes}; the first variant `(1)` wins."""
    out: dict[str, list[Phoneme]] = {}
    for line in text.splitlines():
        if "," not in line:
            continue
        word, pron = line.split(",", 1)
        word = re.sub(r"\(\d+\)$", "", word.strip())
        if word in out:
            continue
        out[word] = [parse_phoneme(p) for p in pron.split()]
    return out


def parse_phoneme(token: str) -> Phoneme:
    stress = 1 if token.startswith("ˈ") else 2 if token.startswith("ˌ") else 0
    return Phoneme(token.lstrip("ˈˌ"), stress)


VOICELESS = {"p", "t", "k", "f", "θ"}
SIBILANT = {"s", "z", "ʃ", "ʒ", "tʃ", "dʒ"}


def add_s(phonemes: list[Phoneme]) -> list[Phoneme]:
    """Plural / possessive -s after [phonemes]."""
    last = phonemes[-1].ipa if phonemes else ""
    if last in SIBILANT:
        return [*phonemes, Phoneme("ɪ"), Phoneme("z")]
    return [*phonemes, Phoneme("s" if last in VOICELESS else "z")]


def espeak_phonemes(word: str, binary: str, runner=subprocess.run) -> list[Phoneme]:
    """eSpeak NG en-gb-x-rp phonemes of [word] in Britfone symbols (dev-side only)."""
    out = runner(
        [binary, "-q", "--ipa", "--sep=_", "-v", "en-gb-x-rp", word],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return convert_espeak(out)


def convert_espeak(ipa: str) -> list[Phoneme]:
    result: list[Phoneme] = []
    for token in re.split(r"[_\s]+", ipa.strip()):
        if not token:
            continue
        p = parse_phoneme(token)
        for i, sym in enumerate(ESPEAK_TO_BRITFONE.get(p.ipa, [p.ipa])):
            stress = p.stress if i == 0 and sym in VOWELS else 0
            result.append(Phoneme(sym, stress))
    return result


def find_espeak() -> str | None:
    """eSpeak NG binary from $ESPEAK_NG or PATH (None when absent)."""
    import os

    return os.environ.get("ESPEAK_NG") or shutil.which("espeak-ng")


def tokenize(text: str) -> list[Word]:
    return [Word(m.group(), i, m.start()) for i, m in enumerate(WORD_RE.finditer(text))]


def passage_json(pid: str, text: str, lexicon: Lexicon, title: str | None = None) -> dict:
    """A `Passage` JSON (lib/core/models/passage.dart) for [text]."""
    words = tokenize(text)
    for w in words:
        w.pron = lexicon.lookup(w.text)
    return words_to_passage(pid, text, words, title)


def words_to_passage(pid: str, text: str, words: list[Word], title: str | None = None) -> dict:
    return {
        "id": pid,
        "level": 1,
        "title": title or pid,
        "text": text,
        "words": [
            {
                "text": w.text,
                "index": w.index,
                "phonemes": [p.to_json() for p in w.pron.phonemes] if w.scorable else [],
                "scorable": w.scorable,
                "offset": w.offset,
            }
            for w in words
        ],
    }


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch_britfone(dest: Path = DEFAULT_DIR, opener=None) -> Path:
    """Downloads Britfone at the pinned commit (if needed); returns the main CSV path."""
    opener = opener or urllib.request.urlopen
    dest.mkdir(parents=True, exist_ok=True)
    for name, digest in BRITFONE_FILES.items():
        path = dest / name
        if not path.exists() or sha256(path) != digest:
            with opener(BRITFONE_URL + name) as r:
                path.write_bytes(r.read())
            if sha256(path) != digest:
                path.unlink()
                raise ValueError(f"{name}: SHA-256 mismatch")
    return dest / "britfone.main.3.0.1.csv"
