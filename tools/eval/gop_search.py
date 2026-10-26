"""GOP research: re-scores harness runs offline with other GOP formulas, per-phoneme
offsets and word-score settings, to search for a stricter scorer that still leaves
native speech alone.

Input: a harness run with `EVAL_FEATURES=1` (`features_<config>.csv` + `words_<config>.csv`
from `tools/eval/dart/run_eval_test.dart`) for the synthetic set and for the native
VCTK set. Each phoneme row carries the expected sound's mean log-posterior over its
aligned frames and its peak over the extended span, plus the 10 best competing phones
(`symbol:mean:peak`). This module recomputes, without re-running Dart:

* the GOP (`gop_values`):
  - `mean`: expected mean minus the best competitor's mean (the Dart scorer's GOP);
  - `peak`: expected peak minus the best competitor's peak over the extended span;
  - both with a *confusion-aware* competitor (`delta` > 0): competitors outside the
    phoneme's learner-confusion set (`CONFUSIONS`) are handicapped by `delta` nats,
    so a typical learner substitution counts fully and arbitrary model noise less;
* per-phoneme offsets (`phoneme_offsets`): each sound's GOP on correct tuning speech
  (native VCTK + clean synthetic reads) relative to all sounds, at a low quantile,
  shrunk towards 0 for rare sounds; subtracted before the curve, as
  `ScoringConfig.phonemeGopOffset` does in Dart;
* word scores and colours exactly as `GopPronunciationScorer` does (curve, stressed
  weight, cap above the worst sound, dropped and intrusive-r scores, thresholds).

The search picks the best synthetic TUNING-voice kappa subject to native false red on
the VCTK TUNING speakers <= --max-red and clean-read false red on the tuning voices
<= --max-clean-red; held-out voices and speakers are only reported.

    python -m tools.eval.gop_search \\
        --synth tools/eval/work/feat_synth --native tools/eval/work/feat_native \\
        --labels tools/eval/data/synth/labels.complete.csv --out tuned.json
"""

from __future__ import annotations

import argparse
import csv
import itertools
import json
import sys
from collections.abc import Iterable, Sequence
from dataclasses import asdict, dataclass, field
from pathlib import Path

import numpy as np

from tools.eval.analyse import RED

DROPPED = "∅"
NCOMP = 10

# Learner confusions: expected British sound -> model symbols a learner typically
# says instead (tips_table.dart, docs/eval-report.md). Accepted symbols never count.
CONFUSIONS: dict[str, tuple[str, ...]] = {
    "θ": ("t", "f", "s", "d"),
    "ð": ("d", "z", "v", "t"),
    "v": ("w", "f", "b"),
    "w": ("v", "ʋ"),
    "ʃ": ("s", "tʃ"),
    "ʒ": ("z", "dʒ", "ʃ"),
    "s": ("z", "ʃ", "θ"),
    "z": ("s",),
    "ɪ": ("iː", "i"),
    "iː": ("ɪ",),
    "i": ("ɪ",),
    "æ": ("ɛ", "e", "ʌ", "ɑː", "a"),
    "ɛ": ("æ", "ɪ", "eɪ"),
    "e": ("æ", "ɪ", "eɪ"),
    "ʌ": ("æ", "ɒ", "ɑː", "ɔ", "ʊ", "a"),
    "ɐ": ("æ", "ɒ", "ɑː", "ɔ", "ʊ", "a"),
    "ɑː": ("æ", "ʌ", "a"),
    "ɒ": ("ɑː", "ɔː", "ɑ", "oʊ", "ʌ"),
    "ɔː": ("ɒ", "oʊ", "ɑː"),
    "ɜː": ("ɛ", "ɑː", "e", "ɔː"),
    "ʊ": ("uː", "u", "ʌ"),
    "uː": ("ʊ",),
    "əʊ": ("ɔː", "ɒ", "oː"),
    "eɪ": ("ɛ", "e", "iː"),
    "p": ("b",),
    "b": ("p", "v"),
    "t": ("d", "θ"),
    "d": ("t", "ð"),
    "k": ("ɡ",),
    "ɡ": ("k",),
    "f": ("v", "p", "θ"),
    "h": ("x",),
    "l": ("ɹ", "n"),
    "ɹ": ("l", "w"),
    "n": ("ŋ", "l"),
    "ŋ": ("n", "ŋɡ"),
    "tʃ": ("ʃ", "dʒ"),
    "dʒ": ("ʒ", "j", "tʃ"),
    "j": ("dʒ",),
}

