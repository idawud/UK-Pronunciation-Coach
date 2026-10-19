"""Builds the passage bundle, minimal pairs and runtime dictionary (dev-side only).

Inputs (all committed):
  tools/content/passages/level1.txt .. level6.txt, placement.txt   passage sources
  tools/content/minimal_pairs.txt                                   pairs by contrast
  tools/content/britfone/britfone.main.3.0.1.csv                    Britfone (MIT)
  tools/content/variants.tsv                                        preferred variants
  tools/content/lexicon_overrides.tsv                               words Britfone lacks

Outputs:
  assets/content/passages.v1.json      Passage model ({"version", "passages", "placement"})
  assets/content/minimal_pairs.json    MinimalPair model ({"version", "pairs"})
  assets/content/britfone.v1.tsv       runtime table for ContentRepository.lookup
  assets/content/SOURCES.md            source of every passage
  tools/content/review.md              words for human review, coverage stats

    python -m tools.content.build                 # rebuild from committed inputs
    python -m tools.content.build --check         # CI: fail if outputs differ
    ESPEAK_NG=/path/espeak-ng python -m tools.content.build --espeak
        # also transcribe words Britfone lacks with eSpeak NG and append them to
        # lexicon_overrides.tsv (reviewed = no). Never used in CI.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

from tools.content import espeak
from tools.content.lexicon import (
    PRE_VOWEL,
    Lexicon,
    is_stressed,
    norm_key,
    strip_stress,
    to_phonemes,
    transcribe,
)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SOURCES_DIR = HERE / "passages"
PAIRS_SRC = HERE / "minimal_pairs.txt"
OVERRIDES = HERE / "lexicon_overrides.tsv"
BRITFONE_LICENSE = HERE / "britfone" / "LICENSE.txt"
EXTRA_VARIANTS = HERE / "extra_variants.tsv"
ASSETS = Path("assets/content")
BUNDLE_VERSION = 1

#: Level -> (min words, max words, min sentences, max sentences).
LENGTHS = {
    1: (8, 12, 1, 1),
    2: (25, 35, 2, 3),
    3: (50, 70, 2, 8),
    4: (85, 115, 3, 12),
    5: (135, 165, 5, 16),
    6: (180, 220, 6, 22),
}

#: Feature tags added to every passage of a level (its sound focus in docs/SPEC.md).
LEVEL_FEATURES = {
    1: ["short-vowels", "clear-consonants"],
    2: ["word-endings"],
    3: ["long-vowels", "non-rhotic"],
    4: ["word-stress", "weak-forms"],
    5: ["linking", "rhythm", "sentence-stress"],
    6: ["intonation", "connected-speech"],
}
FEATURES = {f for fs in LEVEL_FEATURES.values() for f in fs}

#: Phonemes worth tagging (the learner-hard set; ə, i and common consonants excluded).
TARGETS = frozenset(
    "ɪ ɛ æ ʌ ɒ ʊ iː ɑː ɔː uː ɜː eɪ aɪ ɔɪ əʊ aʊ ɪə eə ʊə θ ð v w ɹ l ŋ ʒ ʃ tʃ dʒ h z".split()
)
MAX_TAGS = 6
SHORT_VOWELS = frozenset("ɪ ɛ æ ʌ ɒ ʊ".split())
LONG_VOWELS = frozenset("iː ɑː ɔː uː ɜː".split())
#: Function words ignored by the near-duplicate check.
STOPWORDS = frozenset(
    "a an and the to of in on at for with is are was were be been it its i you he she "
    "we they me him her us them my your his our their this that these those but or so "
    "as by from not no do did does have has had will would can could should there here "
    "what when where who which how all just very".split()
)
NEAR_DUPLICATE = 0.5
SENTENCE_END = re.compile(r"[.!?]+[\"”’')]*(?:\s|$)")


@dataclass
class Source:
    id: str
    level: int
    title: str
    text: str
    focus: list[str] = field(default_factory=list)
    source: str = "Original writing for this app (in-house, 2026)"
    file: str = ""


class BuildError(Exception):
    """Invalid input; the message lists every problem."""


def level_of(pid: str) -> int:
    m = re.fullmatch(r"(?:l(\d)-\d{3}|placement-l(\d))", pid)
    if not m:
        raise BuildError(f"bad passage id {pid!r} (want l<level>-NNN or placement-l<level>)")
    return int(m.group(1) or m.group(2))


def parse_sources(text: str, file: str = "") -> list[Source]:
    """Parses a passage source file.

    Each passage starts with ``=== <id> | <title>``, then optional ``focus:`` and
    ``source:`` lines, then the text. Lines of one paragraph are joined with spaces;
    a blank line starts a new paragraph (``\\n\\n`` in the text). Lines starting with
    ``#`` before the first passage are comments.
    """
    out: list[Source] = []
    cur: Source | None = None
    paras: list[list[str]] = []

    def finish() -> None:
        if cur is not None:
            cur.text = "\n\n".join(" ".join(p) for p in paras if p)
            out.append(cur)

    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("==="):
            finish()
            head = line[3:].split("|", 1)
            if len(head) != 2:
                raise BuildError(f"{file}: bad header {line!r}")
            pid, title = head[0].strip(), head[1].strip()
            cur = Source(pid, level_of(pid), title, "", file=file)
            paras = [[]]
            continue
        if cur is None:
            if line and not line.startswith("#"):
                raise BuildError(f"{file}: text before the first passage: {line!r}")
            continue
        if not any(paras) and ":" in line and line.split(":", 1)[0] in ("focus", "source"):
            key, value = (s.strip() for s in line.split(":", 1))
            if key == "focus":
                cur.focus = value.split()
            else:
                cur.source = value
            continue
        if line:
            paras[-1].append(line)
        elif paras[-1]:
            paras.append([])
    finish()
    return out


def load_overrides(path: Path = OVERRIDES) -> dict[str, dict]:
    """word -> {"ipa", "source", "reviewed"} from the tab-separated overrides file."""
    out: dict[str, dict] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.split("\t")
        if len(cols) != 4:
            raise BuildError(f"lexicon_overrides.tsv: need 4 tab-separated columns: {line!r}")
        word, ipa, source, reviewed = (c.strip() for c in cols)
        out[norm_key(word)] = {"ipa": ipa, "source": source, "reviewed": reviewed}
    return out


def write_overrides(entries: dict[str, dict], path: Path = OVERRIDES) -> None:
    lines = [
        "# Words Britfone lacks. Columns: word, IPA (app spelling, stress on the vowel),",
        "# source, reviewed (yes/no). eSpeak NG lines are machine output, flagged for",
        "# human review in tools/content/review.md; correct the IPA and set reviewed=yes.",
        "# word\tipa\tsource\treviewed",
    ]
    for word in sorted(entries):
        e = entries[word]
        lines.append(f"{word}\t{e['ipa']}\t{e['source']}\t{e['reviewed']}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def sentence_count(text: str) -> int:
    return max(1, len(SENTENCE_END.findall(text.strip())))


def non_rhotic_words(words: list[dict]) -> list[str]:
    """Words spelled with r after a vowel letter (not before one) and said without /ɹ/."""
    out = []
    for w in words:
        lw = w["text"].lower()
        if re.search(r"[aeiouy]r(?![aeiouy])", lw) and not any(
            p["ipa"] == "ɹ" for p in w["phonemes"]
        ):
            out.append(w["text"])
    return out


def weak_form_count(words: list[dict], lex: Lexicon) -> int:
    n = 0
    for w in words:
        prons = lex.base(w["text"]) or []
        said = " ".join(p["ipa"] for p in w["phonemes"])
        if (
            any(is_stressed(p) for p in prons)
            and w["phonemes"]
            and not any(p.get("stress") for p in w["phonemes"])
        ):
            n += 1 if said else 0
    return n


def sound_tags(
    src: Source, words: list[dict], corpus_freq: Counter, corpus_total: int
) -> list[str]:
    """Declared focus, then the most over-represented target phonemes, then the
    level's feature tags."""
    counts = Counter(p["ipa"] for w in words for p in w["phonemes"])
    total = sum(counts.values()) or 1
    min_count = 1 if src.level == 1 else 2
    ranked = sorted(
        (
            (-(counts[ph] / total) / (corpus_freq[ph] / corpus_total), ph)
            for ph in TARGETS
            if counts[ph] >= min_count and corpus_freq[ph]
        ),
    )
    tags = [t for t in src.focus if t not in FEATURES]
    for _, ph in ranked:
        if len(tags) >= MAX_TAGS:
            break
        if ph not in tags:
            tags.append(ph)
    features = [f for f in src.focus if f in FEATURES]
    for f in LEVEL_FEATURES[src.level]:
        if f not in features:
            features.append(f)
    return tags + features


