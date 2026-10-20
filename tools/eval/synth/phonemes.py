"""SSBE phonemes (Britfone spelling, as in assets/content/) -> TTS engine input.

Both engines are driven from PHONEMES, never text, so an injected error is exactly the
sound we wrote into the label:

* **Kokoro-82M** (British voices, misaki `lang_code='b'` symbol set): one character per
  token from the model's `tokenizer.json` vocab. Diphthongs and affricates are single
  letters (`A`=eɪ, `I`=aɪ, `Y`=ɔɪ, `W`=aʊ, `Q`=əʊ, `ʧ`, `ʤ`), TRAP is `a`, SQUARE is
  `ɛː`, length is `ː`, stress marks `ˈ` / `ˌ` go right before the stressed vowel.
* **Piper** (en_GB cori, trained on eSpeak NG voice `en` phonemes): one id per
  codepoint from the voice's `phoneme_id_map`, eSpeak `en` spelling (TRAP `a`, NEAR
  `iə`, SQUARE `eə`, `tʃ` / `dʒ` as two codepoints), stress before the vowel.

A phoneme is `(ipa, stress)` with stress 0 / 1 / 2. Words are joined with spaces and
the sentence's own punctuation, which both engines use for phrasing.
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence

Phone = tuple[str, int]

# Spelling variants -> one canonical SSBE symbol (Britfone raw vs C1's content bundle).
NORMALISE = {
    "ɐ": "ʌ",
    "ɛə": "eə",
    "ɛː": "eə",
    "g": "ɡ",
    "e": "ɛ",
    "r": "ɹ",
    "ʧ": "tʃ",
    "ʤ": "dʒ",
    "a": "æ",
}

VOWELS = {
    "ɪ", "ɛ", "æ", "ʌ", "ɒ", "ʊ", "ə", "i", "u", "iː", "ɑː", "ɔː", "uː", "ɜː",
    "eɪ", "aɪ", "ɔɪ", "əʊ", "aʊ", "ɪə", "eə", "ʊə",
}  # fmt: skip

CONSONANTS = {
    "p", "b", "t", "d", "k", "ɡ", "f", "v", "θ", "ð", "s", "z", "ʃ", "ʒ", "h", "x",
    "tʃ", "dʒ", "m", "n", "ŋ", "l", "ɹ", "j", "w",
}  # fmt: skip

KOKORO = {
    "eɪ": "A",
    "aɪ": "I",
    "ɔɪ": "Y",
    "aʊ": "W",
    "əʊ": "Q",
    "tʃ": "ʧ",
    "dʒ": "ʤ",
    "æ": "a",
    "eə": "ɛː",
    "x": "k",
}

ESPEAK = {
    "æ": "a",
    "ɪə": "iə",
    "x": "k",
}

STRESS_MARK = {1: "ˈ", 2: "ˌ"}
PUNCTUATION = ",.;:!?"


def normalise(ipa: str) -> str:
    return NORMALISE.get(ipa, ipa)


def is_vowel(ipa: str) -> bool:
    return normalise(ipa) in VOWELS


def to_symbols(phones: Iterable[Phone], table: dict[str, str]) -> str:
    """One word in an engine's symbols, stress mark before the stressed vowel."""
    out = []
    for ipa, stress in phones:
        p = normalise(ipa)
        if p not in VOWELS and p not in CONSONANTS:
            raise ValueError(f"unknown SSBE phoneme {ipa!r}")
        mark = STRESS_MARK.get(stress, "") if p in VOWELS else ""
        out.append(mark + table.get(p, p))
    return "".join(out)


def kokoro_word(phones: Iterable[Phone]) -> str:
    return to_symbols(phones, KOKORO)


def espeak_word(phones: Iterable[Phone]) -> str:
    return to_symbols(phones, ESPEAK)


def separators(text: str, offsets: Sequence[int], words: Sequence[str]) -> list[str]:
    """What goes after each word: the text's punctuation (`, `, `. `) or a space; the
    last word always ends with sentence-final punctuation (default `.`)."""
    out = []
    for i, (off, w) in enumerate(zip(offsets, words, strict=True)):
        end = off + len(w)
        nxt = offsets[i + 1] if i + 1 < len(offsets) else len(text)
        gap = "".join(c for c in text[end:nxt] if c in PUNCTUATION)
        if i + 1 == len(offsets):
            out.append(gap[:1] if gap else ".")
        else:
            out.append(f"{gap[:1]} " if gap else " ")
    return out


def render(words: Sequence[Sequence[Phone]], seps: Sequence[str], engine: str) -> str:
    """A sentence in [engine]'s symbols (`kokoro` or `espeak`)."""
    fn = kokoro_word if engine == "kokoro" else espeak_word
    return "".join(fn(w) + s for w, s in zip(words, seps, strict=True))


def check_vocab(s: str, vocab: Iterable[str]) -> None:
    """Raises when [s] has a character the engine has no id for."""
    vocab = set(vocab)
    missing = sorted({c for c in s if c not in vocab})
    if missing:
        raise ValueError(f"symbols not in the engine vocab: {missing} in {s!r}")
