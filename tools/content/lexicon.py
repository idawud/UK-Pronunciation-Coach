"""British pronunciation lookup for the content build (dev-side only).

Britfone (MIT, tools/content/britfone/) is the primary source. Its symbols are
normalised to the app's SSBE spelling (``ɐ`` -> ``ʌ`` for STRUT, ``g`` -> ``ɡ``,
``ɛə`` -> ``eə``); stress marks stay on the vowel token (``ˈ`` primary, ``ˌ``
secondary) until a pronunciation is turned into phoneme dicts.

The same rules are implemented in Dart by ``lib/data/content/britfone_lexicon.dart``
for ``ContentRepository.lookup``; ``test/data/content`` checks both agree on every
passage.
"""

from __future__ import annotations

import csv
import re
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
BRITFONE_CSV = HERE / "britfone" / "britfone.main.3.0.1.csv"
VARIANTS_TSV = HERE / "variants.tsv"

#: Word tokens: letters with optional apostrophe parts ("don't", "Sarah's").
#: Must match the Dart tokeniser in lib/data/content/tokenizer.dart.
WORD_RE = re.compile(r"[A-Za-z]+(?:['’][A-Za-z]+)*")

#: Britfone symbol -> app symbol.
SYMBOL_MAP = {"ɐ": "ʌ", "g": "ɡ", "ɛə": "eə"}

VOWELS = frozenset("ɪ ɛ æ ʌ ɒ ʊ ə i u iː ɑː ɔː uː ɜː eɪ aɪ ɔɪ əʊ aʊ ɪə eə ʊə".split())

#: Text after a word that ends a clause: a weak-form word there takes its strong form.
CLAUSE_END_RE = re.compile(r"^[^A-Za-z]*?[.,;:!?—–)\"”]")

#: Pre-vowel forms: before a word starting with a vowel sound.
PRE_VOWEL = {"the": "ð i", "to": "t ʊ"}

SIBILANTS = frozenset({"s", "z", "ʃ", "ʒ", "tʃ", "dʒ"})
VOICELESS = frozenset({"p", "t", "k", "f", "θ"})


def norm_key(word: str) -> str:
    """Lookup key: lower case, curly apostrophes straightened."""
    return word.replace("’", "'").lower()


def normalise_token(tok: str) -> str:
    """One Britfone token -> app spelling, stress mark kept in front."""
    mark = tok[0] if tok[0] in "ˈˌ" else ""
    base = tok[len(mark) :]
    return mark + SYMBOL_MAP.get(base, base)


def normalise_pron(pron: str) -> str:
    """A space-separated Britfone pronunciation -> app spelling."""
    return " ".join(normalise_token(t) for t in pron.split())


def strip_stress(tok: str) -> str:
    return tok.lstrip("ˈˌ")


def is_stressed(pron: str) -> bool:
    return any(t[0] in "ˈˌ" for t in pron.split())


def to_phonemes(pron: str) -> list[dict]:
    """``"k ˈæ t"`` -> ``[{"ipa": "k"}, {"ipa": "æ", "stress": 1}, {"ipa": "t"}]``.

    Stress 0 is omitted, matching the JSON written by the Dart models' defaults.
    """
    out = []
    for tok in pron.split():
        ph: dict = {"ipa": strip_stress(tok)}
        if tok.startswith("ˈ"):
            ph["stress"] = 1
        elif tok.startswith("ˌ"):
            ph["stress"] = 2
        out.append(ph)
    return out


def load_britfone(path: Path = BRITFONE_CSV) -> dict[str, list[str]]:
    """word (lower case) -> pronunciations in Britfone's order. Multi-word entries
    (``COSTA_RICA``) are skipped: the tokeniser never produces them."""
    lex: dict[str, list[str]] = {}
    with path.open(encoding="utf-8", newline="") as f:
        for row in csv.reader(f):
            if len(row) < 2:
                continue
            head, pron = row[0].strip(), ",".join(row[1:]).strip()
            word = re.sub(r"\(\d+\)$", "", head)
            if "_" in word or not pron:
                continue
            lex.setdefault(norm_key(word), []).append(normalise_pron(pron))
    return lex


def load_variants(path: Path = VARIANTS_TSV) -> dict[str, int]:
    """word -> 1-based Britfone variant to put first (see variants.tsv)."""
    prefs: dict[str, int] = {}
    if not path.exists():
        return prefs
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        word, num = line.split()
        prefs[norm_key(word)] = int(num)
    return prefs


def apply_variants(lex: dict[str, list[str]], prefs: dict[str, int]) -> dict[str, list[str]]:
    """Moves each preferred variant to the front."""
    out = dict(lex)
    for word, num in prefs.items():
        prons = lex.get(word)
        if not prons or not 1 <= num <= len(prons):
            raise ValueError(f"variants.tsv: {word} has no variant {num}")
        chosen = prons[num - 1]
        out[word] = [chosen] + [p for p in prons if p != chosen]
    return out


def add_s(pron: str) -> str:
    """Adds an -s / 's ending: /ɪz/ after sibilants, /s/ after voiceless sounds, else /z/."""
    last = strip_stress(pron.split()[-1])
    if last in SIBILANTS:
        return pron + " ɪ z"
    if last in VOICELESS:
        return pron + " s"
    return pron + " z"