def build_words(src: Source, lex: Lexicon) -> tuple[list[dict], list[str]]:
    """WordSpec dicts for [src] and the words no source knows."""
    words, unknown = [], []
    for i, (tok, pron) in enumerate(transcribe(src.text, lex)):
        if pron is None:
            unknown.append(tok.text)
            phonemes: list[dict] = []
        else:
            phonemes = to_phonemes(pron)
        words.append(
            {
                "text": tok.text,
                "index": i,
                "phonemes": phonemes,
                "scorable": pron is not None,
                "offset": tok.offset,
            }
        )
    return words, unknown


def check_source(src: Source, words: list[dict], lex: Lexicon, library: bool) -> list[str]:
    """Problems with one passage (length, sentences, focus, level checks)."""
    errs = []
    where = f"{src.file}:{src.id}"
    if not src.title:
        errs.append(f"{where}: empty title")
    if re.search(r"\d", src.text):
        errs.append(f"{where}: spell numbers out (digits found)")
    if re.search(r"\b(Mr|Mrs|Ms|Dr|St|etc|e\.g|i\.e)\.", src.text):
        errs.append(f"{where}: abbreviation with a full stop breaks sentence splitting")
    lo, hi, slo, shi = LENGTHS[src.level]
    if not lo <= len(words) <= hi:
        errs.append(f"{where}: {len(words)} words, level {src.level} wants {lo}-{hi}")
    n = sentence_count(src.text)
    if not slo <= n <= shi:
        errs.append(f"{where}: {n} sentences, level {src.level} wants {slo}-{shi}")
    said = {p["ipa"] for w in words for p in w["phonemes"]}
    for t in src.focus:
        if t not in FEATURES and t not in said:
            errs.append(f"{where}: focus {t!r} does not occur in the passage")
    if src.level == 2 and not said & {"θ", "ð"}:
        errs.append(f"{where}: level 2 passages practise /θ/ and /ð/")
    if src.level == 3:
        if not said & LONG_VOWELS:
            errs.append(f"{where}: level 3 passages practise long vowels")
        if len(non_rhotic_words(words)) < 2:
            errs.append(f"{where}: level 3 needs 2+ words with a silent r")
    if src.level == 4 and weak_form_count(words, lex) < 6:
        errs.append(f"{where}: level 4 needs 6+ weak forms")
    if src.level == 1 and not said & SHORT_VOWELS:
        errs.append(f"{where}: level 1 passages practise short vowels")
    return errs