PROBE_CURVE = [(-6.8, 0), (-4.4, 10), (-2.8, 30), (-2, 50), (-1.2, 65), (-0.4, 78), (0.4, 86),
               (2, 95), (4.4, 100)]  # fmt: skip


@dataclass
class Settings:
    """One scorer variant (the `ScoringConfig` fields it maps to in brackets)."""

    gop: str = "mean"  # mean | peak
    delta: float = 0.0  # confusion-aware handicap of other competitors (nats)
    curve: list[tuple[float, float]] = field(default_factory=lambda: list(PROBE_CURVE))
    offsets: dict[str, float] = field(default_factory=dict)  # [phonemeGopOffset]
    stressed_weight: float = 1.5  # [stressedVowelWeight]
    cap: float = 40  # [wordMaxAboveWorst]
    dropped: int = 60  # [droppedScore]
    dropped_strict: int | None = None  # [droppedStrictScore] (None: same as dropped)
    intrusive: int = 80  # [intrusiveRScore]
    good: int = 80
    close: int = 60


@dataclass
class Data:
    """Phoneme and word arrays of one harness run."""

    word_key: list[tuple[str, str]]  # (item, word_index) per word
    word_rows: list[dict]  # the harness word rows
    word_fixed: np.ndarray  # word status forced: 0 none, 1 red (missed), 2 notScored
    ph_word: np.ndarray  # word id per phoneme
    ph_sym: list[str]  # expected sound per phoneme
    ph_stress: np.ndarray
    ph_dropped: np.ndarray
    ph_strict: np.ndarray  # a drop here is not normal elision (see strict_drop_context)
    ph_intrusive: np.ndarray
    exp_mean: np.ndarray
    exp_peak: np.ndarray
    comp_sym: np.ndarray  # object array (n, NCOMP) of symbols ('' = none)
    comp_mean: np.ndarray  # (n, NCOMP), -inf = none
    comp_peak: np.ndarray


def read_csv(path: Path) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


VOWELS = frozenset(
    "ɪ ɛ e æ ʌ ɒ ʊ ə ɐ i u iː ɑː ɔː uː ɜː eɪ aɪ ɔɪ əʊ oʊ aʊ ɪə eə ɛə ɛː ʊə".split()
)
PUNCTUATION = frozenset(".,;:!?")


def strict_drop_context(
    phonemes: Sequence[str], p: int, next_word: Sequence[str] | None, pause_after: bool
) -> bool:
    """True when leaving out sound [p] of a word is not normal connected-speech
    elision: a word-final consonant before a vowel, a pause or the end, or a
    word-initial h (weak function words without h are alternatives)."""
    sym = phonemes[p]
    if p == 0 and sym == "h":
        return True
    if p != len(phonemes) - 1 or sym in VOWELS:
        return False
    return pause_after or not next_word or next_word[0] in VOWELS


def pauses(passages: Path | None) -> dict[str, set[int]]:
    """passage id -> indexes of words followed by punctuation."""
    if passages is None or not passages.exists():
        return {}
    out: dict[str, set[int]] = {}
    for p in json.loads(passages.read_text(encoding="utf-8")):
        ws = p["words"]
        for a, b in itertools.pairwise(ws):
            if a.get("offset") is None or b.get("offset") is None:
                continue
            gap = p["text"][a["offset"] + len(a["text"]) : b["offset"]]
            if PUNCTUATION & set(gap):
                out.setdefault(p["id"], set()).add(a["index"])
    return out


