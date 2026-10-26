"""Adds `WordSpec.alternatives` to eval passages, the way the app does.

The app scores each word against its best-matching accepted pronunciation: C1's
Britfone variants, weak forms, pre-vowel forms ("the", "to"), `extra_variants.tsv` and
the "-day" / "ex-" rules (`tools.content.build.alternatives`, shipped as
`assets/content/alternatives.v1.json`). Without them the harness measures a stricter
engine than the one users get (I1 measured native false red 3.6% -> 1.7%).

A word gets every accepted form except the one it already uses. Words listed in
`exclude` (probe targets, whose expected form is deliberately wrong) get none.
"""

from __future__ import annotations

from collections.abc import Iterable

from tools.content.build import alternatives as c1_alternatives
from tools.content.build import load_extra_variants
from tools.content.lexicon import Lexicon, norm_key, strip_stress, to_phonemes


def plain(phonemes: Iterable[dict | str]) -> str:
    """Phoneme sequence without stress, e.g. "ð ə"."""
    return " ".join(
        strip_stress(p["ipa"] if isinstance(p, dict) else p) for p in phonemes
    )


class Alternatives:
    """word -> accepted pronunciations (C1's rules), loaded once."""

    def __init__(self, table: dict[str, list[str]]) -> None:
        self.table = table

    @classmethod
    def for_words(cls, words: Iterable[str]) -> Alternatives:
        keys = {norm_key(w) for w in words}
        return cls(c1_alternatives(keys, Lexicon.load(), load_extra_variants()))

    def forms(self, word: dict) -> list[list[dict]]:
        """Accepted forms of a passage word other than its own phonemes."""
        if not word.get("scorable"):
            return []
        seen = {plain(word["phonemes"])}
        out = []
        for pron in self.table.get(norm_key(word["text"]), []):
            key = plain(pron.split())
            if key not in seen:
                seen.add(key)
                out.append(to_phonemes(pron))
        return out

    def accepts(self, text: str, phonemes: Iterable[dict | str]) -> bool:
        """True when [phonemes] is one of the word's accepted forms."""
        key = plain(phonemes)
        return any(plain(p.split()) == key for p in self.table.get(norm_key(text), []))


def add_alternatives(
    passages: list[dict],
    exclude: dict[str, int] | None = None,
    table: Alternatives | None = None,
) -> int:
    """Fills `alternatives` on every word of [passages] in place; returns how many
    words got at least one. [exclude] maps passage id -> word index to leave alone."""
    exclude = exclude or {}
    table = table or Alternatives.for_words(
        w["text"] for p in passages for w in p["words"] if w.get("scorable")
    )
    added = 0
    for p in passages:
        for w in p["words"]:
            w["alternatives"] = (
                [] if exclude.get(p["id"]) == w["index"] else table.forms(w)
            )
            added += bool(w["alternatives"])
    return added