def add_ed(pron: str) -> str:
    """Adds a regular past ending: /ɪd/ after t or d, /t/ after voiceless sounds, else /d/."""
    last = strip_stress(pron.split()[-1])
    if last in ("t", "d"):
        return pron + " ɪ d"
    if last in VOICELESS or last in ("s", "ʃ", "tʃ"):
        return pron + " t"
    return pron + " d"


def add_ing(pron: str) -> str:
    return pron + " ɪ ŋ"


def _s_bases(key: str) -> list[str]:
    if key.endswith("'s"):
        return [key[:-2]]
    if key.endswith("ies"):
        return [key[:-3] + "y"]
    if key.endswith("es"):
        return [key[:-1], key[:-2]]
    if key.endswith("s") and not key.endswith("ss"):
        return [key[:-1]]
    return []


def _ed_bases(key: str) -> list[str]:
    if key.endswith("ied"):
        return [key[:-3] + "y"]
    if not key.endswith("ed"):
        return []
    stem = key[:-2]
    out = [stem, key[:-1]]
    if len(stem) > 2 and stem[-1] == stem[-2]:
        out.append(stem[:-1])
    return out


def _ing_bases(key: str) -> list[str]:
    if not key.endswith("ing"):
        return []
    stem = key[:-3]
    out = [stem, stem + "e"]
    if len(stem) > 2 and stem[-1] == stem[-2]:
        out.append(stem[:-1])
    return out


#: Contractions with 're, where the vowels merge.
RE_FORMS = {"you're": "j ˈɔː", "we're": "w ˈɪə", "they're": "ð ˈeə"}

#: Clitic -> (after a vowel, after a consonant).
CLITICS = {"'m": ("m", "ə m"), "'ll": ("l", "ə l"), "'d": ("d", "ə d"), "'ve": ("v", "ə v")}


def _clitic_bases(key: str) -> list[str]:
    for clitic in CLITICS:
        if key.endswith(clitic):
            return [key[: -len(clitic)]]
    return []


def add_clitic_for(key: str) -> Callable[[str], str]:
    def add(pron: str) -> str:
        clitic = next(c for c in CLITICS if key.endswith(c))
        after_vowel, after_consonant = CLITICS[clitic]
        last = strip_stress(pron.split()[-1])
        return f"{pron} {after_vowel if last in VOWELS else after_consonant}"

    return add


#: (base finder, ending) for regular inflections, tried in order.
DERIVATIONS = ((_s_bases, add_s), (_ed_bases, add_ed), (_ing_bases, add_ing))


@dataclass
class Lexicon:
    """Britfone plus reviewed overrides, with the context rules for weak forms."""

    britfone: dict[str, list[str]]
    overrides: dict[str, str] = field(default_factory=dict)

    @classmethod
    def load(cls, overrides: dict[str, str] | None = None) -> Lexicon:
        return cls(apply_variants(load_britfone(), load_variants()), dict(overrides or {}))

    def source(self, word: str) -> str | None:
        """'britfone', 'derived', 'override' or None for an unknown word."""
        key = norm_key(word)
        if key in self.britfone:
            return "britfone"
        if self._derived(key):
            return "derived"
        if key in self.overrides:
            return "override"
        return None

    def _derived(self, key: str) -> str | None:
        """A contraction or regular inflection (-s, 's, -ed, -ing) of a Britfone word,
        or None."""
        if key in RE_FORMS:
            return RE_FORMS[key]
        for base in _clitic_bases(key):
            if base in self.britfone:
                return add_clitic_for(key)(self.britfone[base][0])
        for bases, ending in DERIVATIONS:
            for base in bases(key):
                if len(base) > 1 and base in self.britfone:
                    return ending(self.britfone[base][0])
        return None

    def base(self, word: str) -> list[str] | None:
        """All pronunciations of [word], preferred first, or None."""
        key = norm_key(word)
        if key in self.britfone:
            return self.britfone[key]
        derived = self._derived(key)
        if derived:
            return [derived]
        if key in self.overrides:
            return [self.overrides[key]]
        return None

    def in_context(self, word: str, after: str, next_word: str | None) -> str | None:
        """The pronunciation of [word] given the text [after] it and the next word.

        - a weak-form word (first variant unstressed, another stressed) takes its
          first stressed variant before clause punctuation or at the end of the text;
        - "the" / "to" take their pre-vowel form before a vowel sound.
        """
        prons = self.base(word)
        if prons is None:
            return None
        first = prons[0]
        key = norm_key(word)
        clause_end = next_word is None or CLAUSE_END_RE.match(after) is not None
        if clause_end and not is_stressed(first):
            strong = next((p for p in prons if is_stressed(p)), None)
            if strong:
                return strong
        if key in PRE_VOWEL and not clause_end and next_word is not None:
            nxt = self.base(next_word)
            if nxt and strip_stress(nxt[0].split()[0]) in VOWELS:
                return PRE_VOWEL[key]
        return first


@dataclass
class Token:
    text: str
    offset: int


def tokenise(text: str) -> list[Token]:
    """Words of [text] with their character offsets."""
    return [Token(m.group(0), m.start()) for m in WORD_RE.finditer(text)]


def transcribe(text: str, lex: Lexicon) -> list[tuple[Token, str | None]]:
    """Each token of [text] with its pronunciation in context (None if unknown)."""
    toks = tokenise(text)
    out = []
    for i, tok in enumerate(toks):
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        end = tok.offset + len(tok.text)
        after = text[end : nxt.offset] if nxt else text[end:]
        out.append((tok, lex.in_context(tok.text, after, nxt.text if nxt else None)))
    return out
