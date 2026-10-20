"""Metrics for the synthetic British-voice set (labels known by construction).

    python -m tools.eval.synth.report --labels tools/eval/data/synth/labels.csv \
        --words tools/eval/work/synth/words_default.csv [--json out.json] [--gate heldout]

Engine "wrong" = red (`fix` / `missed`); amber counts as right (as in agreement.py).
Reports word agreement and Cohen's kappa overall, per split (tuning vs held-out voices),
per voice and per read (clean / error), the false-red rate on clean reads, detection
per injected error type, and agreement per augmentation condition. Exit code 1 when
the gate split's agreement is below the threshold (default 80%), 0 with SKIPPED when
the labels or the harness output are missing.

This is a PROXY for teacher agreement: TTS voices read clean phoneme substitutions,
not accented learner speech (see docs/eval-report.md).
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from collections.abc import Callable, Iterable
from pathlib import Path

from tools.eval.agreement import THRESHOLD, score
from tools.eval.analyse import RED, read_csv
from tools.eval.synth.inject import error_class


def _join(labels: list[dict], words: list[dict]) -> list[tuple[dict, dict]]:
    engine = {(r["item"], str(r["word_index"])): r for r in words}
    out = []
    for lab in labels:
        w = engine.get((lab["item"], str(lab["word_index"])))
        if w is not None and w["status"] != "notScored":
            out.append((lab, w))
    return out


def grouped(
    labels: list[dict], words: list[dict], key: Callable[[dict], str | None]
) -> dict[str, dict]:
    groups: dict[str, list[dict]] = defaultdict(list)
    for lab in labels:
        k = key(lab)
        if k is not None:
            groups[k].append(lab)
    return {k: score(v, words) for k, v in sorted(groups.items())}


def detection(pairs: Iterable[tuple[dict, dict]], key: Callable[[dict], str]) -> dict:
    """Per group of wrong words: share red, share not green (amber or red)."""
    acc: dict[str, list[str]] = defaultdict(list)
    for lab, w in pairs:
        if lab["label"] == "wrong":
            acc[key(lab)].append(w["status"])
    return {
        k: {
            "words": len(v),
            "red": sum(s in RED for s in v) / len(v),
            "not_green": sum(s != "good" for s in v) / len(v),
        }
        for k, v in sorted(acc.items())
    }


def aug_tags(desc: str) -> list[str]:
    tags = ["noise" if "dB" in desc else "no-noise"]
    tags.append("reverb" if "reverb" in desc else "dry-room")
    tags.append("phone-band" if "phone" in desc else "full-band")
    return tags


def summarise(labels: list[dict], words: list[dict]) -> dict:
    pairs = _join(labels, words)
    clean = [lab for lab in labels if lab.get("read") == "clean"]
    by_aug: dict[str, list[dict]] = defaultdict(list)
    for lab in labels:
        for t in aug_tags(lab.get("aug", "")):
            by_aug[t].append(lab)
    status_by_read: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for lab, w in pairs:
        status_by_read[lab.get("read", "")][w["status"]] += 1
    every = score(labels, words)
    right = every.get("engine_right_teacher_right", 0) + every.get("engine_wrong_teacher_right", 0)
    return {
        # agreement of an engine that marks every word right: the floor to beat
        "always_right_baseline": right / every["words"] if every.get("words") else 0.0,
        "all": every,
        "all_amber_wrong": score(labels, words, amber_wrong=True),
        "by_split": grouped(labels, words, lambda r: r.get("split") or None),
        "by_voice": grouped(labels, words, lambda r: r.get("voice") or r.get("speaker")),
        "by_read": grouped(labels, words, lambda r: r.get("read") or None),
        "clean_false_red": score(clean, words).get("false_red_on_right_words", 0.0),
        "clean_false_red_by_split": {
            k: v.get("false_red_on_right_words", 0.0)
            for k, v in grouped(clean, words, lambda r: r.get("split") or None).items()
        },
        "status_by_read": {k: dict(v) for k, v in status_by_read.items()},
        "detection_by_error": detection(pairs, lambda r: r.get("error", "") or "?"),
        "detection_by_class": detection(pairs, lambda r: error_class(r.get("error", "") or "?")),
        "detection_by_split": detection(pairs, lambda r: r.get("split", "") or "?"),
        "by_augmentation": {k: score(v, words) for k, v in sorted(by_aug.items())},
    }


def pct(x: float) -> str:
    return f"{100 * x:.1f}%"


def format_summary(s: dict) -> str:
    def line(name: str, m: dict) -> str:
        if not m.get("words"):
            return f"{name:22} (no words)"
        return (
            f"{name:22} {m['words']:6}  agree {pct(m['agreement']):6}  "
            f"kappa {m['kappa']:.3f}  false red {pct(m['false_red_on_right_words']):6}  "
            f"recall {pct(m['recall_of_wrong_words'])}"
        )

    out = [
        line("all", s["all"]),
        f"{'':22} (an engine marking every word right would agree "
        f"{pct(s['always_right_baseline'])})",
        line("all (amber = wrong)", s["all_amber_wrong"]),
    ]
    out += [line(f"split {k}", v) for k, v in s["by_split"].items()]
    out += [line(f"read {k}", v) for k, v in s["by_read"].items()]
    out += [line(f"voice {k}", v) for k, v in s["by_voice"].items()]
    out += [line(f"aug {k}", v) for k, v in s["by_augmentation"].items()]
    out.append(f"clean-read false red: {pct(s['clean_false_red'])} {s['clean_false_red_by_split']}")
    out.append("detection (wrong words red / not green):")
    for k, v in list(s["detection_by_class"].items()) + list(s["detection_by_error"].items()):
        out.append(
            f"  {k:16} n={v['words']:5}  red {pct(v['red']):6}  !green {pct(v['not_green'])}"
        )
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--labels", type=Path, required=True)
    ap.add_argument("--words", type=Path, required=True)
    ap.add_argument("--json", type=Path)
    ap.add_argument("--threshold", type=float, default=THRESHOLD)
    ap.add_argument(
        "--gate", default="heldout", help="split whose agreement is gated ('all' for every voice)"
    )
    ap.add_argument(
        "--min-kappa", type=float, help="also require Cohen's kappa >= this on the gate split"
    )
    args = ap.parse_args(argv)
    for p in (args.labels, args.words):
        if not p.exists():
            print(f"SKIPPED: {p} not found")
            return 0
    s = summarise(read_csv(args.labels), read_csv(args.words))
    print(format_summary(s))
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(s, ensure_ascii=False, indent=1), encoding="utf-8")
    gate = s["all"] if args.gate == "all" else s["by_split"].get(args.gate, {})
    if not gate.get("words"):
        print(f"SKIPPED: no scored words in split {args.gate!r}")
        return 0
    ok = gate["agreement"] >= args.threshold
    if args.min_kappa is not None and gate["kappa"] < args.min_kappa:
        print(f"kappa {gate['kappa']:.3f} < --min-kappa {args.min_kappa}")
        ok = False
    print(
        f"{'GO' if ok else 'NO-GO'} (synthetic proxy, {args.gate} voices): word agreement "
        f"{pct(gate['agreement'])}, kappa {gate['kappa']:.3f} (threshold {args.threshold:.0%})"
    )
    return 0 if ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
