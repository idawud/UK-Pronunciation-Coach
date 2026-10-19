"""eSpeak NG fallback for words Britfone lacks (dev-side only, never shipped).

eSpeak NG is GPL-3.0 and is only ever called as an external binary from the build
script on a developer machine. Its output is converted to the app's SSBE spelling and
written to ``tools/content/lexicon_overrides.tsv`` with ``reviewed = no``; a human
checks (and corrects) each line. CI never runs eSpeak: it rebuilds from the committed
overrides file.
"""

from __future__ import annotations

import os
import subprocess
from collections.abc import Callable

from tools.content.lexicon import VOWELS

VOICE = "en-gb-x-rp"  # eSpeak's Received Pronunciation variant of en-gb

#: eSpeak symbol -> app symbol.
ESPEAK_MAP = {
    "ɐ": "ə",  # reduced vowel (stressed ɐ is handled in convert())
    "ᵻ": "ɪ",
    "iə": "ɪə",
    "ɛə": "eə",
    "ɾ": "t",
    "ɔ": "ɒ",
    "a": "æ",
    "g": "ɡ",
    "r": "ɹ",
    "əl": "ə l",
    "n̩": "ə n",
    "l̩": "ə l",
    "oː": "ɔː",
    "e": "ɛ",
    "ʔ": "t",
    "x": "k",
    "aɪə": "aɪ ə",
    "aʊə": "aʊ ə",
}

Runner = Callable[[str], str]


def run_espeak(word: str, binary: str | None = None) -> str:
    """Raw eSpeak IPA for [word], phonemes separated by ``_``."""
    exe = binary or os.environ.get("ESPEAK_NG", "espeak-ng")
    out = subprocess.run(
        [exe, "-v", VOICE, "-q", "--ipa", "--sep=_", word],
        check=True,
        capture_output=True,
        text=True,
    )
    return out.stdout


def convert(raw: str) -> str:
    """eSpeak ``"p_ɹ_ˈiː_j_ɐ"`` -> app spelling ``"p ɹ ˈiː j ə"``."""
    out: list[str] = []
    for chunk in raw.replace("‍", "").split():
        for tok in chunk.split("_"):
            tok = tok.strip()
            if not tok:
                continue
            mark = tok[0] if tok[0] in "ˈˌ" else ""
            base = tok[len(mark) :]
            if base == "ɐ" and mark:
                mapped = "ʌ"
            else:
                mapped = ESPEAK_MAP.get(base, base)
            parts = mapped.split()
            out.append(mark + parts[0])
            out.extend(parts[1:])
    if not out:
        raise ValueError(f"eSpeak gave no phonemes for {raw!r}")
    # happY: Britfone writes a final unstressed ɪ as i ("happy" h ˈæ p i).
    if out[-1] == "ɪ" and len(out) > 1:
        out[-1] = "i"
    if not any(t[0] in "ˈˌ" for t in out):
        # Single-syllable words: eSpeak may omit the mark; stress the first vowel.
        for i, t in enumerate(out):
            if t in VOWELS:
                out[i] = "ˈ" + t
                break
    return " ".join(out)


def transcribe(word: str, runner: Runner | None = None) -> str:
    """App-spelling IPA for [word] from eSpeak."""
    return convert((runner or run_espeak)(word))