def content_words(text: str) -> set[str]:
    return {w.lower() for w in re.findall(r"[A-Za-z']+", text) if w.lower() not in STOPWORDS}


def near_duplicates(sources: list[Source]) -> list[tuple[str, str, float]]:
    """Pairs of passages at the same level whose content words overlap too much."""
    out = []
    sets = [(s, content_words(s.text)) for s in sources]
    for i, (a, wa) in enumerate(sets):
        for b, wb in sets[i + 1 :]:
            if a.level != b.level or not wa or not wb:
                continue
            j = len(wa & wb) / len(wa | wb)
            if j > NEAR_DUPLICATE:
                out.append((a.id, b.id, round(j, 2)))
    return out


def parse_pairs(text: str) -> list[tuple[str, str, str]]:
    """``contrast: wordA wordB, wordA wordB`` lines -> (contrast, a, b)."""
    out = []
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        contrast, rest = (s.strip() for s in line.split(":", 1))
        for pair in rest.split(","):
            ws = pair.split()
            if len(ws) != 2:
                raise BuildError(f"minimal_pairs.txt: bad pair {pair!r} in {contrast}")
            out.append((contrast, ws[0], ws[1]))
    return out


def build_pairs(pairs: list[tuple[str, str, str]], lex: Lexicon) -> tuple[list[dict], list[str]]:
    """MinimalPair dicts; each pair must differ in exactly the contrasted phoneme."""
    out, errs = [], []
    for contrast, a, b in pairs:
        pa, pb = lex.britfone.get(norm_key(a)), lex.britfone.get(norm_key(b))
        if not pa or not pb:
            errs.append(f"minimal pair {a}/{b}: not in Britfone")
            continue
        sa = [strip_stress(t) for t in pa[0].split()]
        sb = [strip_stress(t) for t in pb[0].split()]
        x, y = contrast.split("-")
        diff = [(p, q) for p, q in zip(sa, sb, strict=False) if p != q]
        if len(sa) != len(sb) or diff != [(x, y)]:
            errs.append(f"minimal pair {a}/{b}: {' '.join(sa)} vs {' '.join(sb)} is not {contrast}")
            continue
        out.append(
            {
                "contrast": contrast,
                "wordA": a,
                "wordB": b,
                "phonemesA": to_phonemes(pa[0]),
                "phonemesB": to_phonemes(pb[0]),
            }
        )
    return out, errs


