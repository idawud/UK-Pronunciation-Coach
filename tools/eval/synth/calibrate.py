"""Calibration check / search on the synthetic set, guarded by native VCTK speech.

Both sets must have been run with the probe config (`python -m tools.eval.calibrate
probe-config`), so each phoneme score encodes its GOP; `tools.eval.calibrate.simulate`
then recomputes word colours for any curve / cap / r score / dropped score.

    python -m tools.eval.synth.calibrate \
        --synth-words tools/eval/work/synth/words_probe.csv \
        --labels tools/eval/data/synth/labels.csv \
        --native-words tools/eval/work/native/words_probe.csv \
        --max-red 0.035 --out tools/eval/work/synth_tuned.json

The search maximises word agreement on the TUNING voices only, subject to native false
red on the VCTK tuning speakers <= --max-red (the release target is < 5%, so keep a
margin). It prints the held-out voices and held-out VCTK speakers for the best config
and for the current defaults, so a change is only adopted when it also helps there.
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Iterable
from dataclasses import asdict
from pathlib import Path

from tools.eval import calibrate as cal
from tools.eval.agreement import score
from tools.eval.analyse import RED, read_csv

# The engine-spike defaults (lib/engine/scoring/config/scoring_config.dart).
CURRENT = cal.Params(
    curve=[
        (-6.8, 0),
        (-4.4, 10),
        (-2.8, 30),
        (-2, 50),
        (-1.2, 65),
        (-0.4, 78),
        (0.4, 86),
        (2, 95),
        (4.4, 100),
    ],  # fmt: skip
    word_max_above_worst=40,
    intrusive_r_score=80,
    dropped_score=60,
)


def native_red(rows: list[dict], split: str | None) -> float:
    sel = [
        r
        for r in rows
        if r["kind"] == "native"
        and r["status"] != "notScored"
        and (split is None or r["split"] == split)
    ]
    return sum(r["status"] in RED for r in sel) / len(sel) if sel else 0.0


def evaluate(
    p: cal.Params,
    synth: list[cal.WordObs],
    labels: dict[str, list[dict]],
    native: list[cal.WordObs],
) -> dict:
    sim = cal.simulate(synth, p)
    nat = cal.simulate(native, p)
    out = {}
    for split, labs in labels.items():
        m = score(labs, sim)
        out[f"agree_{split}"] = m.get("agreement", 0.0)
        out[f"kappa_{split}"] = m.get("kappa", 0.0)
        out[f"recall_{split}"] = m.get("recall_of_wrong_words", 0.0)
        out[f"false_red_{split}"] = m.get("false_red_on_right_words", 0.0)
    for split in ("tune", "heldout"):
        out[f"native_red_{split}"] = native_red(nat, split)
    out["native_red_all"] = native_red(nat, None)
    return out


def search(
    synth: list[cal.WordObs],
    labels: dict[str, list[dict]],
    native: list[cal.WordObs],
    params: Iterable[cal.Params],
    max_red: float,
) -> tuple[cal.Params | None, dict, int]:
    """Best tuning-voice agreement with native tuning red <= [max_red]."""
    best, best_m, n = None, {}, 0
    for p in params:
        n += 1
        nat = cal.simulate(native, p)
        if native_red(nat, "tune") > max_red:
            continue
        m = score(labels["tune"], cal.simulate(synth, p))
        if best is None or m["agreement"] > best_m["agree_tune"]:
            best, best_m = p, {"agree_tune": m["agreement"]}
    if best is not None:
        best_m = evaluate(best, synth, labels, native)
    return best, best_m, n


def split_labels(labels: list[dict]) -> dict[str, list[dict]]:
    return {
        "tune": [r for r in labels if r.get("split") == "tune"],
        "heldout": [r for r in labels if r.get("split") == "heldout"],
        "all": labels,
    }


def main(argv: list[str] | None = None) -> int:  # pragma: no cover - CLI wiring
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--synth-words", type=Path, required=True)
    ap.add_argument("--labels", type=Path, required=True)
    ap.add_argument("--native-words", type=Path, required=True)
    ap.add_argument("--max-red", type=float, default=0.035)
    ap.add_argument("--out", type=Path)
    args = ap.parse_args(argv)
    synth = cal.observe(read_csv(args.synth_words))
    native = cal.observe(read_csv(args.native_words))
    labels = split_labels(read_csv(args.labels))
    current = evaluate(CURRENT, synth, labels, native)
    best, m, n = search(synth, labels, native, cal.candidates(), args.max_red)
    print(json.dumps({"current": current, "best": m, "tried": n}, indent=1))
    if best is not None:
        print(json.dumps(asdict(best)))
        if args.out:
            args.out.write_text(json.dumps(best.to_config(), indent=1))
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
