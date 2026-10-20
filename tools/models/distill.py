"""Light tier without a GPU: distil the full model into a layer-dropped copy on CPU.

The teacher is the full tier (facebook/wav2vec2-lv-60-espeak-cv-ft, Apache-2.0). The
student keeps the teacher's conv feature encoder, feature projection, positional conv and
CTC head, plus a few of its 24 transformer layers (initialised from the teacher). It is
trained to match the teacher's per-frame posteriors (KL divergence), so it needs no
hand labels and keeps the full 392-token vocab with the same token strings: A2 loads it
like the full tier and A3's mapping table and I2's calibration apply unchanged.

CPU tricks that make this feasible on a laptop:
  * the conv feature encoder is frozen, so its output is computed once per clip (by the
    teacher pass) and cached as float16; training never touches raw audio;
  * the teacher's log-posteriors are cached once as float16 next to the features;
  * batches are bucketed by length with a frame budget; checkpoints are written every
    `--ckpt-minutes` and training resumes from the last one after an interruption.

    # 1. teacher pass (features + log-posteriors) for training and held-out clips
    python -m tools.models.distill prepare --teacher <full HF dir> \
        --manifest data/train/manifest.tsv --cache work/cache-train
    # 2. (optional) compare layer choices before training
    python -m tools.models.distill init-check --teacher <dir> --cache work/cache-eval \
        --candidates "0,4,9,14,19,23" "18,19,20,21,22,23"
    # 3. train; prints a timing estimate after the first steps
    python -m tools.models.distill train --teacher <dir> --cache work/cache-train \
        --eval-cache work/cache-eval --out work/student --keep-layers 0,4,9,14,19,23 \
        --hours 12
    # 4. export: python -m tools.models.export_onnx --model work/student/hf ...
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
import time
from collections.abc import Callable, Sequence
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F

from tools.models import phonemes as ph
from tools.models.audio import load_audio, normalise
from tools.models.evaluate import read_manifest

DEFAULT_THREADS = 4
CKPT = "checkpoint.pt"


# --------------------------------------------------------------------------- models


def load_teacher(path: str | Path):
    """(Wav2Vec2ForCTC in eval mode, vocab) from a local HF directory with vocab.json."""
    from transformers import Wav2Vec2ForCTC

    model = Wav2Vec2ForCTC.from_pretrained(str(path)).eval()
    vocab = ph.load_vocab(Path(path) / "vocab.json")
    if len(vocab) != model.config.vocab_size:
        raise ValueError(f"vocab.json has {len(vocab)} tokens, model has {model.config.vocab_size}")
    return model, vocab


def parse_layers(spec: str) -> tuple[int, ...]:
    """`0,4,9` -> (0, 4, 9); must be strictly increasing."""
    layers = tuple(int(x) for x in spec.split(",") if x.strip())
    if not layers or list(layers) != sorted(set(layers)):
        raise ValueError(f"layer list must be non-empty and increasing: {spec!r}")
    return layers


def make_student(
    teacher,
    keep_layers: Sequence[int],
    dropout: float = 0.05,
    mask_time_prob: float = 0.05,
):
    """A Wav2Vec2ForCTC with the teacher's layers [keep_layers] (and every non-layer
    weight) copied over. Feature encoder frozen; layerdrop off."""
    from transformers import Wav2Vec2ForCTC

    n = teacher.config.num_hidden_layers
    if any(not 0 <= i < n for i in keep_layers):
        raise ValueError(f"layers must be in 0..{n - 1}: {list(keep_layers)}")
    config = teacher.config.__class__.from_dict(teacher.config.to_dict())
    config.num_hidden_layers = len(keep_layers)
    config.layerdrop = 0.0
    config.hidden_dropout = config.attention_dropout = config.feat_proj_dropout = dropout
    config.activation_dropout = config.final_dropout = 0.0
    config.mask_time_prob = mask_time_prob
    config.mask_time_min_masks = 0
    config.mask_feature_prob = 0.0
    config.distill_keep_layers = list(keep_layers)
    student = Wav2Vec2ForCTC(config)
    state = {}
    prefix = "wav2vec2.encoder.layers."
    for key, value in teacher.state_dict().items():
        if key.startswith(prefix):
            idx, rest = key[len(prefix) :].split(".", 1)
            if int(idx) not in keep_layers:
                continue
            key = f"{prefix}{list(keep_layers).index(int(idx))}.{rest}"
        state[key] = value.clone()
    if "wav2vec2.masked_spec_embed" not in student.state_dict():
        state.pop("wav2vec2.masked_spec_embed", None)
    missing, unexpected = student.load_state_dict(state, strict=False)
    # masked_spec_embed only exists when SpecAugment is configured; keep its fresh init
    if unexpected or set(missing) - {"wav2vec2.masked_spec_embed"}:
        raise ValueError(f"state mismatch: missing {missing}, unexpected {unexpected}")
    student.freeze_feature_encoder()
    return student


def count_params(model) -> int:
    return sum(p.numel() for p in model.parameters())


def conv_features(model, audio: np.ndarray) -> torch.Tensor:
    """Frozen conv feature-encoder output [1, frames, conv_dim] for one normalised clip."""
    x = torch.from_numpy(np.asarray(audio, dtype=np.float32))[None]
    return model.wav2vec2.feature_extractor(x).transpose(1, 2)


def logits_from_features(model, feats: torch.Tensor, frame_mask: torch.Tensor | None = None):
    """Wav2Vec2ForCTC forward starting after the conv feature encoder (same maths as
    `model(input_values).logits`; SpecAugment time masking applies in train mode)."""
    w = model.wav2vec2
    hidden, _ = w.feature_projection(feats)
    hidden = w._mask_hidden_states(hidden, attention_mask=frame_mask)
    hidden = w.encoder(hidden, attention_mask=frame_mask).last_hidden_state
    return model.lm_head(model.dropout(hidden))


# --------------------------------------------------------------------------- cache


class FrameCache:
    """Append-only on-disk store of per-clip conv features and teacher log-posteriors.

    Files: `index.jsonl` (one line per clip: id, frames, offset), `feats.f16` and
    `logp.f16` (float16, row-major, concatenated). A clip is complete once its index line
    is written; `open()` truncates any half-written tail, so an interrupted `prepare`
    resumes cleanly.
    """

    def __init__(self, root: Path, feat_dim: int | None = None, vocab_size: int | None = None):
        self.root = Path(root)
        meta_path = self.root / "meta.json"
        if meta_path.exists():
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        else:
            if feat_dim is None or vocab_size is None:
                raise FileNotFoundError(f"no frame cache at {self.root}")
            self.root.mkdir(parents=True, exist_ok=True)
            meta = {"feat_dim": feat_dim, "vocab_size": vocab_size}
            meta_path.write_text(json.dumps(meta), encoding="utf-8")
        self.feat_dim = meta["feat_dim"]
        self.vocab_size = meta["vocab_size"]
        self.entries: list[dict] = []
        index = self.root / "index.jsonl"
        if index.exists():
            for line in index.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    try:
                        self.entries.append(json.loads(line))
                    except json.JSONDecodeError:  # torn last line
                        break
        total = sum(e["frames"] for e in self.entries)
        for name, dim in (("feats.f16", self.feat_dim), ("logp.f16", self.vocab_size)):
            path = self.root / name
            path.touch()
            if path.stat().st_size != total * dim * 2:
                os.truncate(path, total * dim * 2)
        index.write_text("".join(json.dumps(e) + "\n" for e in self.entries), encoding="utf-8")
        self._feats = self._logp = None

    def __len__(self) -> int:
        return len(self.entries)

    @property
    def ids(self) -> set[str]:
        return {e["id"] for e in self.entries}

    @property
    def frames(self) -> int:
        return sum(e["frames"] for e in self.entries)

    def append(self, clip_id: str, feats: np.ndarray, logp: np.ndarray, **extra) -> None:
        if feats.shape[0] != logp.shape[0]:
            raise ValueError(f"{clip_id}: {feats.shape[0]} feature frames != {logp.shape[0]}")
        offset = self.frames
        with (self.root / "feats.f16").open("ab") as f:
            f.write(np.ascontiguousarray(feats, dtype=np.float16).tobytes())
        with (self.root / "logp.f16").open("ab") as f:
            f.write(np.ascontiguousarray(logp, dtype=np.float16).tobytes())
        entry = {"id": clip_id, "frames": int(feats.shape[0]), "offset": offset, **extra}
        with (self.root / "index.jsonl").open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry) + "\n")
        self.entries.append(entry)
        self._feats = self._logp = None

    def _maps(self):
        if self._feats is None:
            n = self.frames
            self._feats = np.memmap(
                self.root / "feats.f16", np.float16, "r", shape=(n, self.feat_dim)
            )
            self._logp = np.memmap(
                self.root / "logp.f16", np.float16, "r", shape=(n, self.vocab_size)
            )
        return self._feats, self._logp

    def get(self, i: int) -> tuple[np.ndarray, np.ndarray]:
        """(features [frames, feat_dim], teacher log-probs [frames, vocab]) as float32."""
        feats, logp = self._maps()
        e = self.entries[i]
        sl = slice(e["offset"], e["offset"] + e["frames"])
        return np.asarray(feats[sl], np.float32), np.asarray(logp[sl], np.float32)


def prepare(
    teacher,
    rows: Sequence[dict],
    cache: FrameCache,
    log: Callable[[str], None] = print,
) -> int:
    """Runs the teacher once per clip (one clip at a time, no padding, as on device)
    and caches conv features + log-posteriors. Skips clips already cached; returns the
    number of clips added."""
    done = cache.ids
    todo = [r for r in rows if r["id"] not in done]
    t0, audio_s = time.time(), 0.0
    for n, row in enumerate(todo, 1):
        audio = normalise(load_audio(row["path"]))
        with torch.no_grad():
            feats = conv_features(teacher, audio)
            logp = torch.log_softmax(logits_from_features(teacher, feats), -1)
        cache.append(row["id"], feats[0].numpy(), logp[0].numpy(), speaker=row.get("speaker"))
        audio_s += audio.size / 16000
        if n % 100 == 0 or n == len(todo):
            el = time.time() - t0
            log(
                f"prepare {n}/{len(todo)} clips, {audio_s / 3600:.2f} h audio in "
                f"{el / 3600:.2f} h (RTF {el / max(audio_s, 1e-9):.2f})"
            )
    return len(todo)


# --------------------------------------------------------------------------- training


def frame_batches(lengths: Sequence[int], max_frames: int, rng: random.Random) -> list:
    """Shuffled batches of clip indices whose padded size (clips x longest) stays within
    [max_frames]; clips are sorted by length inside chunks to cut padding."""
    order = list(range(len(lengths)))
    rng.shuffle(order)
    out: list[list[int]] = []
    chunk = 2000
    for start in range(0, len(order), chunk):
        part = sorted(order[start : start + chunk], key=lambda i: lengths[i])
        batch: list[int] = []
        for i in part:
            if batch and (len(batch) + 1) * lengths[i] > max_frames:
                out.append(batch)
                batch = []
            batch.append(i)
        if batch:
            out.append(batch)
    rng.shuffle(out)
    return out


def collate_frames(items: Sequence[tuple[np.ndarray, np.ndarray]]):
    """Zero-padded feats [B,T,C], teacher log-probs [B,T,V] and a bool frame mask [B,T]."""
    t = max(f.shape[0] for f, _ in items)
    feats = torch.zeros(len(items), t, items[0][0].shape[1])
    logp = torch.zeros(len(items), t, items[0][1].shape[1])
    mask = torch.zeros(len(items), t, dtype=torch.bool)
    for i, (f, lp) in enumerate(items):
        feats[i, : f.shape[0]] = torch.from_numpy(f)
        logp[i, : lp.shape[0]] = torch.from_numpy(lp)
        mask[i, : f.shape[0]] = True
    return feats, logp, mask


def distill_loss(
    student_logits: torch.Tensor,
    teacher_logp: torch.Tensor,
    mask: torch.Tensor,
    temperature: float = 1.0,
    ctc_weight: float = 0.0,
    blank: int = 0,
) -> tuple[torch.Tensor, dict]:
    """Mean per-frame KL(teacher || student) over valid frames (x T^2 when softened),
    plus optional CTC on the teacher's greedy labels."""
    s = torch.log_softmax(student_logits / temperature, -1)
    t = torch.log_softmax(teacher_logp / temperature, -1)
    kl = (t.exp() * (t - s)).sum(-1)
    kl = (kl * mask).sum() / mask.sum().clamp(min=1) * temperature**2
    loss = kl
    parts = {"kl": float(kl.detach())}
    if ctc_weight > 0:
        labels = [
            ph.ctc_greedy(teacher_logp[i, m].argmax(-1).tolist(), blank) for i, m in enumerate(mask)
        ]
        targets = torch.tensor([x for seq in labels for x in seq], dtype=torch.long)
        lp = torch.log_softmax(student_logits, -1).transpose(0, 1)
        ctc = F.ctc_loss(
            lp,
            targets,
            mask.sum(1),
            torch.tensor([len(seq) for seq in labels]),
            blank=blank,
            zero_infinity=True,
        )
        loss = loss + ctc_weight * ctc
        parts["ctc"] = float(ctc.detach())
    return loss, parts


