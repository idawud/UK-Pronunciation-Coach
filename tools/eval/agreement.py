"""Word agreement between the engine and a British-English teacher (go/no-go >= 80%).

    # blank labelling sheet for a manifest (one row per scorable word)
    python -m tools.eval.agreement template --manifest M.tsv --passages P.json --out labels.csv
    # agreement of a harness run with the filled-in labels
    python -m tools.eval.agreement score --labels labels.csv --words run/words_default.csv

The teacher marks each word `right` or `wrong` (see tools/eval/LABELLING.md). The
engine says "wrong" when the word is red (`fix` or `missed`); amber (`close`) counts as
"right" by default (`--amber wrong` to count it as wrong). Exit code: 0 when agreement
>= the threshold (default 0.80), 1 below it, and 0 with a "SKIPPED" line when there
are no labels (missing file or no row labelled) unless `--require-labels`.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

from tools.eval.analyse import RED, read_csv

LABEL_FIELDS = ["item", "speaker", "passage", "word_index", "word", "label", "teacher", "notes"]
RIGHT = {"right", "r", "ok", "1", "correct"}
WRONG = {"wrong", "w", "x", "0", "incorrect"}
THRESHOLD = 0.80


def template_rows(
    manifest: list[dict], passages: dict[str, dict], kinds=("native", "learner")
) -> list[dict]:
    rows = []
    for m in manifest:
        if m.get("kind", "native") not in kinds:
            continue
        p = passages[m["passage"]]
        for w in p["words"]:
            if not w.get("scorable", True):
                continue
            rows.append(
                {
                    "item": m["item"],
                    "speaker": m.get("speaker", ""),
                    "passage": m["passage"],
                    "word_index": w["index"],
                    "word": w["text"],
                    "label": "",
                    "teacher": "",
                    "notes": "",
                }
            )
    return rows


def parse_label(v: str) -> bool | None:
    """True = right, False = wrong, None = not labelled."""
    v = (v or "").strip().lower()
    if v in RIGHT:
        return True
    if v in WRONG:
        return False
    return None


def score(labels: list[dict], words: list[dict], amber_wrong: bool = False) -> dict:
    """Agreement, Cohen's kappa and confusion counts over labelled words."""
    engine = {(r["item"], str(r["word_index"])): r["status"] for r in words}
    tp = tn = fp = fn = 0  # positive = "wrong"
    unmatched = 0
    for row in labels:
        lab = parse_label(row.get("label", ""))
        if lab is None:
            continue
        status = engine.get((row["item"], str(row["word_index"])))
        if status is None or status == "notScored":
            unmatched += 1
            continue
        eng_wrong = status in RED or (amber_wrong and status == "close")
        teacher_wrong = not lab
        if eng_wrong and teacher_wrong:
            tp += 1
        elif eng_wrong:
            fp += 1
        elif teacher_wrong:
            fn += 1
        else:
            tn += 1
    n = tp + tn + fp + fn
    if n == 0:
        return {"words": 0, "unmatched": unmatched}
    agree = (tp + tn) / n
    pe = ((tp + fp) * (tp + fn) + (tn + fn) * (tn + fp)) / (n * n)
    kappa = (agree - pe) / (1 - pe) if pe < 1 else 1.0
    return {
        "words": n,
        "unmatched": unmatched,
        "agreement": agree,
        "kappa": kappa,
        "engine_wrong_teacher_wrong": tp,
        "engine_wrong_teacher_right": fp,
        "engine_right_teacher_wrong": fn,
        "engine_right_teacher_right": tn,
        "false_red_on_right_words": fp / (fp + tn) if fp + tn else 0.0,
        "recall_of_wrong_words": tp / (tp + fn) if tp + fn else 0.0,
    }


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("template")
    t.add_argument("--manifest", type=Path, required=True)
    t.add_argument("--passages", type=Path, required=True)
    t.add_argument("--out", type=Path, required=True)
    t.add_argument("--kinds", default="native,learner")
    s = sub.add_parser("score")
    s.add_argument("--labels", type=Path, required=True)
    s.add_argument("--words", type=Path, required=True)
    s.add_argument("--amber", choices=["right", "wrong"], default="right")
    s.add_argument("--threshold", type=float, default=THRESHOLD)
    s.add_argument("--require-labels", action="store_true")
    s.add_argument("--json", type=Path)
    args = ap.parse_args(argv)

    if args.cmd == "template":
        with open(args.manifest, newline="", encoding="utf-8") as f:
            manifest = list(csv.DictReader(f, delimiter="\t"))
        passages = {p["id"]: p for p in json.loads(args.passages.read_text(encoding="utf-8"))}
        rows = template_rows(manifest, passages, tuple(args.kinds.split(",")))
        write_csv(args.out, rows, LABEL_FIELDS)
        print(f"wrote {len(rows)} words to {args.out}")
        return 0

    if not args.labels.exists():
        print(f"SKIPPED: no labels at {args.labels}")
        return 1 if args.require_labels else 0
    labels = read_csv(args.labels)
    if not any(parse_label(r.get("label", "")) is not None for r in labels):
        print(f"SKIPPED: {args.labels} has no labelled words yet")
        return 1 if args.require_labels else 0
    if not args.words.exists():
        print(f"SKIPPED: no harness output at {args.words}")
        return 1 if args.require_labels else 0
    result = score(labels, read_csv(args.words), amber_wrong=args.amber == "wrong")
    print(json.dumps(result, indent=1))
    if args.json:
        args.json.write_text(json.dumps(result, indent=1))
    if result["words"] == 0:
        print("SKIPPED: no labelled word matched the harness output")
        return 1 if args.require_labels else 0
    ok = result["agreement"] >= args.threshold
    verdict = "GO" if ok else "NO-GO"
    print(f"{verdict}: word agreement {result['agreement']:.1%} (threshold {args.threshold:.0%})")
    return 0 if ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
