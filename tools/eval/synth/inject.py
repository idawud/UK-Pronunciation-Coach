"""Learner-error injection with labels known by construction.

Every error changes the PHONEMES a TTS voice reads for one word, so the word is
`wrong` by construction; every other word of the sentence is `right`. The catalogue
follows `lib/engine/scoring/data/tips_table.dart` and common errors of learners of
British English:

* substitutions: θ->t/f/s, ð->d/z/v, v->w, w->v, ʃ->s, z->s, ɪ->iː, iː->ɪ, æ->ɛ/ʌ,
  ʌ->ɒ/æ, ɑː->æ (BATH words only), ɒ->ɑː/ɔː, ɜː->ɛ/ɑː, ʊ->uː;
* `added_r`: a rhotic r after a vowel spelled with r (not before a vowel: that would
  be a linking r, which is correct SSBE);
* `dropped_final`: a word-final consonant left out before a vowel or a pause (before
  a consonant it could pass as normal elision);
* `h_dropped` / `h_added` on content words (weak function words drop h legitimately);
* `stress`: primary stress moved to another vowel of a multi-syllable word.

An error read gets 1-3 errors (about a quarter of its words); error types are drawn
uniformly first, then a word, so rare sounds (θ, ʊ) are not swamped by common ones.
"""

from __future__ import annotations

import hashlib
import random
from dataclasses import dataclass

from tools.eval.synth.phonemes import Phone, is_vowel, normalise

SUBSTITUTIONS: dict[str, tuple[str, ...]] = {
    "θ": ("t", "f", "s"),
    "ð": ("d", "z", "v"),
    "v": ("w",),
    "w": ("v",),
    "ʃ": ("s",),
    "z": ("s",),
    "ɪ": ("iː",),
    "iː": ("ɪ",),
    "æ": ("ɛ", "ʌ"),
    "ʌ": ("ɒ", "æ"),
    "ɑː": ("æ",),
    "ɒ": ("ɑː", "ɔː"),
    "ɜː": ("ɛ", "ɑː"),
    "ʊ": ("uː",),
}
BATH_NEXT = {"f", "θ", "s", "n", "m"}
R_VOWELS = {"ɑː", "ɔː", "ɜː", "ə", "ɪə", "eə", "ʊə"}
FUNCTION_WORDS = {
    "a", "an", "the", "and", "but", "or", "of", "to", "from", "for", "at", "as", "in",
    "on", "by", "with", "her", "him", "his", "he", "them", "us", "your", "you", "we",
    "she", "it", "its", "was", "were", "is", "are", "be", "been", "has", "have", "had",
    "can", "could", "would", "should", "will", "do", "does", "that", "than", "there",
    "some", "not", "into", "our", "me", "my", "they", "their", "this", "these", "those",
    "which", "who", "what", "so", "no", "i", "am", "if", "up", "out",
}  # fmt: skip
STRUCTURAL = ("added_r", "dropped_final", "h_dropped", "h_added", "stress")


@dataclass(frozen=True)
class Error:
    """One injected error: [kind] is the class (`θ->t`, `added_r`, ...), [phones] the
    word's new pronunciation and [detail] what changed."""

    kind: str
    phones: tuple[Phone, ...]
    detail: str


def stable_rng(*parts: str) -> random.Random:
    return random.Random(int(hashlib.sha256("|".join(parts).encode()).hexdigest()[:12], 16))


