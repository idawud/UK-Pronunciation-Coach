"""Light tier: fine-tune facebook/wav2vec2-base (Apache-2.0) for CTC on eSpeak IPA labels.

Labels: each transcript is phonemised with eSpeak NG's Received Pronunciation voice
(`en-gb-x-rp`, run as a binary) and mapped onto full-tier vocab tokens, so the light
vocab is a subset of the full vocab with the same token strings (blank `<pad>` = 0).

Real run (GPU; see docs/models.md for cost):

    python -m tools.models.train_light \
        --train tools/models/data/train/manifest.tsv --val tools/models/data/eval/manifest.tsv \
        --full-vocab tools/models/release/full/vocab.json \
        --base facebook/wav2vec2-base --out tools/models/work/light/hf \
        --steps 20000 --batch-size 16 --lr 1e-4 --warmup 1000 --fp16

CPU smoke test of the whole pipeline (tiny random model, a few clips): add `--tiny`.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
import time
from collections.abc import Callable, Sequence
from pathlib import Path

import numpy as np
import torch

from tools.models import phonemes as ph
from tools.models.audio import load_audio, normalise
from tools.models.evaluate import decode, read_manifest

BASE_MODEL = "facebook/wav2vec2-base"
BASE_REVISION = "0b5b8e868dd84f03fd87d01f9c4ff0f080fecfe8"


def tiny_config(vocab_size: int, **overrides):
    """A tiny randomly initialised wav2vec2 config with the base model's layout (group
    norm feature encoder, post-norm transformer): fast enough for tests on CPU."""
    from transformers import Wav2Vec2Config

    kwargs = dict(
        vocab_size=vocab_size,
        hidden_size=32,
        num_hidden_layers=2,
        num_attention_heads=2,
        intermediate_size=64,
        conv_dim=(32,) * 7,
        num_conv_pos_embeddings=16,
        num_conv_pos_embedding_groups=2,
        feat_extract_norm="group",
        do_stable_layer_norm=False,
        pad_token_id=0,
        ctc_loss_reduction="mean",
        ctc_zero_infinity=True,
        mask_time_prob=0.0,
        layerdrop=0.0,
    )
    kwargs.update(overrides)
    return Wav2Vec2Config(**kwargs)


def build_model(vocab: dict[str, int], base: str = BASE_MODEL, tiny: bool = False):
    """CTC model with a fresh output layer sized for [vocab]; feature encoder frozen."""
    from transformers import Wav2Vec2ForCTC

    if tiny:
        torch.manual_seed(0)
        model = Wav2Vec2ForCTC(tiny_config(len(vocab)))
    else:  # pragma: no cover - downloads wav2vec2-base
        model = Wav2Vec2ForCTC.from_pretrained(
            base,
            revision=BASE_REVISION if base == BASE_MODEL else None,
            vocab_size=len(vocab),
            pad_token_id=ph.blank_index(vocab),
            ctc_loss_reduction="mean",
            ctc_zero_infinity=True,
            mask_time_prob=0.05,
            layerdrop=0.05,
            ignore_mismatched_sizes=True,
        )
    model.freeze_feature_encoder()
    return model


def label_rows(
    rows: Sequence[dict],
    full_vocab: dict[str, int],
    voice: str = ph.VOICE_RP,
    runner=None,
) -> list[dict]:
    """Adds `tokens` (full-vocab token strings from eSpeak) to each manifest row."""
    vocab_set = set(full_vocab) - set(ph.SPECIALS)
    out = []
    for row in rows:
        tokens = ph.text_to_tokens(row["text"], vocab_set, voice, runner)
        if tokens:
            out.append({**row, "tokens": tokens})
    return out


def load_or_label(manifest: Path, full_vocab: dict, cache: Path, runner=None) -> list[dict]:
    """Labelled rows for a manifest, cached as JSON lines next to the model output."""
    if cache.exists():
        return [json.loads(line) for line in cache.read_text(encoding="utf-8").splitlines()]
    rows = label_rows(read_manifest(manifest), full_vocab, runner=runner)
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(
        "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8"
    )
    return rows


class Clips:
    """Normalised audio + label ids for labelled rows (audio loaded once, kept in RAM)."""

    def __init__(self, rows: Sequence[dict], vocab: dict[str, int]):
        self.rows = list(rows)
        self.audio = [normalise(load_audio(r["path"])) for r in self.rows]
        self.labels = [[vocab[t] for t in r["tokens"]] for r in self.rows]

    def __len__(self) -> int:
        return len(self.rows)


def collate(audio: Sequence[np.ndarray], labels: Sequence[Sequence[int]]):
    """Zero-padded input batch, attention mask and -100-padded labels."""
    n = max(a.size for a in audio)
    x = torch.zeros(len(audio), n)
    mask = torch.zeros(len(audio), n, dtype=torch.long)
    for i, a in enumerate(audio):
        x[i, : a.size] = torch.from_numpy(a)
        mask[i, : a.size] = 1
    m = max(len(seq) for seq in labels)
    y = torch.full((len(labels), m), -100, dtype=torch.long)
    for i, seq in enumerate(labels):
        y[i, : len(seq)] = torch.tensor(seq, dtype=torch.long)
    return x, mask, y


def batches(lengths: Sequence[int], batch_size: int, rng: random.Random) -> list[list[int]]:
    """Length-bucketed shuffled batches (sort within chunks of 50 batches to cut padding)."""
    order = list(range(len(lengths)))
    rng.shuffle(order)
    chunk = batch_size * 50
    out = []
    for start in range(0, len(order), chunk):
        part = sorted(order[start : start + chunk], key=lambda i: lengths[i])
        out += [part[i : i + batch_size] for i in range(0, len(part), batch_size)]
    rng.shuffle(out)
    return out


def lr_at(step: int, total: int, warmup: int, peak: float) -> float:
    """Linear warm-up then linear decay to zero."""
    if step < warmup:
        return peak * (step + 1) / warmup
    return peak * max(0.0, (total - step) / max(1, total - warmup))


def evaluate_per(model, clips: Clips, vocab: dict[str, int]) -> float:
    """Greedy-decode PER of a PyTorch model on [clips]."""
    model.eval()
    tokens = ph.vocab_list(vocab)
    pairs = []
    with torch.no_grad():
        for audio, row in zip(clips.audio, clips.rows, strict=True):
            logits = model(torch.from_numpy(audio)[None]).logits[0].numpy()
            pairs.append((row["tokens"], decode(logits, tokens, ph.blank_index(vocab))))
    model.train()
    return ph.phoneme_error_rate(pairs)


def train(
    model,
    train_clips: Clips,
    val_clips: Clips | None,
    vocab: dict[str, int],
    steps: int,
    batch_size: int = 8,
    lr: float = 1e-4,
    warmup: int = 500,
    eval_every: int = 1000,
    seed: int = 0,
    fp16: bool = False,
    log: Callable[[str], None] = print,
) -> list[dict]:
    """Plain PyTorch CTC fine-tuning loop; returns the log (loss, lr, val PER)."""
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model.to(device).train()
    use_mask = model.config.feat_extract_norm == "layer"
    params = [p for p in model.parameters() if p.requires_grad]
    opt = torch.optim.AdamW(params, lr=lr, weight_decay=0.005)
    scaler = torch.amp.GradScaler(device, enabled=fp16 and device == "cuda")
    rng = random.Random(seed)
    torch.manual_seed(seed)
    lengths = [a.size for a in train_clips.audio]
    history: list[dict] = []
    step, t0 = 0, time.time()
    while step < steps:
        for idx in batches(lengths, batch_size, rng):
            if step >= steps:
                break
            x, mask, y = collate(
                [train_clips.audio[i] for i in idx], [train_clips.labels[i] for i in idx]
            )
            for group in opt.param_groups:
                group["lr"] = lr_at(step, steps, warmup, lr)
            with torch.autocast(device, enabled=fp16 and device == "cuda"):
                out = model(
                    x.to(device),
                    attention_mask=mask.to(device) if use_mask else None,
                    labels=y.to(device),
                )
            opt.zero_grad()
            scaler.scale(out.loss).backward()
            scaler.unscale_(opt)
            torch.nn.utils.clip_grad_norm_(params, 1.0)
            scaler.step(opt)
            scaler.update()
            step += 1
            current_lr = lr_at(step - 1, steps, warmup, lr)
            entry = {"step": step, "loss": round(float(out.loss), 4), "lr": current_lr}
            if val_clips is not None and (step % eval_every == 0 or step == steps):
                model.cpu()
                entry["val_per"] = round(evaluate_per(model, val_clips, vocab), 4)
                model.to(device)
            history.append(entry)
            if step % 50 == 0 or "val_per" in entry or step == 1:
                log(f"{time.time() - t0:7.0f}s {json.dumps(entry)}")
    model.cpu().eval()
    if any(not math.isfinite(h["loss"]) for h in history):
        log("warning: non-finite loss seen (ctc_zero_infinity keeps training going)")
    return history


def main(argv: list[str] | None = None, runner=None) -> int:
    parser = argparse.ArgumentParser(description="Fine-tune the light-tier phoneme model")
    parser.add_argument("--train", type=Path, required=True, help="train manifest.tsv")
    parser.add_argument("--val", type=Path, help="validation manifest.tsv (held-out speakers)")
    parser.add_argument("--val-limit", type=int, default=100)
    parser.add_argument("--full-vocab", type=Path, required=True, help="full-tier vocab.json")
    parser.add_argument("--base", default=BASE_MODEL)
    parser.add_argument("--tiny", action="store_true", help="tiny random model (smoke test)")
    parser.add_argument("--out", type=Path, required=True, help="HF model output folder")
    parser.add_argument("--steps", type=int, default=20000)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--warmup", type=int, default=1000)
    parser.add_argument("--eval-every", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--fp16", action="store_true")
    args = parser.parse_args(argv)

    full_vocab = ph.load_vocab(args.full_vocab)
    train_rows = load_or_label(args.train, full_vocab, args.out / "labels.train.jsonl", runner)
    val_rows = []
    if args.val:
        val_rows = load_or_label(args.val, full_vocab, args.out / "labels.val.jsonl", runner)
        val_rows = val_rows[: args.val_limit]
    vocab = ph.build_light_vocab([r["tokens"] for r in train_rows + val_rows], full_vocab)
    print(f"{len(train_rows)} train / {len(val_rows)} val clips, light vocab {len(vocab)}")

    model = build_model(vocab, args.base, args.tiny)
    history = train(
        model,
        Clips(train_rows, vocab),
        Clips(val_rows, vocab) if val_rows else None,
        vocab,
        steps=args.steps,
        batch_size=args.batch_size,
        lr=args.lr,
        warmup=min(args.warmup, max(1, args.steps // 10)),
        eval_every=args.eval_every,
        seed=args.seed,
        fp16=args.fp16,
    )
    args.out.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(args.out)
    (args.out / "vocab.json").write_text(
        json.dumps(vocab, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    (args.out / "train_log.json").write_text(json.dumps(history, indent=1), encoding="utf-8")
    print(f"saved {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
