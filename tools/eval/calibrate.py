"""Calibration search for `lib/engine/scoring/config/scoring_config.dart`.

The Dart scorer is the source of truth; this module only re-weighs its per-phoneme
output to search many configs quickly:

1. Run the harness once with `PROBE_CONFIG` (a linear GOP curve, -10 -> 0 .. 10 -> 100,
   and no intrusive-r cap), so each phoneme score encodes its GOP to 0.2 nats.
2. `simulate` recomputes word scores and colours for any calibration curve, word cap,
   stressed-vowel weight, intrusive-r and dropped-sound scores, exactly as
   `GopPronunciationScorer._scoreWord` does (alignment, missed words and `heard` do not
   depend on these settings).
3. `search` picks the config with the best controlled-error detection whose native
   false-red rate on the tuning speakers stays under the target.
4. Re-run the harness with the chosen config (real Dart) and report both splits;
   `agreement` measures how closely the simulation matched Dart.

    python -m tools.eval.calibrate probe-config > tools/eval/work/probe.json
    python -m tools.eval.calibrate search tools/eval/work/probe/words_probe.csv \
        --out tools/eval/work/tuned.json
"""

from __future__ import annotations

import argparse
import itertools
import json
from collections.abc import Iterable, Sequence
from dataclasses import asdict, dataclass, field
from pathlib import Path

from tools.eval.analyse import RED, read_csv

PROBE_LO, PROBE_HI = -10.0, 10.0
PROBE_CONFIG = {
    "calibration": [[PROBE_LO, 0], [PROBE_HI, 100]],
    "intrusiveRScore": 100,
}
DROPPED = "∅"

# A3's initial curve (ScoringConfig.defaultCalibration).
DEFAULT_CURVE = [(-6, 0), (-3, 10), (-1, 30), (0, 50), (1, 65), (2, 78), (3, 86), (5, 95), (8, 100)]


def interp(curve: Sequence[tuple[float, float]], x: float) -> float:
    """PiecewiseLinear.call."""
    if x <= curve[0][0]:
        return curve[0][1]
    if x >= curve[-1][0]:
        return curve[-1][1]
    for (x0, y0), (x1, y1) in itertools.pairwise(curve):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return curve[-1][1]  # pragma: no cover


def dart_round(x: float) -> int:
    """Dart's `round()` (half away from zero)."""
    return int(x + 0.5) if x >= 0 else -int(-x + 0.5)


@dataclass
class Params:
    curve: list[tuple[float, float]] = field(default_factory=lambda: list(DEFAULT_CURVE))
    stressed_vowel_weight: float = 1.5
    word_max_above_worst: float = 50
    intrusive_r_score: int = 45
    dropped_score: int = 0
    good: int = 80
    close: int = 60

    def to_config(self) -> dict:
        """The matching `ScoringConfig.toJson` subset."""
        return {
            "calibration": [[x, y] for x, y in self.curve],
            "stressedVowelWeight": self.stressed_vowel_weight,
            "wordMaxAboveWorst": self.word_max_above_worst,
            "intrusiveRScore": self.intrusive_r_score,
            "droppedScore": self.dropped_score,
            "goodThreshold": self.good,
            "closeThreshold": self.close,
        }


@dataclass
class Phone:
    gop: float
    dropped: bool
    intrusive: bool
    stressed: bool


@dataclass
class WordObs:
    row: dict
    status: str  # Dart status in the probe run (missed / notScored kept as is)
    phones: list[Phone]


def gop_of(score: int) -> float:
    return PROBE_LO + (PROBE_HI - PROBE_LO) * score / 100


def observe(rows: Iterable[dict]) -> list[WordObs]:
    """Parses a probe-run word CSV."""
    out = []
    for r in rows:
        phones = []
        if r["status"] not in ("missed", "notScored") and r["heard"]:
            exp = r["expected"].split()
            stress = r["stress"].split()
            for e, h, s, st in zip(
                exp, r["heard"].split(), r["phoneme_scores"].split(), stress, strict=True
            ):
                gop = gop_of(int(s))
                phones.append(
                    Phone(
                        gop=gop,
                        dropped=h == DROPPED,
                        intrusive=h == e + "ɹ" and gop >= 0,
                        stressed=st == "1",
                    )
                )
        out.append(WordObs(r, r["status"], phones))
    return out


def word_status(obs: WordObs, p: Params) -> tuple[str, int]:
    if not obs.phones:
        return obs.status, 0
    scores, weights = [], []
    for ph in obs.phones:
        if ph.dropped:
            s = p.dropped_score
        else:
            s = min(100, max(0, dart_round(interp(p.curve, ph.gop))))
            if ph.intrusive:
                s = min(s, p.intrusive_r_score)
        scores.append(s)
        weights.append(p.stressed_vowel_weight if ph.stressed else 1.0)
    mean = sum(s * w for s, w in zip(scores, weights, strict=True)) / sum(weights)
    score = min(100, max(0, dart_round(min(mean, min(scores) + p.word_max_above_worst))))
    status = "good" if score >= p.good else "close" if score >= p.close else "fix"
    return status, score


def simulate(words: list[WordObs], p: Params) -> list[dict]:
    """Word rows with `status` / `score` recomputed for [p]."""
    out = []
    for w in words:
        status, score = word_status(w, p)
        out.append({**w.row, "status": status, "score": str(score)})
    return out


