"""Metrics over the harness CSVs (`words_<config>.csv`, `clips_<config>.csv`).

    python -m tools.eval.analyse tools/eval/work/baseline --config default

Native rows (`kind == native`) give the false red ("fix" or missed) and amber rates on
native British speech; probe rows (`swap`, `sub`) give the controlled-error detection
rate for their target word. Probes are a proxy: the audio is a correct native reading
and only the *expected* transcript was changed, so detection says whether the engine
notices a mismatch between expected and spoken sounds, not whether it agrees with a
teacher on real learner speech.
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
from collections import Counter, defaultdict
from collections.abc import Iterable
from pathlib import Path

RED = {"fix", "missed"}
FUNCTION_WORDS = {
    "a", "an", "the", "and", "but", "or", "of", "to", "from", "for", "at", "as", "in", "on",
    "by", "with", "her", "him", "his", "them", "us", "your", "you", "we", "he", "she", "it",
    "was", "were", "is", "are", "be", "been", "has", "have", "had", "can", "could", "would",
    "should", "will", "do", "does", "that", "than", "there", "some", "not", "into", "our",
    "me", "my", "they", "their", "this", "these", "those", "which", "who", "what", "so", "no",
}  # fmt: skip


def read_csv(path: Path) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def scored(rows: Iterable[dict]) -> list[dict]:
    return [r for r in rows if r["status"] != "notScored"]


def rates(rows: list[dict]) -> dict:
    """Share of words per colour (red = fix + missed)."""
    rows = scored(rows)
    n = len(rows)
    c = Counter(r["status"] for r in rows)
    red = c["fix"] + c["missed"]
    return {
        "words": n,
        "red": red / n if n else 0.0,
        "fix": c["fix"] / n if n else 0.0,
        "missed": c["missed"] / n if n else 0.0,
        "amber": c["close"] / n if n else 0.0,
        "green": c["good"] / n if n else 0.0,
        "mean_score": statistics.fmean(int(r["score"]) for r in rows) if n else 0.0,
    }


def native_rates(rows: list[dict], split: str | None = None) -> dict:
    sel = [r for r in rows if r["kind"] == "native" and (split is None or r["split"] == split)]
    out = rates(sel)
    out["content_words"] = rates([r for r in sel if r["word"].lower() not in FUNCTION_WORDS])
    out["function_words"] = rates([r for r in sel if r["word"].lower() in FUNCTION_WORDS])
    out["by_speaker"] = {
        s: rates([r for r in sel if r["speaker"] == s]) for s in sorted({r["speaker"] for r in sel})
    }
    return out


def probe_detection(rows: list[dict], split: str | None = None) -> dict:
    """Per probe kind: share of target words that came out red / not green."""
    out = {}
    for kind in ("swap", "sub"):
        targets = [
            r
            for r in rows
            if r["kind"] == kind
            and r["is_target"] == "1"
            and (split is None or r["split"] == split)
        ]
        n = len(targets)
        red = sum(r["status"] in RED for r in targets)
        not_green = sum(r["status"] != "good" for r in targets)
        out[kind] = {
            "items": n,
            "red": red / n if n else 0.0,
            "not_green": not_green / n if n else 0.0,
        }
    both = [r for r in rows if r["kind"] in ("swap", "sub") and r["is_target"] == "1"]
    both = [r for r in both if split is None or r["split"] == split]
    out["all"] = {
        "items": len(both),
        "red": sum(r["status"] in RED for r in both) / len(both) if both else 0.0,
        "not_green": sum(r["status"] != "good" for r in both) / len(both) if both else 0.0,
    }
    return out


def sub_pairs(rows: list[dict], probes: dict[str, str]) -> dict[str, dict]:
    """Detection per substituted pair (`θ->t`) for `sub` probes; [probes] maps item ->
    probe description (`word:θ->t`)."""
    acc: dict[str, list[bool]] = defaultdict(list)
    for r in rows:
        if r["kind"] == "sub" and r["is_target"] == "1":
            pair = probes.get(r["item"], ":?").split(":", 1)[1]
            acc[pair].append(r["status"] in RED)
    return {p: {"items": len(v), "red": sum(v) / len(v)} for p, v in sorted(acc.items())}


def phoneme_stats(rows: list[dict], min_count: int = 10) -> list[dict]:
    """Per expected phoneme on native words: count, mean score, share under 60, and the
    most common things heard instead (`∅` = dropped)."""
    per: dict[str, list[tuple[int, str]]] = defaultdict(list)
    for r in rows:
        if r["kind"] != "native" or r["status"] in ("notScored", "missed") or not r["heard"]:
            continue
        exp = r["expected"].split()
        heard = r["heard"].split()
        scores = r["phoneme_scores"].split()
        if not (len(exp) == len(heard) == len(scores)):
            continue
        for e, h, s in zip(exp, heard, scores, strict=True):
            per[e].append((int(s), h))
    out = []
    for e, v in per.items():
        if len(v) < min_count:
            continue
        low = [h for s, h in v if s < 60]
        confusions = Counter(h for s, h in v if s < 60 and h != e)
        out.append(
            {
                "phoneme": e,
                "count": len(v),
                "mean": statistics.fmean(s for s, _ in v),
                "low": len(low) / len(v),
                "heard_as": confusions.most_common(4),
            }
        )
    return sorted(out, key=lambda x: -x["low"])


def known_issues(rows: list[dict]) -> dict:
    """The American-label issues A3 flagged, counted on native words."""
    lot_total = lot_ah = rcol = rcol_words = flap = t_total = 0
    for r in rows:
        if r["kind"] != "native" or not r["heard"]:
            continue
        exp, heard = r["expected"].split(), r["heard"].split()
        if len(exp) != len(heard):
            continue
        for e, h in zip(exp, heard, strict=True):
            if e == "ɒ":
                lot_total += 1
                lot_ah += h in ("ɑː", "ɑ", "ɑːɹ")
            if h.endswith("ɹ") and h != e and e not in ("ɹ", "r"):
                rcol += 1
            if e == "t":
                t_total += 1
                flap += h == "ɾ"
        rcol_words += any(
            h.endswith("ɹ") and h != e and e not in ("ɹ", "r")
            for e, h in zip(exp, heard, strict=True)
        )
    return {
        "lot_heard_as_ah": {"count": lot_ah, "of": lot_total},
        "vowel_heard_with_r": {"phonemes": rcol, "words": rcol_words},
        "t_heard_as_flap": {"count": flap, "of": t_total},
    }


def timing(clips: list[dict]) -> dict:
    timed = [c for c in clips if c["kind"] == "native" and c["model_ms"]]
    if not timed:
        return {}
    model = [int(c["model_ms"]) for c in timed]
    total = [int(c["recognise_ms"]) for c in timed]
    audio = [int(c["audio_ms"]) for c in timed]
    score = [float(c["score_ms"]) for c in clips if c["kind"] == "native"]
    rtf = [m / a for m, a in zip(model, audio, strict=True)]
    return {
        "clips": len(timed),
        "audio_s_mean": statistics.fmean(audio) / 1000,
        "model_ms_median": statistics.median(model),
        "recognise_ms_median": statistics.median(total),
        "rtf_median": statistics.median(rtf),
        "rtf_p90": sorted(rtf)[int(0.9 * (len(rtf) - 1))],
        "score_ms_median": statistics.median(score),
        "est_25s_passage_s": statistics.median(rtf) * 25,
    }


def summarise(words: list[dict], clips: list[dict] | None = None) -> dict:
    probes = {c["item"]: c["probe"] for c in clips or []}
    return {
        "native": {s or "all": native_rates(words, s) for s in (None, "tune", "heldout")},
        "probes": {s or "all": probe_detection(words, s) for s in (None, "tune", "heldout")},
        "sub_pairs": sub_pairs(words, probes),
        "phonemes": phoneme_stats(words),
        "known_issues": known_issues(words),
        "timing": timing(clips or []),
    }


def pct(x: float) -> str:
    return f"{100 * x:.1f}%"


def format_summary(s: dict) -> str:
    lines = ["split    words  red     amber   green   | swap red  sub red  sub !green"]
    for split in ("all", "tune", "heldout"):
        n, p = s["native"][split], s["probes"][split]
        lines.append(
            f"{split:8} {n['words']:5}  {pct(n['red']):7} {pct(n['amber']):7} "
            f"{pct(n['green']):7} | "
            f"{pct(p['swap']['red']):9} {pct(p['sub']['red']):8} {pct(p['sub']['not_green'])}"
        )
    lines.append("weak phonemes (share < 60 on native words):")
    for ph in s["phonemes"][:12]:
        heard = ", ".join(f"{h} x{c}" for h, c in ph["heard_as"])
        lines.append(
            f"  {ph['phoneme']:3} n={ph['count']:4} low={pct(ph['low']):6} "
            f"mean={ph['mean']:.0f}  {heard}"
        )
    lines.append(f"known issues: {json.dumps(s['known_issues'], ensure_ascii=False)}")
    if s["timing"]:
        lines.append(f"timing: {json.dumps(s['timing'])}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("run_dir", type=Path)
    ap.add_argument("--config", default="default")
    ap.add_argument("--json", type=Path, help="also write the summary as JSON")
    ap.add_argument("--max-red", type=float, help="exit 1 when native false red >= this")
    args = ap.parse_args(argv)
    words = read_csv(args.run_dir / f"words_{args.config}.csv")
    clips_path = args.run_dir / f"clips_{args.config}.csv"
    clips = read_csv(clips_path) if clips_path.exists() else []
    s = summarise(words, clips)
    print(format_summary(s))
    if args.json:
        args.json.write_text(json.dumps(s, ensure_ascii=False, indent=1), encoding="utf-8")
    red = s["native"]["all"]["red"]
    if args.max_red is not None and red >= args.max_red:
        print(f"FAIL: native false red {pct(red)} >= {pct(args.max_red)}")
        return 1
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
