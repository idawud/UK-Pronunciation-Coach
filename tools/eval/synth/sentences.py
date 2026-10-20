"""Eval sentences for the synthetic set: the app's own passages split into sentences
(phonemes from C1's bundle, `assets/content/passages.v1.json`) plus the VCTK sentence
texts already used by the native set (phonemes from Britfone 3.0.1).

`select` writes the committed list `tools/eval/synth/sentences.tsv` (id, source, text);
`passages` turns that list back into `Passage` JSON for the harness.
"""

from __future__ import annotations

import csv
import json
import random
from pathlib import Path

from tools.eval import lexicon as lx

ROOT = Path(__file__).resolve().parents[3]
CONTENT = ROOT / "assets" / "content" / "passages.v1.json"
SENTENCES_TSV = Path(__file__).parent / "sentences.tsv"
SEED = 20261020
MIN_WORDS, MAX_WORDS = 4, 12
ABBREVIATIONS = {"mr", "mrs", "ms", "dr", "st", "prof", "etc", "vs"}


def split_passage(passage: dict) -> list[dict]:
    """A content passage -> one passage per sentence (words re-indexed, offsets made
    relative to the sentence). Sentences end at `.`, `!` or `?` after a word."""
    text, words = passage["text"], passage["words"]
    out, cur, start = [], [], 0
    for i, w in enumerate(words):
        cur.append(w)
        end = w["offset"] + len(w["text"])
        nxt = words[i + 1]["offset"] if i + 1 < len(words) else len(text)
        gap = text[end:nxt]
        if (
            any(c in gap for c in ".!?") and w["text"].lower() not in ABBREVIATIONS
        ) or i + 1 == len(words):
            stop = end + len(gap.rstrip())
            sid = f"{passage['id']}.s{len(out) + 1}"
            out.append(
                {
                    "id": sid,
                    "level": passage.get("level", 1),
                    "title": sid,
                    "text": text[start:stop].strip(),
                    "words": [
                        {
                            **x,
                            "index": j,
                            "offset": x["offset"] - cur[0]["offset"],
                        }
                        for j, x in enumerate(cur)
                    ],
                }
            )
            cur = []
            start = nxt
    return out


def content_sentences(path: Path = CONTENT) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return [s for p in data["passages"] for s in split_passage(p)]


def ok_length(n: int) -> bool:
    return MIN_WORDS <= n <= MAX_WORDS


def select(
    content: list[dict],
    vctk_texts: list[str],
    n_content: int = 200,
    n_vctk: int = 100,
    seed: int = SEED,
) -> list[dict]:
    """Rows {id, source, text}: [n_content] app sentences spread evenly over the levels
    plus [n_vctk] VCTK texts, all with MIN_WORDS..MAX_WORDS words."""
    rng = random.Random(seed)
    by_level: dict[int, list[dict]] = {}
    for s in content:
        if ok_length(len(s["words"])) and all(w["scorable"] for w in s["words"]):
            by_level.setdefault(s["level"], []).append(s)
    levels = sorted(by_level)
    chosen: list[dict] = []
    for i, lv in enumerate(levels):
        pool = sorted(by_level[lv], key=lambda s: s["id"])
        rng.shuffle(pool)
        want = n_content // len(levels) + (i < n_content % len(levels))
        chosen += pool[:want]
    if len(chosen) < n_content:  # small levels: top up from the rest
        rest = [s for lv in levels for s in by_level[lv] if s not in chosen]
        rng.shuffle(rest)
        chosen += rest[: n_content - len(chosen)]
    rows = [{"id": s["id"], "source": "content", "text": s["text"]} for s in chosen]
    texts = sorted({t for t in vctk_texts if ok_length(len(lx.tokenize(t)))})
    rng.shuffle(texts)
    rows += [
        {"id": f"vctk.{i + 1:03d}", "source": "vctk", "text": t}
        for i, t in enumerate(sorted(texts[:n_vctk]))
    ]
    return sorted(rows, key=lambda r: r["id"])


def write_rows(rows: list[dict], path: Path = SENTENCES_TSV) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, ["id", "source", "text"], delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def read_rows(path: Path = SENTENCES_TSV) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def passages(rows: list[dict], content: list[dict], lexicon: lx.Lexicon | None) -> list[dict]:
    """`Passage` JSON for each row: content sentences as split, VCTK texts through the
    Britfone lexicon (needs [lexicon] only when there are VCTK rows)."""
    by_id = {s["id"]: s for s in content}
    out = []
    for r in rows:
        if r["source"] == "content":
            if r["id"] not in by_id:
                raise KeyError(f"{r['id']}: not in the content bundle (rebuild sentences.tsv)")
            out.append(by_id[r["id"]])
        else:
            if lexicon is None:
                raise ValueError("VCTK sentences need the Britfone lexicon")
            p = lx.passage_json(r["id"], r["text"], lexicon)
            if not all(w["scorable"] for w in p["words"]):
                raise ValueError(f"{r['id']}: a word has no pronunciation")
            out.append(p)
    return out