def load(run: Path, config: str = "default", passages: Path | None = None) -> Data:
    """Reads `words_<config>.csv` and `features_<config>.csv` from [run];
    [passages] (the run's passages.json) marks pauses at punctuation."""
    words = read_csv(run / f"words_{config}.csv")
    feats = read_csv(run / f"features_{config}.csv")
    index = {(w["item"], w["word_index"]): i for i, w in enumerate(words)}
    fixed = np.zeros(len(words), dtype=np.int8)
    for i, w in enumerate(words):
        if w["status"] == "notScored":
            fixed[i] = 2
        elif w["status"] == "missed":
            fixed[i] = 1
    have = np.zeros(len(words), dtype=bool)
    stops = pauses(passages)
    n = len(feats)
    strict = np.zeros(n, dtype=bool)
    ph_word = np.zeros(n, dtype=np.int64)
    stress = np.zeros(n, dtype=bool)
    dropped = np.zeros(n, dtype=bool)
    intrusive = np.zeros(n, dtype=bool)
    exp_mean = np.zeros(n)
    exp_peak = np.zeros(n)
    comp_sym = np.full((n, NCOMP), "", dtype=object)
    comp_mean = np.full((n, NCOMP), -np.inf)
    comp_peak = np.full((n, NCOMP), -np.inf)
    syms = []
    for k, f in enumerate(feats):
        wi = index[(f["item"], f["word_index"])]
        have[wi] = True
        ph_word[k] = wi
        syms.append(f["expected"])
        stress[k] = f["stress"] == "1"
        row = words[wi]
        nxt = words[wi + 1] if wi + 1 < len(words) else None
        same = nxt is not None and nxt["item"] == row["item"] and nxt["expected"]
        strict[k] = strict_drop_context(
            row["expected"].split(),
            int(f["phoneme_index"]),
            nxt["expected"].split() if same else None,
            int(row["word_index"]) in stops.get(row["passage"], set()),
        )
        dropped[k] = f["heard"] == DROPPED
        intrusive[k] = f["heard"] == f["expected"] + "ɹ"
        exp_mean[k] = float(f["exp_mean"])
        exp_peak[k] = float(f["exp_peak"])
        for j, c in enumerate(filter(None, f["competitors"].split("|"))):
            s, m, p = c.rsplit(":", 2)
            comp_sym[k, j], comp_mean[k, j], comp_peak[k, j] = s, float(m), float(p)
    # Words scored by Dart but without feature rows (should not happen) keep Dart's
    # colour: mark them fixed red / green.
    for i, w in enumerate(words):
        if fixed[i] == 0 and not have[i]:
            fixed[i] = 1 if w["status"] in RED else 3
    return Data(
        word_key=[(w["item"], w["word_index"]) for w in words],
        word_rows=words,
        word_fixed=fixed,
        ph_word=ph_word,
        ph_sym=syms,
        ph_stress=stress,
        ph_dropped=dropped,
        ph_strict=strict,
        ph_intrusive=intrusive,
        exp_mean=exp_mean,
        exp_peak=exp_peak,
        comp_sym=comp_sym,
        comp_mean=comp_mean,
        comp_peak=comp_peak,
    )


def confusion_mask(d: Data) -> np.ndarray:
    """True where a competitor is in its phoneme's confusion set."""
    mask = np.zeros(d.comp_sym.shape, dtype=bool)
    for k, e in enumerate(d.ph_sym):
        conf = CONFUSIONS.get(e)
        if conf:
            mask[k] = [s in conf for s in d.comp_sym[k]]
    return mask


def gop_values(d: Data, s: Settings, mask: np.ndarray | None = None) -> np.ndarray:
    """GOP per phoneme for [s]'s formula."""
    exp, comp = (d.exp_mean, d.comp_mean) if s.gop == "mean" else (d.exp_peak, d.comp_peak)
    if s.delta:
        mask = confusion_mask(d) if mask is None else mask
        comp = np.where(mask, comp, comp - s.delta)
    best = comp.max(axis=1)
    best = np.where(np.isfinite(best), best, exp - 10)
    return exp - best


def phoneme_offsets(
    gops: Iterable[tuple[str, float]], quantile: float = 0.1, shrink: float = 20
) -> dict[str, float]:
    """Per-sound GOP offset: (sound's quantile - all sounds' quantile) * n / (n + shrink)."""
    by: dict[str, list[float]] = {}
    for sym, g in gops:
        by.setdefault(sym, []).append(g)
    allv = np.array([g for v in by.values() for g in v])
    if allv.size == 0:
        return {}
    ref = float(np.quantile(allv, quantile))
    return {
        sym: round((float(np.quantile(v, quantile)) - ref) * len(v) / (len(v) + shrink), 2)
        for sym, v in sorted(by.items())
    }


def dart_round(x: np.ndarray) -> np.ndarray:
    return np.where(x >= 0, np.floor(x + 0.5), -np.floor(-x + 0.5))


