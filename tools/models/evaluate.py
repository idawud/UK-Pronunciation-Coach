"""Verify and measure an exported tier: logits vs PyTorch, PER, size and CPU time.

    python -m tools.models.evaluate --model facebook/wav2vec2-lv-60-espeak-cv-ft \
        --release tools/models/release/full --work tools/models/work/full \
        --verify-clips tools/models/data/verify/manifest.tsv \
        --eval-clips tools/models/data/eval/manifest.tsv --ref-voice en-us

Writes <work>/report.json. Needs eSpeak NG for the PER references (see phonemes.py).
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import statistics
import sys
import time
from collections.abc import Callable, Sequence
from pathlib import Path

import numpy as np

from tools.models import export_onnx as ex
from tools.models import phonemes as ph
from tools.models.audio import load_audio, normalise


def read_manifest(path: Path, limit: int | None = None) -> list[dict]:
    """Rows of a clip manifest TSV (columns: id, path, speaker, text). Relative paths
    are resolved against the manifest's folder."""
    with path.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f, delimiter="\t"))
    for row in rows:
        p = Path(row["path"])
        row["path"] = str(p if p.is_absolute() else path.parent / p)
    return rows[:limit] if limit else rows


def spread(rows: Sequence[dict], n: int) -> list[dict]:
    """Up to [n] rows taken round-robin across speakers (so a subset mixes voices)."""
    by_speaker: dict[str, list[dict]] = {}
    for row in rows:
        by_speaker.setdefault(row.get("speaker", ""), []).append(row)
    queues = list(by_speaker.values())
    out: list[dict] = []
    while len(out) < n and any(queues):
        for q in queues:
            if q and len(out) < n:
                out.append(q.pop(0))
    return out


def log_softmax(x: np.ndarray) -> np.ndarray:
    """Row-wise log-softmax."""
    x = x - x.max(axis=-1, keepdims=True)
    return x - np.log(np.exp(x).sum(axis=-1, keepdims=True))


def compare_logits(reference: np.ndarray, candidate: np.ndarray) -> dict:
    """Closeness of two [frames, vocab] logit arrays: abs diffs of logits and
    log-probabilities, and how often the per-frame argmax agrees."""
    if reference.shape != candidate.shape:
        raise ValueError(f"shape {candidate.shape} != {reference.shape}")
    diff = np.abs(reference - candidate)
    lp_diff = np.abs(log_softmax(reference) - log_softmax(candidate))
    return {
        "max_abs": float(diff.max()),
        "mean_abs": float(diff.mean()),
        "max_abs_logprob": float(lp_diff.max()),
        "argmax_agree": float((reference.argmax(-1) == candidate.argmax(-1)).mean()),
    }


def summarise(per_clip: Sequence[dict]) -> dict:
    """Aggregate of compare_logits results over clips."""
    return {
        "clips": len(per_clip),
        "max_abs": max(c["max_abs"] for c in per_clip),
        "mean_abs": float(np.mean([c["mean_abs"] for c in per_clip])),
        "max_abs_logprob": max(c["max_abs_logprob"] for c in per_clip),
        "argmax_agree": float(np.mean([c["argmax_agree"] for c in per_clip])),
    }


def verify(model, sessions: dict, clips: Sequence[np.ndarray]) -> dict:
    """PyTorch vs each ONNX session (e.g. {"fp32": s1, "int8": s2}) on normalised clips."""
    out: dict[str, dict] = {}
    for name, sess in sessions.items():
        results = []
        for audio in clips:
            ref = ex.torch_logits(model, audio)
            results.append(compare_logits(ref, ex.onnx_logits(sess, audio)))
        out[name] = summarise(results)
    return out


def decode(logits: np.ndarray, vocab_tokens: Sequence[str], blank: int) -> list[str]:
    """Greedy CTC decode of [frames, vocab] logits to tokens (specials dropped)."""
    ids = ph.ctc_greedy(logits.argmax(-1).tolist(), blank)
    return [vocab_tokens[i] for i in ids if vocab_tokens[i] not in ph.SPECIALS]