def dump_bundle(passages: list[dict], placement: list[dict]) -> str:
    """JSON with one word per line, so diffs stay readable."""

    def passage(p: dict) -> str:
        head = {k: v for k, v in p.items() if k != "words"}
        lines = [
            "  {",
            *(f"   {json.dumps(k)}: {json.dumps(v, ensure_ascii=False)}," for k, v in head.items()),
            '   "words": [',
        ]
        ws = [json.dumps(w, ensure_ascii=False, separators=(",", ":")) for w in p["words"]]
        lines += [f"    {w}," for w in ws[:-1]] + [f"    {ws[-1]}"]
        lines += ["   ]", "  }"]
        return "\n".join(lines)

    def section(name: str, items: list[dict]) -> str:
        return f' "{name}": [\n' + ",\n".join(passage(p) for p in items) + "\n ]"

    return (
        "{\n"
        f' "version": {BUNDLE_VERSION},\n'
        + section("passages", passages)
        + ",\n"
        + section("placement", placement)
        + "\n}\n"
    )


def load_extra_variants(path: Path = EXTRA_VARIANTS) -> dict[str, list[str]]:
    """word -> extra accepted pronunciations from extra_variants.tsv."""
    out: dict[str, list[str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        word, pron = line.split("\t")
        out.setdefault(norm_key(word), []).append(pron.strip())
    return out


def rule_variants(word: str, pron: str) -> list[str]:
    """Rule-based alternatives: "-day" as /deɪ/ or /di/, "ex-" as /ɛk/ or /ɪk/."""
    out = []
    toks = pron.split()
    plain = [strip_stress(t) for t in toks]
    for suffix in (["d", "i"], ["d", "i", "z"], ["d", "eɪ"], ["d", "eɪ", "z"]):
        n = len(suffix)
        if word.rstrip("s").endswith("day") and plain[-n:] == suffix:
            swapped = ["d", "eɪ" if suffix[1] == "i" else "i", *suffix[2:]]
            out.append(" ".join(toks[:-n] + swapped))
            break
    if word.startswith("ex") and len(plain) > 2 and plain[1] in ("k", "ɡ"):
        if plain[0] in ("ɪ", "ɛ") and toks[0] == plain[0]:
            out.append(" ".join(["ɛ" if plain[0] == "ɪ" else "ɪ", *toks[1:]]))
    return out


def alternatives(words: set[str], lex: Lexicon, extra: dict[str, list[str]]) -> dict:
    """word -> every accepted pronunciation (preferred first) for words with more
    than one: Britfone's variants and weak forms, pre-vowel forms, extra_variants.tsv
    and the "-day" / "ex-" rules."""
    out = {}
    for word in sorted(words):
        prons = list(lex.base(word) or [])
        if not prons:
            continue
        if word in ("the", "to"):
            prons.append(PRE_VOWEL[word])
        prons += extra.get(word, [])
        for p in list(prons):
            prons += rule_variants(word, p)
        seen: dict[str, str] = {}
        for p in prons:  # one entry per phoneme sequence, ignoring stress
            seen.setdefault(" ".join(strip_stress(t) for t in p.split()), p)
        unique = list(seen.values())
        if len(unique) > 1:
            out[word] = unique
    return out


def dump_alternatives(alts: dict) -> str:
    body = ",\n".join(
        f"  {json.dumps(w, ensure_ascii=False)}: {json.dumps(p, ensure_ascii=False)}"
        for w, p in alts.items()
    )
    return '{\n "version": 1,\n "alternatives": {\n' + body + "\n }\n}\n"


def dump_pairs(pairs: list[dict]) -> str:
    body = ",\n".join(
        "  " + json.dumps(p, ensure_ascii=False, separators=(",", ":")) for p in pairs
    )
    return '{\n "version": 1,\n "pairs": [\n' + body + "\n ]\n}\n"


def dump_table(lex: Lexicon) -> str:
    """Runtime table: ``word<TAB>pron|pron`` (preferred first), Britfone words only."""
    lines = [
        "# Britfone 3.0.1 (MIT, Copyright (c) 2017 Jose Llarena; see BRITFONE_LICENSE.txt),",
        "# normalised by tools/content/build.py. word<TAB>pronunciations, preferred first.",
    ]
    for word in sorted(lex.britfone):
        lines.append(f"{word}\t{'|'.join(lex.britfone[word])}")
    return "\n".join(lines) + "\n"


def dump_sources(sources: list[Source]) -> str:
    lines = [
        "# Passage sources",
        "",
        "Generated by `tools/content/build.py` from `tools/content/passages/`.",
        "Every passage is original writing for UK Pronunciation Coach unless stated",
        "otherwise; no copyrighted text is used.",
        "",
        "| Id | Level | Title | Source |",
        "| --- | --- | --- | --- |",
    ]
    for s in sources:
        lines.append(f"| {s.id} | {s.level} | {s.title} | {s.source} |")
    return "\n".join(lines) + "\n"


def dump_review(
    overrides: dict[str, dict],
    used: dict[str, list[str]],
    stats: dict[str, int],
    dupes: list[tuple[str, str, float]],
) -> str:
    lines = [
        "# Content review report",
        "",
        "Generated by `tools/content/build.py`. Words below are not in Britfone; their",
        "IPA comes from `tools/content/lexicon_overrides.tsv` (eSpeak NG en-gb-x-rp output,",
        "dev-side only). **A human should check each line marked `no`** and set it to",
        "`yes` in the overrides file after correcting it.",
        "",
        "## Coverage",
        "",
        f"- Word tokens: {stats['tokens']}; from Britfone: {stats['britfone']}"
        f" ({100 * stats['britfone'] / max(1, stats['tokens']):.1f}%),"
        f" derived (inflections, contractions): {stats['derived']},"
        f" overrides: {stats['override']}, unscorable: {stats['unknown']}",
        f"- Distinct words: {stats['types']}; not in Britfone: {stats['types_override']}",
        "",
        "## Words for review",
        "",
        "| Word | IPA | Source | Reviewed | Passages |",
        "| --- | --- | --- | --- | --- |",
    ]
    for word in sorted(overrides):
        if word not in used:
            continue
        e = overrides[word]
        lines.append(
            f"| {word} | /{e['ipa']}/ | {e['source']} | {e['reviewed']} |"
            f" {', '.join(sorted(set(used[word])))} |"
        )
    lines += ["", "## Near-duplicate check", ""]
    if dupes:
        lines += [f"- {a} / {b}: overlap {j}" for a, b, j in dupes]
    else:
        lines.append(f"No same-level pair shares more than {NEAR_DUPLICATE:.0%} of content words.")
    return "\n".join(lines) + "\n"


@dataclass
class Outputs:
    files: dict[Path, str]
    overrides: dict[str, dict]
    stats: dict[str, int]


def build(
    root: Path = ROOT,
    use_espeak: bool = False,
    runner: espeak.Runner | None = None,
    sources_dir: Path = SOURCES_DIR,
    pairs_src: Path = PAIRS_SRC,
    overrides_path: Path = OVERRIDES,
    log: Callable[[str], None] = print,
) -> Outputs:
    """Builds every output in memory. Raises [BuildError] on invalid input."""
    overrides = load_overrides(overrides_path)
    lex = Lexicon.load({w: e["ipa"] for w, e in overrides.items()})

    library: list[Source] = []
    for level in range(1, 7):
        path = sources_dir / f"level{level}.txt"
        library += parse_sources(path.read_text(encoding="utf-8"), path.name)
    placement_path = sources_dir / "placement.txt"
    placement = parse_sources(placement_path.read_text(encoding="utf-8"), placement_path.name)

    errs: list[str] = []
    for s in library:
        if not s.id.startswith(f"l{s.level}-") or s.file != f"level{s.level}.txt":
            errs.append(f"{s.file}:{s.id}: belongs in level{s.level}.txt")
    if [s.level for s in placement] != [1, 3, 5]:
        errs.append("placement.txt: want placement-l1, placement-l3, placement-l5 in order")
    everything = library + placement
    ids = Counter(s.id for s in everything)
    errs += [f"duplicate id {i}" for i, n in ids.items() if n > 1]

    # Words nobody knows: ask eSpeak (dev only) or fail.
    missing = sorted(
        {
            norm_key(t.text)
            for s in everything
            for t, pron in transcribe(s.text, lex)
            if pron is None
        }
    )
    if missing and use_espeak:
        for word in missing:
            ipa = espeak.transcribe(word, runner)
            overrides[word] = {"ipa": ipa, "source": f"espeak-ng {espeak.VOICE}", "reviewed": "no"}
            log(f"eSpeak: {word} -> /{ipa}/ (flagged for review)")
        lex = Lexicon.load({w: e["ipa"] for w, e in overrides.items()})
    elif missing:
        errs.append(
            "words not in Britfone or lexicon_overrides.tsv (run with --espeak locally): "
            + ", ".join(missing)
        )

    built: dict[str, list[dict]] = {}
    used: dict[str, list[str]] = {}
    stats = Counter()
    types: set[str] = set()
    for s in everything:
        words, unknown = build_words(s, lex)
        built[s.id] = words
        errs += check_source(s, words, lex, s in library)
        for w in words:
            key = norm_key(w["text"])
            src = lex.source(w["text"]) or "unknown"
            stats["tokens"] += 1
            stats[src] += 1
            if key not in types:
                types.add(key)
                if src == "override":
                    stats["types_override"] += 1
            if src == "override":
                used.setdefault(key, []).append(s.id)

    dupes = near_duplicates(everything)
    errs += [f"near-duplicate passages {a} / {b} ({j})" for a, b, j in dupes]

    pairs, pair_errs = build_pairs(parse_pairs(pairs_src.read_text(encoding="utf-8")), lex)
    errs += pair_errs
    if errs:
        raise BuildError("\n".join(errs))

    corpus = Counter(p["ipa"] for ws in built.values() for w in ws for p in w["phonemes"])
    total = sum(corpus.values())

    def passage(s: Source) -> dict:
        return {
            "id": s.id,
            "level": s.level,
            "title": s.title,
            "text": s.text,
            "soundTags": sound_tags(s, built[s.id], corpus, total),
            "words": built[s.id],
        }

    library.sort(key=lambda s: (s.level, s.id))
    stats["types"] = len(types)
    files = {
        root / ASSETS / "passages.v1.json": dump_bundle(
            [passage(s) for s in library], [passage(s) for s in placement]
        ),
        root / ASSETS / "minimal_pairs.json": dump_pairs(pairs),
        root / ASSETS / "alternatives.v1.json": dump_alternatives(
            alternatives(types, lex, load_extra_variants())
        ),
        root / ASSETS / "britfone.v1.tsv": dump_table(lex),
        root / ASSETS / "BRITFONE_LICENSE.txt": BRITFONE_LICENSE.read_text(encoding="utf-8"),
        root / ASSETS / "SOURCES.md": dump_sources(library + placement),
        root / "tools" / "content" / "review.md": dump_review(overrides, used, stats, dupes),
    }
    for k in ("britfone", "derived", "override", "unknown", "types_override"):
        stats.setdefault(k, 0)
    return Outputs(files, overrides, dict(stats))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build the passage bundle")
    parser.add_argument("--check", action="store_true", help="fail if outputs differ")
    parser.add_argument("--espeak", action="store_true", help="transcribe unknown words")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    try:
        out = build(args.root, use_espeak=args.espeak and not args.check)
    except BuildError as e:
        print(f"content build FAILED:\n{e}", file=sys.stderr)
        return 1
    if args.check:
        stale = [
            str(p.relative_to(args.root))
            for p, text in out.files.items()
            if not p.exists() or p.read_text(encoding="utf-8") != text
        ]
        if stale:
            print("content build: committed outputs are stale or hand-edited:", *stale, sep="\n  ")
            print("Run `python -m tools.content.build` and commit the result.")
            return 1
        print("content build: outputs up to date")
        return 0
    if args.espeak:
        write_overrides(out.overrides)
    for path, text in out.files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    s = out.stats
    print(
        f"content build: {s['tokens']} words, {s['britfone']} from Britfone, "
        f"{s['derived']} derived, {s['override']} from overrides"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