def word_status(d: Data, s: Settings, gop: np.ndarray) -> np.ndarray:
    """Word statuses ('good' / 'close' / 'fix' / 'missed' / 'notScored') for [s]."""
    off = np.array([s.offsets.get(e, 0.0) for e in d.ph_sym]) if s.offsets else 0.0
    xs, ys = zip(*s.curve, strict=True)
    score = np.clip(dart_round(np.interp(gop - off, xs, ys)), 0, 100)
    score = np.where(d.ph_intrusive, np.minimum(score, s.intrusive), score)
    strict = s.dropped if s.dropped_strict is None else s.dropped_strict
    score = np.where(d.ph_dropped, np.where(d.ph_strict, strict, s.dropped), score)
    w = np.where(d.ph_stress, s.stressed_weight, 1.0)
    nw = len(d.word_rows)
    tot = np.bincount(d.ph_word, weights=score * w, minlength=nw)
    wt = np.bincount(d.ph_word, weights=w, minlength=nw)
    worst = np.full(nw, 100.0)
    np.minimum.at(worst, d.ph_word, score)
    mean = np.divide(tot, wt, out=np.full(nw, 100.0), where=wt > 0)
    ws = np.clip(dart_round(np.minimum(mean, worst + s.cap)), 0, 100)
    out = np.where(ws >= s.good, "good", np.where(ws >= s.close, "close", "fix")).astype(object)
    out[d.word_fixed == 1] = "missed"
    out[d.word_fixed == 2] = "notScored"
    out[d.word_fixed == 3] = "good"
    return out


@dataclass
class Labels:
    """Synthetic labels by (item, word_index)."""

    rows: dict[tuple[str, str], dict]

    @classmethod
    def read(cls, path: Path) -> Labels:
        return cls({(r["item"], r["word_index"]): r for r in read_csv(path)})


def label_arrays(d: Data, labels: Labels) -> dict[str, np.ndarray]:
    """Per word of [d]: labelled, wrong, split and clean-read flags (cached on [d])."""
    cache = getattr(d, "_labels", None)
    if cache is not None and cache[0] is labels:
        return cache[1]
    rows = [labels.rows.get(k) for k in d.word_key]
    arr = {
        "has": np.array([r is not None for r in rows]),
        "wrong": np.array([r is not None and r["label"] == "wrong" for r in rows]),
        "clean": np.array([r is not None and r["read"] == "clean" for r in rows]),
        "split": np.array([r["split"] if r else "" for r in rows], dtype=object),
    }
    d._labels = (labels, arr)  # type: ignore[attr-defined]
    return arr


def synth_metrics(d: Data, status: np.ndarray, labels: Labels, split: str) -> dict:
    """Agreement, kappa, recall, false red and clean-read false red on [split]."""
    a = label_arrays(d, labels)
    sel = a["has"] & (status != "notScored")
    if split != "all":
        sel &= a["split"] == split
    red = np.isin(status, list(RED))
    wrong = a["wrong"]
    tp = int((sel & wrong & red).sum())
    fn = int((sel & wrong & ~red).sum())
    fp = int((sel & ~wrong & red).sum())
    tn = int((sel & ~wrong & ~red).sum())
    clean = sel & ~wrong & a["clean"]
    n_clean = int(clean.sum())
    return _metrics(tp, fp, fn, tn) | {
        "clean_false_red": int((clean & red).sum()) / n_clean if n_clean else 0.0
    }


def _metrics(tp: int, fp: int, fn: int, tn: int) -> dict:
    n = tp + fp + fn + tn
    if not n:
        return {"words": 0, "agreement": 0.0, "kappa": 0.0, "recall": 0.0, "false_red": 0.0}
    po = (tp + tn) / n
    pe = ((tp + fp) * (tp + fn) + (fn + tn) * (fp + tn)) / n / n
    return {
        "words": n,
        "agreement": po,
        "kappa": (po - pe) / (1 - pe) if pe < 1 else 0.0,
        "recall": tp / (tp + fn) if tp + fn else 0.0,
        "false_red": fp / (fp + tn) if fp + tn else 0.0,
    }


def native_red(d: Data, status: np.ndarray, split: str) -> float:
    sel = np.array(
        [r["kind"] == "native" and (split == "all" or r["split"] == split) for r in d.word_rows],
        dtype=bool,
    ) & (status != "notScored")
    n = int(sel.sum())
    return int((sel & np.isin(status, list(RED))).sum()) / n if n else 0.0


def correct_gops(
    synth: Data, native: Data, labels: Labels, s: Settings, split: str = "tune"
) -> list[tuple[str, float]]:
    """(sound, GOP) of every sound in correct [split] speech: native words and clean
    synthetic reads; dropped sounds excluded."""
    out = []
    for d, ok in (
        (native, lambda r: r["kind"] == "native" and r["split"] == split),
        (
            synth,
            lambda r: (lab := labels.rows.get((r["item"], r["word_index"]))) is not None
            and lab["split"] == split
            and lab["read"] == "clean",
        ),
    ):
        g = gop_values(d, s)
        good_word = np.array([ok(r) for r in d.word_rows], dtype=bool)
        sel = good_word[d.ph_word] & ~d.ph_dropped
        out += [(d.ph_sym[k], float(g[k])) for k in np.flatnonzero(sel)]
    return out