def per_report(
    sess,
    vocab: dict[str, int],
    clips: Sequence[tuple[np.ndarray, str]],
    labeler: Callable[[str], list[str]],
) -> dict:
    """Strict and loose PER of an ONNX session on (normalised audio, transcript) pairs.

    `labeler(text)` returns reference vocab tokens (eSpeak in practice)."""
    tokens = ph.vocab_list(vocab)
    blank = ph.blank_index(vocab)
    pairs = []
    for audio, text in clips:
        hyp = decode(ex.onnx_logits(sess, audio), tokens, blank)
        pairs.append((labeler(text), hyp))
    loose = [(ph.normalise_for_per(r), ph.normalise_for_per(h)) for r, h in pairs]
    return {
        "clips": len(pairs),
        "ref_phonemes": sum(len(r) for r, _ in pairs),
        "per": round(ph.phoneme_error_rate(pairs), 4),
        "per_loose": round(ph.phoneme_error_rate(loose), 4),
        "example": {"ref": " ".join(pairs[0][0]), "hyp": " ".join(pairs[0][1])} if pairs else {},
    }


def benchmark(sess, seconds: float = 20.0, repeats: int = 3) -> float:
    """Median wall-clock seconds to run [seconds] of audio through [sess] (after a warm-up)."""
    rng = np.random.default_rng(0)
    audio = normalise(rng.standard_normal(int(16000 * seconds)).astype(np.float32))
    ex.onnx_logits(sess, audio)
    times = []
    for _ in range(repeats):
        t = time.perf_counter()
        ex.onnx_logits(sess, audio)
        times.append(time.perf_counter() - t)
    return round(statistics.median(times), 3)


def evaluate(
    model,
    vocab: dict[str, int],
    release_dir: Path,
    fp32_path: Path,
    verify_rows: Sequence[dict],
    eval_rows: Sequence[dict],
    labeler: Callable[[str], list[str]] | None,
    threads: Sequence[int] = (1, 4),
    bench_seconds: float = 20.0,
) -> dict:
    """Full report for one tier (see module docstring)."""
    int8_path = release_dir / "model.onnx"
    sessions = {"fp32": ex.session(fp32_path), "int8": ex.session(int8_path)}
    verify_audio = [normalise(load_audio(r["path"])) for r in verify_rows]
    report: dict = {
        "size_bytes": {"fp32": fp32_path.stat().st_size, "int8": int8_path.stat().st_size},
        "opset": ex.onnx_opset(int8_path),
        "vocab_size": len(vocab),
        "blank_index": ph.blank_index(vocab),
        "verify": verify(model, sessions, verify_audio) if verify_audio else {},
    }
    if eval_rows and labeler is not None:
        clips = [(normalise(load_audio(r["path"])), r["text"]) for r in eval_rows]
        report["per"] = {name: per_report(s, vocab, clips, labeler) for name, s in sessions.items()}
        report["eval_speakers"] = sorted({r.get("speaker", "") for r in eval_rows})
    report["cpu_seconds"] = {
        f"{name}_{n}_threads": benchmark(ex.session(p, n), bench_seconds)
        for name, p in (("fp32", fp32_path), ("int8", int8_path))
        for n in threads
    }
    report["bench_audio_seconds"] = bench_seconds
    report["cpu"] = f"{os.cpu_count()} logical CPUs ({os.uname().machine})"
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Verify an exported tier and report PER")
    parser.add_argument("--model", required=True, help="hub id or local HF model directory")
    parser.add_argument("--release", type=Path, required=True, help="tier release folder")
    parser.add_argument("--work", type=Path, required=True, help="tier work folder")
    parser.add_argument("--verify-clips", type=Path, help="manifest.tsv of logits-check clips")
    parser.add_argument("--verify-limit", type=int, default=20)
    parser.add_argument("--eval-clips", type=Path, help="manifest.tsv of held-out clips")
    parser.add_argument("--eval-limit", type=int)
    parser.add_argument("--ref-voice", default=ph.VOICE_RP, help="eSpeak voice for references")
    parser.add_argument("--bench-seconds", type=float, default=20.0)
    args = parser.parse_args(argv)

    model, vocab = ex.load_model(args.model)
    verify_rows = (
        spread(read_manifest(args.verify_clips), args.verify_limit) if args.verify_clips else []
    )
    eval_rows = read_manifest(args.eval_clips, args.eval_limit) if args.eval_clips else []
    vocab_set = set(vocab) - set(ph.SPECIALS)

    def labeler(text: str) -> list[str]:
        return ph.text_to_tokens(text, vocab_set, args.ref_voice)

    report = evaluate(
        model,
        vocab,
        args.release,
        args.work / "model.fp32.onnx",
        verify_rows,
        eval_rows,
        labeler if eval_rows else None,
        bench_seconds=args.bench_seconds,
    )
    report["ref_voice"] = args.ref_voice
    report["model"] = str(args.model)
    args.work.mkdir(parents=True, exist_ok=True)
    (args.work / "report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