def lr_at(step: int, total: int, warmup: int, peak: float, floor: float = 0.05) -> float:
    """Linear warm-up, then cosine decay to [floor] x peak."""
    if step < warmup:
        return peak * (step + 1) / warmup
    progress = min(1.0, (step - warmup) / max(1, total - warmup))
    return peak * (floor + (1 - floor) * 0.5 * (1 + math.cos(math.pi * progress)))


def compare_to_teacher(model, cache: FrameCache, limit: int | None = None, blank: int = 0) -> dict:
    """Student vs cached teacher on held-out clips: frame argmax agreement, mean KL and
    the edit distance between greedy decodes over teacher length ("teacher PER")."""
    model.eval()
    agree = frames = 0
    kl_sum = 0.0
    pairs = []
    with torch.no_grad():
        for i in range(min(len(cache), limit or len(cache))):
            feats, logp = cache.get(i)
            s = torch.log_softmax(logits_from_features(model, torch.from_numpy(feats)[None])[0], -1)
            t = torch.from_numpy(logp)
            t = torch.log_softmax(t, -1)
            agree += int((s.argmax(-1) == t.argmax(-1)).sum())
            frames += t.shape[0]
            kl_sum += float((t.exp() * (t - s)).sum())
            pairs.append(
                (
                    ph.ctc_greedy(t.argmax(-1).tolist(), blank),
                    ph.ctc_greedy(s.argmax(-1).tolist(), blank),
                )
            )
    return {
        "clips": len(pairs),
        "argmax_agree": round(agree / max(frames, 1), 4),
        "kl": round(kl_sum / max(frames, 1), 4),
        "teacher_per": round(ph.phoneme_error_rate(pairs), 4),
    }