def metrics(rows: list[dict], split: str | None) -> dict:
    sel = [r for r in rows if split is None or r["split"] == split]
    native = [r for r in sel if r["kind"] == "native" and r["status"] != "notScored"]
    targets = [r for r in sel if r["kind"] in ("swap", "sub") and r["is_target"] == "1"]
    n = len(native) or 1
    t = len(targets) or 1
    return {
        "red": sum(r["status"] in RED for r in native) / n,
        "amber": sum(r["status"] == "close" for r in native) / n,
        "detect": sum(r["status"] in RED for r in targets) / t,
        "detect_swap": _rate(targets, "swap"),
        "detect_sub": _rate(targets, "sub"),
    }


def _rate(targets: list[dict], kind: str) -> float:
    sel = [r for r in targets if r["kind"] == kind]
    return sum(r["status"] in RED for r in sel) / len(sel) if sel else 0.0


def shifted_curve(shift: float, scale: float, base=DEFAULT_CURVE) -> list[tuple[float, float]]:
    """[base] moved [shift] nats left (more lenient when > 0) and stretched by [scale]."""
    return [(round(x / scale - shift, 3), y) for x, y in base]


def candidates(
    shifts: Iterable[float] = (0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4),
    scales: Iterable[float] = (0.75, 1.0, 1.25, 1.5),
    caps: Iterable[float] = (40, 50, 60),
    r_scores: Iterable[int] = (45, 65, 100),
    dropped: Iterable[int] = (0, 40),
    weights: Iterable[float] = (1.5,),
) -> Iterable[Params]:
    for sh, sc, cap, rs, dr, wt in itertools.product(
        shifts, scales, caps, r_scores, dropped, weights
    ):
        yield Params(
            curve=shifted_curve(sh, sc),
            word_max_above_worst=cap,
            intrusive_r_score=rs,
            dropped_score=dr,
            stressed_vowel_weight=wt,
        )


def search(
    words: list[WordObs],
    params: Iterable[Params],
    split: str = "tune",
    max_red: float = 0.04,
) -> tuple[Params, dict, list[tuple[dict, Params]]]:
    """Best detection on [split] with native red <= [max_red]; ties -> less amber.
    Falls back to the lowest red when nothing meets the target."""
    tried = []
    for p in params:
        m = metrics(simulate(words, p), split)
        tried.append((m, p))
    ok = [t for t in tried if t[0]["red"] <= max_red]
    pool = ok or sorted(tried, key=lambda t: t[0]["red"])[:1]
    best = max(pool, key=lambda t: (round(t[0]["detect"], 4), -t[0]["amber"]))
    return best[1], best[0], tried


def agreement(sim_rows: list[dict], dart_rows: list[dict]) -> float:
    """Share of words where the simulation and a real Dart run agree on the colour."""
    key = lambda r: (r["item"], r["word_index"])  # noqa: E731
    dart = {key(r): r["status"] for r in dart_rows}
    both = [r for r in sim_rows if key(r) in dart]
    return sum(r["status"] == dart[key(r)] for r in both) / len(both) if both else 0.0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("probe-config")
    s = sub.add_parser("search")
    s.add_argument("probe_words", type=Path)
    s.add_argument("--out", type=Path, required=True)
    s.add_argument("--max-red", type=float, default=0.04)
    s.add_argument(
        "--extra", type=Path, help="JSON merged into the output config (e.g. extraAccepted)"
    )
    c = sub.add_parser("check", help="simulation vs a real Dart run with the same config")
    c.add_argument("probe_words", type=Path)
    c.add_argument("config", type=Path)
    c.add_argument("dart_words", type=Path)
    args = ap.parse_args(argv)
    if args.cmd == "probe-config":
        print(json.dumps(PROBE_CONFIG))
        return 0
    words = observe(read_csv(args.probe_words))
    if args.cmd == "check":
        cfg = json.loads(args.config.read_text())
        p = params_from_config(cfg)
        print(
            "simulation/Dart colour agreement: "
            f"{agreement(simulate(words, p), read_csv(args.dart_words)):.4f}"
        )
        return 0
    best, m, tried = search(words, candidates(), max_red=args.max_red)
    cfg = best.to_config()
    if args.extra:
        cfg.update(json.loads(args.extra.read_text()))
    args.out.write_text(json.dumps(cfg, ensure_ascii=False, indent=1))
    held = metrics(simulate(words, best), "heldout")
    print(
        json.dumps(
            {"tune": m, "heldout": held, "params": asdict(best), "tried": len(tried)}, indent=1
        )
    )
    return 0


def params_from_config(cfg: dict) -> Params:
    d = Params()
    return Params(
        curve=[(x, y) for x, y in cfg.get("calibration", d.curve)],
        stressed_vowel_weight=cfg.get("stressedVowelWeight", d.stressed_vowel_weight),
        word_max_above_worst=cfg.get("wordMaxAboveWorst", d.word_max_above_worst),
        intrusive_r_score=cfg.get("intrusiveRScore", d.intrusive_r_score),
        dropped_score=cfg.get("droppedScore", d.dropped_score),
        good=cfg.get("goodThreshold", d.good),
        close=cfg.get("closeThreshold", d.close),
    )


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
