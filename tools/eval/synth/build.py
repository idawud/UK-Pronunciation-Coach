"""Builds the synthetic British-voice eval set.

    python -m tools.eval.synth.build fetch                 # voices (pinned, SHA-256)
    python -m tools.eval.synth.build sentences             # re-select sentences.tsv
    python -m tools.eval.synth.build plan                  # passages, manifest, labels
    python -m tools.eval.synth.build synth --workers 4     # render the audio (resumable)

Output (git-ignored) in `tools/eval/data/synth/`:

* `passages.json`: one `Passage` per sentence, the CORRECT SSBE pronunciation;
* `manifest.tsv`: harness items, two reads per sentence per voice: `clean` (read as
  written) and `error` (1-3 injected learner errors);
* `labels.csv`: one row per scorable word, `right` / `wrong` by construction, in the
  format `tools/eval/agreement.py` reads (`teacher` = `synthetic`, `notes` = what was
  injected, plus `error`, `voice`, `split`, `read`, `aug` columns);
* `items.tsv`: per item, the phoneme string each engine read and the augmentation;
* `wav/<voice>/<sentence>.<read>.wav`: augmented 16 kHz clips (scored);
  `dry/...`: the same TTS output without noise, reverb or phone band.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
import wave
from pathlib import Path

import numpy as np

from tools.eval import lexicon as lx
from tools.eval.agreement import LABEL_FIELDS
from tools.eval.build_set import EVALSET_DIR, clip_rows, dump_passages, write_tsv
from tools.eval.synth import augment, inject, phonemes, sentences
from tools.eval.synth.voices import DEFAULT_DIR, VOICES, Voice, available, fetch

OUT = Path(__file__).resolve().parents[1] / "data" / "synth"
MANIFEST_FIELDS = ["item", "wav", "passage", "speaker", "split", "kind", "target", "probe"]
ITEM_FIELDS = ["item", "voice", "engine", "speaker", "sentence", "read", "symbols", "profile"]
EXTRA_LABEL_FIELDS = ["error", "voice", "split", "read", "aug"]


def word_phones(word: dict) -> list[phonemes.Phone]:
    return [(p["ipa"], int(p.get("stress", 0) or 0)) for p in word["phonemes"]]


TUNE_SHARE = 3


def reads_sentence(voice: Voice, index: int, share: int = TUNE_SHARE) -> bool:
    """Held-out voices read every sentence. Tuning voices (CPU budget: Kokoro runs at
    about 1x real time per core here) each read every [share]-th sentence, offset by
    their position in VOICES, so with 6 tuning voices and share 3 every sentence gets
    2 tuning reads, one female and one male voice."""
    if voice.split == "heldout" or share <= 1:
        return True
    tune = [v.name for v in VOICES.values() if v.split == "tune"]
    return index % share == tune.index(voice.name) % share


def plan_items(
    passages: list[dict], voices: list[Voice], share: int = TUNE_SHARE
) -> tuple[list, list, list]:
    """(manifest rows, label rows, item rows) for every sentence x voice x read."""
    manifest, labels, items = [], [], []
    for n, p in enumerate(passages):
        words = [w for w in p["words"] if w["scorable"]]
        texts = [w["text"] for w in p["words"]]
        seps = phonemes.separators(p["text"], [w["offset"] for w in p["words"]], texts)
        base = [word_phones(w) for w in p["words"]]
        for v in voices:
            if not reads_sentence(v, n, share):
                continue
            errors = inject.inject(
                [(w["text"], word_phones(w)) for w in words], f"{p['id']}|{v.name}"
            )
            by_index = {words[i]["index"]: e for i, e in errors.items()}
            for read in ("clean", "error"):
                item = f"{p['id']}__{v.name}__{read}"
                profile = augment.draw_profile(inject.stable_rng("aug", item))
                said = [
                    list(by_index[i].phones) if read == "error" and i in by_index else ph
                    for i, ph in enumerate(base)
                ]
                engine_syms = "kokoro" if v.engine == "kokoro" else "espeak"
                symbols = phonemes.render(said, seps, engine_syms)
                wav = f"wav/{v.name}/{p['id']}.{read}.wav"
                manifest.append(
                    {
                        "item": item,
                        "wav": wav,
                        "passage": p["id"],
                        "speaker": v.name,
                        "split": v.split,
                        "kind": read,
                        "target": "",
                        "probe": profile.describe(),
                    }
                )
                items.append(
                    {
                        "item": item,
                        "voice": v.name,
                        "engine": v.engine,
                        "speaker": v.speaker,
                        "sentence": p["id"],
                        "read": read,
                        "symbols": symbols,
                        "profile": json.dumps(profile.to_dict(), separators=(",", ":")),
                    }
                )
                for w in words:
                    e = by_index.get(w["index"]) if read == "error" else None
                    labels.append(
                        {
                            "item": item,
                            "speaker": v.name,
                            "passage": p["id"],
                            "word_index": w["index"],
                            "word": w["text"],
                            "label": "wrong" if e else "right",
                            "teacher": "synthetic",
                            "notes": e.detail if e else "",
                            "error": e.kind if e else "",
                            "voice": v.name,
                            "split": v.split,
                            "read": read,
                            "aug": profile.describe(),
                        }
                    )
    return manifest, labels, items


def load_passages(britfone: Path | None = None) -> list[dict]:
    rows = sentences.read_rows()
    lexicon = None
    if any(r["source"] == "vctk" for r in rows):
        lexicon = lx.Lexicon.load(britfone or lx.fetch_britfone())
    return sentences.passages(rows, sentences.content_sentences(), lexicon)


def write_plan(
    out: Path, passages: list[dict], voices: list[Voice], share: int = TUNE_SHARE
) -> dict:
    manifest, labels, items = plan_items(passages, voices, share)
    out.mkdir(parents=True, exist_ok=True)
    (out / "passages.json").write_text(dump_passages(passages), encoding="utf-8")
    write_tsv(out / "manifest.tsv", manifest, MANIFEST_FIELDS)
    write_tsv(out / "items.tsv", items, ITEM_FIELDS)
    with open(out / "labels.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, LABEL_FIELDS + EXTRA_LABEL_FIELDS, lineterminator="\n")
        w.writeheader()
        w.writerows(labels)
    wrong = sum(r["label"] == "wrong" for r in labels)
    err_words = sum(r["read"] == "error" for r in labels)
    return {
        "sentences": len(passages),
        "voices": len(voices),
        "items": len(manifest),
        "words": len(labels),
        "wrong": wrong,
        "wrong_share": wrong / len(labels) if labels else 0.0,
        "wrong_share_error_reads": wrong / err_words if err_words else 0.0,
    }


def write_wav(path: Path, audio: np.ndarray, sr: int = augment.TARGET_SR) -> None:
    pcm = (np.clip(audio, -1.0, 1.0) * 32767.0).round().astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".part")
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    tmp.replace(path)


_ENGINES: dict[str, object] = {}


def engine_for(voice: Voice, root: Path, threads: int = 1):
    """One engine per model file per process (loaded lazily)."""
    from tools.eval.synth.voices import KokoroEngine, PiperEngine

    key = voice.files[0]
    if key not in _ENGINES:
        if voice.engine == "kokoro":
            _ENGINES[key] = KokoroEngine(root, threads)
        else:
            _ENGINES[key] = PiperEngine(root / voice.files[0], threads)
    return _ENGINES[key]


def render_item(row: dict, out: Path, root: Path, engine=None) -> float:
    """Synthesises one item, writes its augmented and dry WAVs; returns seconds."""
    voice = VOICES[row["voice"]]
    profile = augment.Profile(**json.loads(row["profile"]))
    eng = engine or engine_for(voice, root)
    t = time.perf_counter()
    audio, sr = eng.synth(row["symbols"], voice.name, profile.speed)
    seed = int(inject.stable_rng("noise", row["item"]).random() * 2**31)
    rel = Path(row["voice"]) / f"{row['sentence']}.{row['read']}.wav"
    write_wav(out / "wav" / rel, augment.apply(audio, sr, profile, seed))
    write_wav(out / "dry" / rel, augment.clean(audio, sr, profile.lead_ms, profile.tail_ms))
    return time.perf_counter() - t


def _work(args: tuple[dict, str, str]) -> tuple[str, float]:  # pragma: no cover - subprocess
    row, out, root = args
    return row["item"], render_item(row, Path(out), Path(root))


def pending(items: list[dict], out: Path, kinds: tuple[str, ...] = ("wav", "dry")) -> list[dict]:
    """Items whose WAVs of [kinds] are not all on disk (`wav` is what the harness scores)."""
    return [
        r
        for r in items
        if not all(
            (out / k / r["voice"] / f"{r['sentence']}.{r['read']}.wav").exists() for k in kinds
        )
    ]


def render_order(items: list[dict]) -> list[dict]:
    """Sentences in a seeded shuffled order (all reads of a sentence together), so an
    interrupted run leaves a representative subset of whole sentences, not a prefix."""
    return sorted(
        items, key=lambda r: (inject.stable_rng("order", r["sentence"]).random(), r["item"])
    )


def complete_sentences(items: list[dict], out: Path) -> set[str]:
    """Sentences whose planned reads all have audio (`wav`)."""
    missing = {r["sentence"] for r in pending(items, out, ("wav",))}
    return {r["sentence"] for r in items} - missing


def write_subset(out: Path, items: list[dict]) -> dict:
    """`manifest.complete.tsv` / `labels.complete.csv`: only sentences whose planned
    reads are all rendered, for scoring a partial build."""
    keep = complete_sentences(items, out)
    manifest = [r for r in read_tsv(out / "manifest.tsv") if r["passage"] in keep]
    write_tsv(out / "manifest.complete.tsv", manifest, MANIFEST_FIELDS)
    with open(out / "labels.csv", newline="", encoding="utf-8") as f:
        labels = [r for r in csv.DictReader(f) if r["passage"] in keep]
    with open(out / "labels.complete.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, LABEL_FIELDS + EXTRA_LABEL_FIELDS, lineterminator="\n")
        w.writeheader()
        w.writerows(labels)
    return {"sentences": len(keep), "items": len(manifest), "words": len(labels)}


def synth_all(
    items: list[dict], out: Path, root: Path, workers: int = 4, log=print
) -> int:  # pragma: no cover - needs the voices; render_item is tested
    todo = render_order(pending(items, out))
    log(f"{len(todo)} of {len(items)} items to render with {workers} worker(s)")
    if not todo:
        return 0
    os.environ.setdefault("OMP_NUM_THREADS", "1")
    t0 = time.time()
    args = [(r, str(out), str(root)) for r in todo]
    if workers <= 1:
        results = map(_work, args)
    else:
        import multiprocessing as mp

        pool = mp.get_context("spawn").Pool(workers)
        results = pool.imap_unordered(_work, args, chunksize=4)
    for n, (item, secs) in enumerate(results, 1):
        if n % 50 == 0 or n == len(args):
            rate = (time.time() - t0) / n
            log(f"[{n}/{len(args)}] {item} {secs:.1f}s, eta {rate * (len(args) - n) / 60:.0f} min")
    return len(args)


def read_tsv(path: Path) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def main(argv: list[str] | None = None) -> int:  # pragma: no cover - CLI wiring
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("step", choices=["fetch", "sentences", "plan", "synth", "status", "subset"])
    ap.add_argument("--out", type=Path, default=OUT)
    ap.add_argument("--voices-dir", type=Path, default=DEFAULT_DIR)
    ap.add_argument("--voices", default=",".join(VOICES), help="comma-separated voice names")
    ap.add_argument("--britfone", type=Path)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument(
        "--tune-share", type=int, default=TUNE_SHARE, help="1 = tuning voices read everything"
    )
    args = ap.parse_args(argv)
    names = [n for n in args.voices.split(",") if n]
    voices = [VOICES[n] for n in names]
    if args.step == "fetch":
        for p in fetch(names, args.voices_dir):
            print("ok", p)
        return 0
    if args.step == "sentences":
        vctk = [r[3] for r in clip_rows(EVALSET_DIR / "clips.tsv")]
        rows = sentences.select(sentences.content_sentences(), vctk)
        sentences.write_rows(rows)
        print(f"{len(rows)} sentences -> {sentences.SENTENCES_TSV}")
        return 0
    if args.step == "plan":
        stats = write_plan(args.out, load_passages(args.britfone), voices, args.tune_share)
        print(json.dumps(stats, indent=1))
        return 0
    if args.step == "status":
        have = [v.name for v in voices if available(v, args.voices_dir)]
        print("voices available:", ", ".join(have) or "none")
        items = read_tsv(args.out / "items.tsv") if (args.out / "items.tsv").exists() else []
        print(f"items: {len(items)}, still to render: {len(pending(items, args.out, ('wav',)))}")
        return 0
    if args.step == "subset":
        print(json.dumps(write_subset(args.out, read_tsv(args.out / "items.tsv"))))
        return 0
    missing = [v.name for v in voices if not available(v, args.voices_dir)]
    if missing:
        print(f"voices missing: {missing} (run the fetch step)", file=sys.stderr)
        return 2
    items = [r for r in read_tsv(args.out / "items.tsv") if r["voice"] in names]
    synth_all(items, args.out, args.voices_dir, args.workers)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