def _save_atomic(obj, path: Path) -> None:
    tmp = path.with_suffix(".tmp")
    torch.save(obj, tmp)
    os.replace(tmp, path)


def train(
    student,
    cache: FrameCache,
    out: Path,
    steps: int,
    max_frames: int = 3000,
    lr: float = 5e-5,
    warmup: int = 100,
    eval_cache: FrameCache | None = None,
    eval_every: int = 200,
    ckpt_minutes: float = 60.0,
    hours: float | None = None,
    temperature: float = 1.0,
    ctc_weight: float = 0.0,
    seed: int = 0,
    log: Callable[[str], None] = print,
) -> list[dict]:
    """KL distillation loop with periodic checkpoints and resume.

    Stops after [steps] optimiser steps or [hours] of wall clock (whichever first); the
    LR schedule always spans [steps]. Returns the training history."""
    out.mkdir(parents=True, exist_ok=True)
    params = [p for p in student.parameters() if p.requires_grad]
    opt = torch.optim.AdamW(params, lr=lr, weight_decay=0.01)
    blank = student.config.pad_token_id or 0
    history: list[dict] = []
    step, elapsed, epoch = 0, 0.0, 0
    ckpt = out / CKPT
    if ckpt.exists():
        state = torch.load(ckpt, weights_only=False)
        student.load_state_dict(state["model"])
        opt.load_state_dict(state["opt"])
        step, elapsed, epoch = state["step"], state["elapsed"], state["epoch"]
        history = state["history"]
        log(f"resumed at step {step} ({elapsed / 3600:.2f} h trained)")

    def save() -> None:
        _save_atomic(
            {
                "model": student.state_dict(),
                "opt": opt.state_dict(),
                "step": step,
                "elapsed": elapsed,
                "epoch": epoch,
                "history": history,
            },
            ckpt,
        )

    lengths = [e["frames"] for e in cache.entries]
    log_file = (out / "train_log.jsonl").open("a", encoding="utf-8")
    last_ckpt = time.time()
    budget = hours * 3600 if hours else float("inf")
    student.train()
    stop = step >= steps or elapsed >= budget
    while not stop:
        rng = random.Random(seed * 1000 + epoch)
        torch.manual_seed(seed * 1000 + epoch)
        batches = frame_batches(lengths, max_frames, rng)
        # skip batches already done in this epoch when resuming mid-epoch
        done_in_epoch = sum(1 for h in history if h.get("epoch") == epoch and "loss" in h)
        for idx in batches[done_in_epoch:]:
            t_step = time.time()
            feats, logp, mask = collate_frames([cache.get(i) for i in idx])
            for group in opt.param_groups:
                group["lr"] = lr_at(step, steps, warmup, lr)
            logits = logits_from_features(student, feats, mask)
            loss, parts = distill_loss(logits, logp, mask, temperature, ctc_weight, blank)
            opt.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(params, 1.0)
            opt.step()
            step += 1
            dt = time.time() - t_step
            elapsed += dt
            entry = {
                "step": step,
                "epoch": epoch,
                "loss": round(float(loss), 5),
                **{k: round(v, 5) for k, v in parts.items()},
                "lr": lr_at(step - 1, steps, warmup, lr),
                "frames": int(mask.sum()),
                "sec": round(dt, 2),
            }
            if eval_cache is not None and (step % eval_every == 0 or step == steps):
                entry["val"] = compare_to_teacher(student, eval_cache, blank=blank)
                student.train()
            history.append(entry)
            log_file.write(json.dumps(entry) + "\n")
            log_file.flush()
            if step <= 3 or step % 20 == 0 or "val" in entry:
                rate = sum(h["frames"] for h in history[-20:]) / max(
                    1e-9, sum(h["sec"] for h in history[-20:])
                )
                log(
                    f"step {step}/{steps} epoch {epoch} {elapsed / 3600:.2f} h "
                    f"{rate / 50:.1f} audio-s/s {json.dumps(entry)}"
                )
            if time.time() - last_ckpt > ckpt_minutes * 60:
                save()
                last_ckpt = time.time()
            if step >= steps or elapsed >= budget:
                stop = True
                break
        else:
            epoch += 1
    save()
    log_file.close()
    student.eval()
    return history