def evaluate(synth: Data, native: Data, labels: Labels, s: Settings) -> dict:
    """Every metric for [s], tuning and held-out."""
    ss = word_status(synth, s, gop_values(synth, s))
    ns = word_status(native, s, gop_values(native, s))
    out = {}
    for split in ("tune", "heldout"):
        for k, v in synth_metrics(synth, ss, labels, split).items():
            out[f"{k}_{split}"] = v
        out[f"native_red_{split}"] = native_red(native, ns, split)
    return out


def shifted(curve: Sequence[tuple[float, float]], shift: float, scale: float = 1.0):
    """[curve] moved [shift] nats right (stricter when > 0) and stretched by [scale]
    around GOP 0."""
    return [(round(x * scale + shift, 3), y) for x, y in curve]


def search(
    synth: Data,
    native: Data,
    labels: Labels,
    grid: Iterable[Settings],
    max_red: float,
    max_clean_red: float,
) -> tuple[Settings | None, dict, int]:
    """Best tuning kappa under the native and clean-read false-red caps."""
    best, best_k, n = None, -2.0, 0
    for s in grid:
        n += 1
        ns = word_status(native, s, gop_values(native, s))
        if native_red(native, ns, "tune") > max_red:
            continue
        m = synth_metrics(synth, word_status(synth, s, gop_values(synth, s)), labels, "tune")
        if m["clean_false_red"] > max_clean_red:
            continue
        if m["kappa"] > best_k:
            best, best_k = s, m["kappa"]
    return best, (evaluate(synth, native, labels, best) if best else {}), n


def grid(
    synth: Data,
    native: Data,
    labels: Labels,
    gops: Sequence[str] = ("mean", "peak"),
    deltas: Sequence[float] = (0, 1, 2, 4),
    quantiles: Sequence[float | None] = (None, 0.05, 0.1, 0.25),
    shifts: Sequence[float] = (-1, 0, 1, 2, 3, 4, 5),
    scales: Sequence[float] = (0.75, 1.0, 1.5),
    caps: Sequence[float] = (30, 40, 50),
    dropped: Sequence[int] = (40, 60),
    intrusive: Sequence[int] = (65, 80),
) -> Iterable[Settings]:
    """Search grid; offsets are re-estimated per GOP formula on tuning speech only."""
    for g, dl, q in itertools.product(gops, deltas, quantiles):
        base = Settings(gop=g, delta=dl)
        off = (
            {}
            if q is None
            else phoneme_offsets(correct_gops(synth, native, labels, base), quantile=q)
        )
        for sh, sc, cap, dr, ir in itertools.product(shifts, scales, caps, dropped, intrusive):
            yield Settings(
                gop=g,
                delta=dl,
                curve=shifted(PROBE_CURVE, sh, sc),
                offsets=off,
                cap=cap,
                dropped=dr,
                intrusive=ir,
            )


def to_config(s: Settings) -> dict:
    """The `ScoringConfig` JSON subset for [s] (GOP formula `mean` only)."""
    return {
        "calibration": [[x, y] for x, y in s.curve],
        "phonemeGopOffset": s.offsets,
        "stressedVowelWeight": s.stressed_weight,
        "wordMaxAboveWorst": s.cap,
        "droppedScore": s.dropped,
        "intrusiveRScore": s.intrusive,
        "goodThreshold": s.good,
        "closeThreshold": s.close,
    }


def main(argv: list[str] | None = None) -> int:  # pragma: no cover - CLI wiring
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--synth", type=Path, required=True)
    ap.add_argument("--native", type=Path, required=True)
    ap.add_argument("--labels", type=Path, required=True)
    ap.add_argument("--config", default="default")
    ap.add_argument("--max-red", type=float, default=0.035)
    ap.add_argument("--max-clean-red", type=float, default=0.035)
    ap.add_argument("--gops", default="mean,peak")
    ap.add_argument("--out", type=Path)
    args = ap.parse_args(argv)
    synth = load(args.synth, args.config)
    native = load(args.native, args.config)
    labels = Labels.read(args.labels)
    current = evaluate(synth, native, labels, Settings())
    print(json.dumps({"current": current}, indent=1))
    best, m, n = search(
        synth,
        native,
        labels,
        grid(synth, native, labels, gops=args.gops.split(",")),
        args.max_red,
        args.max_clean_red,
    )
    print(json.dumps({"best": m, "tried": n}, indent=1))
    if best is not None:
        print(json.dumps(asdict(best), ensure_ascii=False))
        if args.out:
            args.out.write_text(json.dumps(to_config(best), ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