def word_errors(text: str, phones: list[Phone], next_phones: list[Phone] | None) -> list[Error]:
    """Every error the catalogue can apply to one word. [next_phones] is the next
    word's pronunciation, or None at the end of the sentence (a pause)."""
    ph = [(normalise(p), s) for p, s in phones]
    out: list[Error] = []
    lower = text.lower()
    function = lower in FUNCTION_WORDS
    next_vowel_or_pause = next_phones is None or is_vowel(next_phones[0][0])
    next_consonant_or_pause = next_phones is None or not is_vowel(next_phones[0][0])
    for i, (p, s) in enumerate(ph):
        for new in SUBSTITUTIONS.get(p, ()):
            if p == "ɑː" and (i + 1 >= len(ph) or ph[i + 1][0] not in BATH_NEXT or "ar" in lower):
                continue  # BATH only: "ask", "after", "dance", not "car", "father"
            stress = s if is_vowel(new) else 0
            new_ph = (*ph[:i], (new, stress), *ph[i + 1 :])
            out.append(Error(f"{p}->{new}", new_ph, f"{i}:{p}->{new}"))
    # added r after an r-spelled vowel, not before a vowel (linking r is correct)
    if "r" in lower:
        for i, (p, _) in enumerate(ph):
            last = i + 1 == len(ph)
            if p not in R_VOWELS:
                continue
            if (not last and (is_vowel(ph[i + 1][0]) or ph[i + 1][0] == "ɹ")) or (
                last and not next_consonant_or_pause
            ):
                continue
            if i > 0 and ph[i - 1][0] == "ɹ" and p == "ə":
                continue  # "-rə" (e.g. "camera"): the r is already there
            new_ph = (*ph[: i + 1], ("ɹ", 0), *ph[i + 1 :])
            out.append(Error("added_r", new_ph, f"{i}:+ɹ"))
            break
    if len(ph) >= 3 and not is_vowel(ph[-1][0]) and next_vowel_or_pause:
        out.append(Error("dropped_final", tuple(ph[:-1]), f"{len(ph) - 1}:-{ph[-1][0]}"))
    if not function and len(ph) >= 2:
        if ph[0][0] == "h":
            out.append(Error("h_dropped", tuple(ph[1:]), "0:-h"))
        elif is_vowel(ph[0][0]):
            out.append(Error("h_added", (("h", 0), *ph), "0:+h"))
    vowels = [i for i, (p, _) in enumerate(ph) if is_vowel(p)]
    primary = [i for i in vowels if ph[i][1] == 1]
    if len(vowels) >= 2 and primary:
        full = [i for i in vowels if i != primary[0] and ph[i][0] not in ("ə", "i", "u")]
        others = full or [i for i in vowels if i != primary[0]]
        j = others[0]
        new_ph = tuple(
            (p, 1 if k == j else 0 if k == primary[0] else s) for k, (p, s) in enumerate(ph)
        )
        out.append(Error("stress", new_ph, f"{primary[0]}->{j}"))
    return out


def error_count(n_words: int, rng: random.Random) -> int:
    """1-3 errors, about a quarter of the words."""
    return max(1, min(3, round(0.25 * n_words + rng.uniform(-0.5, 0.5))))


def inject(
    words: list[tuple[str, list[Phone]]], key: str, k: int | None = None
) -> dict[int, Error]:
    """Chooses errors for one error read: {word index: Error}. [words] is (text,
    phonemes) per scorable word; [key] seeds the choice (sentence + voice)."""
    rng = stable_rng("inject", key)
    cands: dict[str, list[tuple[int, Error]]] = {}
    for i, (text, ph) in enumerate(words):
        nxt = words[i + 1][1] if i + 1 < len(words) else None
        for e in word_errors(text, ph, nxt):
            cands.setdefault(e.kind, []).append((i, e))
    k = error_count(len(words), rng) if k is None else k
    chosen: dict[int, Error] = {}
    while len(chosen) < k:
        kinds = sorted(c for c, v in cands.items() if any(i not in chosen for i, _ in v))
        if not kinds:
            break
        kind = rng.choice(kinds)
        i, e = rng.choice([(i, e) for i, e in cands[kind] if i not in chosen])
        chosen[i] = e
    return chosen


def error_class(kind: str) -> str:
    """Coarse class for reports: consonant / vowel substitution or the structural kind."""
    if kind in STRUCTURAL:
        return kind
    src = kind.split("->")[0]
    return "vowel" if is_vowel(src) else "consonant"