def save_student(student, vocab: dict[str, int], out: Path) -> Path:
    """Saves the student as a HF directory (+ vocab.json) loadable by export_onnx."""
    out.mkdir(parents=True, exist_ok=True)
    student.save_pretrained(out)
    (out / "vocab.json").write_text(
        json.dumps(vocab, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    return out


# --------------------------------------------------------------------------- CLI


def _rows(manifest: Path, limit: int | None, exclude: set[str]) -> list[dict]:
    rows = [r for r in read_manifest(manifest) if r.get("speaker") not in exclude]
    return rows[:limit] if limit else rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="CPU distillation of the light-tier model")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("prepare", help="teacher pass: cache conv features + log-posteriors")
    p.add_argument("--teacher", type=Path, required=True)
    p.add_argument("--manifest", type=Path, nargs="+", required=True)
    p.add_argument("--cache", type=Path, required=True)
    p.add_argument("--limit", type=int)
    p.add_argument("--exclude-speakers", default="", help="comma-separated speaker ids")
    c = sub.add_parser("init-check", help="teacher agreement of untrained layer choices")
    c.add_argument("--teacher", type=Path, required=True)
    c.add_argument("--cache", type=Path, required=True)
    c.add_argument("--candidates", nargs="+", required=True)
    c.add_argument("--limit", type=int)
    t = sub.add_parser("train", help="distil (resumes from <out>/checkpoint.pt)")
    t.add_argument("--teacher", type=Path, required=True)
    t.add_argument("--cache", type=Path, nargs="+", required=True)
    t.add_argument("--eval-cache", type=Path)
    t.add_argument("--out", type=Path, required=True)
    t.add_argument("--keep-layers", default="0,4,9,14,19,23")
    t.add_argument("--steps", type=int, default=3000)
    t.add_argument("--hours", type=float, help="wall-clock budget (stop early, keep LR plan)")
    t.add_argument("--max-frames", type=int, default=3000)
    t.add_argument("--lr", type=float, default=5e-5)
    t.add_argument("--warmup", type=int, default=100)
    t.add_argument("--eval-every", type=int, default=200)
    t.add_argument("--ckpt-minutes", type=float, default=60.0)
    t.add_argument("--temperature", type=float, default=1.0)
    t.add_argument("--ctc-weight", type=float, default=0.0)
    t.add_argument("--dropout", type=float, default=0.05)
    t.add_argument("--mask-time-prob", type=float, default=0.05)
    t.add_argument("--seed", type=int, default=0)
    e = sub.add_parser("compare", help="agreement of a saved student with cached teacher")
    e.add_argument("--model", type=Path, required=True)
    e.add_argument("--cache", type=Path, required=True)
    for s in (p, c, t, e):
        s.add_argument("--threads", type=int, default=DEFAULT_THREADS)
    args = parser.parse_args(argv)
    torch.set_num_threads(args.threads)

    def log(msg: str) -> None:
        print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

    if args.cmd == "compare":
        model, _ = load_teacher(args.model)
        print(json.dumps(compare_to_teacher(model, FrameCache(args.cache))))
        return 0
    teacher, vocab = load_teacher(args.teacher)
    if args.cmd == "prepare":
        exclude = {s for s in args.exclude_speakers.split(",") if s}
        rows = [r for m in args.manifest for r in _rows(m, None, exclude)]
        rows = rows[: args.limit] if args.limit else rows
        cache = FrameCache(args.cache, teacher.config.conv_dim[-1], len(vocab))
        added = prepare(teacher, rows, cache, log)
        log(f"cache {args.cache}: {len(cache)} clips, {cache.frames / 180000:.2f} h ({added} new)")
        return 0
    if args.cmd == "init-check":
        cache = FrameCache(args.cache)
        for spec in args.candidates:
            student = make_student(teacher, parse_layers(spec))
            res = compare_to_teacher(student, cache, args.limit)
            log(f"layers {spec}: {json.dumps(res)}")
        return 0
    # train
    keep = parse_layers(args.keep_layers)
    student = make_student(teacher, keep, args.dropout, args.mask_time_prob)
    del teacher
    caches = [FrameCache(p) for p in args.cache]
    cache = caches[0] if len(caches) == 1 else _merge(caches, args.out / "cache-merged")
    log(
        f"student: layers {list(keep)}, {count_params(student) / 1e6:.1f} M params; "
        f"train cache {len(cache)} clips / {cache.frames / 180000:.2f} h"
    )
    train(
        student,
        cache,
        args.out,
        steps=args.steps,
        max_frames=args.max_frames,
        lr=args.lr,
        warmup=args.warmup,
        eval_cache=FrameCache(args.eval_cache) if args.eval_cache else None,
        eval_every=args.eval_every,
        ckpt_minutes=args.ckpt_minutes,
        hours=args.hours,
        temperature=args.temperature,
        ctc_weight=args.ctc_weight,
        seed=args.seed,
        log=log,
    )
    save_student(student, vocab, args.out / "hf")
    log(f"saved {args.out / 'hf'}")
    return 0


class _MultiCache:
    """Read-only view over several FrameCaches (concatenated entries)."""

    def __init__(self, caches: Sequence[FrameCache]):
        self.caches = list(caches)
        self.entries = [e for c in self.caches for e in c.entries]
        self._where = [(ci, i) for ci, c in enumerate(self.caches) for i in range(len(c))]

    def __len__(self) -> int:
        return len(self.entries)

    @property
    def frames(self) -> int:
        return sum(c.frames for c in self.caches)

    def get(self, i: int):
        ci, j = self._where[i]
        return self.caches[ci].get(j)


def _merge(caches: Sequence[FrameCache], _unused: Path) -> _MultiCache:
    return _MultiCache(caches)


if __name__ == "__main__":
    sys.exit(main())
