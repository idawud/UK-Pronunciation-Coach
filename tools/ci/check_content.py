"""Content bundle check (CI "content" job).

Validates assets/content/passages.v1.json against the Passage model
(lib/core/models/passage.dart): ids unique, levels 1-6, 20 passages per level, word
indexes 0..n-1, every scorable word has phonemes, offsets point at the word in the
text. Also checks assets/content/minimal_pairs.json (40+ pairs) when present.

Before C1-content delivers the bundle, the check passes with a notice; pass
--require to fail when the bundle is missing.

    python3 tools/ci/check_content.py [--root .] [--require] [--per-level 20]
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

BUNDLE = Path("assets/content/passages.v1.json")
PAIRS = Path("assets/content/minimal_pairs.json")


def passages_of(data: Any) -> list[Any]:
    """Accepts a list of passages or an object with a 'passages' list."""
    if isinstance(data, list):
        return data
    if isinstance(data, dict) and isinstance(data.get("passages"), list):
        return data["passages"]
    raise ValueError("bundle must be a list of passages or {'passages': [...]}")


def check_phoneme(p: Any, where: str) -> list[str]:
    if not isinstance(p, dict) or not isinstance(p.get("ipa"), str) or not p["ipa"]:
        return [f"{where}: phoneme needs a non-empty 'ipa'"]
    errors = []
    if "ˈ" in p["ipa"] or "ˌ" in p["ipa"]:
        errors.append(f"{where}: stress marks belong in 'stress', not 'ipa'")
    if p.get("stress", 0) not in (0, 1, 2):
        errors.append(f"{where}: stress must be 0, 1 or 2")
    return errors


def check_passage(p: Any, index: int) -> list[str]:
    """Errors for one passage dict."""
    if not isinstance(p, dict):
        return [f"passage #{index}: not an object"]
    pid = p.get("id")
    where = f"passage {pid!r}"
    errors = []
    for key, kind in (("id", str), ("title", str), ("text", str), ("words", list)):
        if not isinstance(p.get(key), kind):
            errors.append(f"{where}: '{key}' must be a {kind.__name__}")
    level = p.get("level")
    if not isinstance(level, int) or isinstance(level, bool) or not 1 <= level <= 6:
        errors.append(f"{where}: level must be an int 1-6")
    tags = p.get("soundTags", [])
    if not isinstance(tags, list) or not all(isinstance(t, str) for t in tags):
        errors.append(f"{where}: soundTags must be a list of strings")
    if errors:
        return errors
    if not p["words"]:
        errors.append(f"{where}: no words")
    text = p["text"]
    for i, w in enumerate(p["words"]):
        ww = f"{where} word {i}"
        if not isinstance(w, dict) or not isinstance(w.get("text"), str) or not w["text"]:
            errors.append(f"{ww}: needs non-empty 'text'")
            continue
        if w.get("index") != i:
            errors.append(f"{ww}: index is {w.get('index')!r}, expected {i}")
        phonemes = w.get("phonemes", [])
        if not isinstance(phonemes, list):
            errors.append(f"{ww}: phonemes must be a list")
            continue
        if w.get("scorable", True) and not phonemes:
            errors.append(f"{ww} ({w['text']!r}): scorable word has no phonemes")
        for j, ph in enumerate(phonemes):
            errors += check_phoneme(ph, f"{ww} phoneme {j}")
        offset = w.get("offset")
        if offset is not None and text[offset : offset + len(w["text"])] != w["text"]:
            errors.append(f"{ww}: offset {offset} does not point at {w['text']!r}")
    return errors


def check_bundle(data: Any, per_level: int | None) -> list[str]:
    """Errors for the whole bundle."""
    try:
        passages = passages_of(data)
    except ValueError as e:
        return [str(e)]
    errors = []
    for i, p in enumerate(passages):
        errors += check_passage(p, i)
    ids = Counter(p.get("id") for p in passages if isinstance(p, dict))
    errors += [f"duplicate id {pid!r}" for pid, n in ids.items() if n > 1]
    if per_level is not None:
        levels = Counter(p.get("level") for p in passages if isinstance(p, dict))
        for level in range(1, 7):
            if levels.get(level, 0) != per_level:
                errors.append(
                    f"level {level}: {levels.get(level, 0)} passages, expected {per_level}"
                )
    return errors


def check_pairs(data: Any, minimum: int = 40) -> list[str]:
    """Errors for minimal_pairs.json (list or {'pairs': [...]}, MinimalPair fields)."""
    pairs = data.get("pairs") if isinstance(data, dict) else data
    if not isinstance(pairs, list):
        return ["minimal pairs must be a list or {'pairs': [...]}"]
    errors = []
    if len(pairs) < minimum:
        errors.append(f"minimal pairs: {len(pairs)}, expected at least {minimum}")
    for i, p in enumerate(pairs):
        if not isinstance(p, dict) or not all(
            isinstance(p.get(k), str) and p.get(k) for k in ("contrast", "wordA", "wordB")
        ):
            errors.append(f"minimal pair #{i}: needs contrast, wordA and wordB")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Content bundle check")
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--require", action="store_true")
    parser.add_argument("--per-level", type=int, default=20)
    args = parser.parse_args(argv)
    bundle = args.root / BUNDLE
    if not bundle.exists():
        print(f"content check: {BUNDLE} not found yet (C1-content delivers it)")
        return 1 if args.require else 0
    errors = check_bundle(json.loads(bundle.read_text(encoding="utf-8")), args.per_level)
    pairs = args.root / PAIRS
    if pairs.exists():
        errors += check_pairs(json.loads(pairs.read_text(encoding="utf-8")))
    for e in errors:
        print(f"ERROR: {e}")
    print("content check:", "FAILED" if errors else "passed")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
