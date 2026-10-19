"""Speech data for verification, evaluation and light-tier training.

Source: CSTR VCTK Corpus 0.92 (CC-BY-4.0, University of Edinburgh; 110 speakers of
British and other English accents reading newspaper sentences), via the silence-trimmed
Parquet mirror `jspaulsen/vctk` on the Hugging Face Hub (same licence, pinned revision).
Every utterance appears once per microphone; we keep `mic1`.

    # held-out set: logits check + PER (speakers never used for training)
    python -m tools.models.data --speakers p225,p227,p228,p229,p232 --per-speaker 12 \
        --out tools/models/data/eval
    # light-tier training data (the shards holding English-accent speakers, minus held-out)
    python -m tools.models.data --accent english --exclude-eval \
        --out tools/models/data/train

Writes <out>/wav/<id>.wav (16 kHz mono PCM16) and <out>/manifest.tsv
(id, path, speaker, text). Downloads go to the Hugging Face cache.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from collections.abc import Iterable, Iterator
from pathlib import Path

import numpy as np
import pyarrow.parquet as pq
import soundfile as sf

from tools.models.audio import SAMPLE_RATE, load_audio

VCTK_REPO = "jspaulsen/vctk"
VCTK_REVISION = "fb74847570d78d2b23e83193d8e55df80e6271b2"
VCTK_SHARDS = 34
VCTK_SHARD = "data/train-{i:05d}-of-00034.parquet"

# Speakers whose accent is "English" in VCTK 0.92 speaker-info.txt (id: region).
# Southern / South-East England speakers are closest to Standard Southern British.
VCTK_ENGLISH = {
    "p225": "Southern England",
    "p226": "Surrey",
    "p227": "Cumbria",
    "p228": "Southern England",
    "p229": "Southern England",
    "p230": "Stockport",
    "p231": "Southern England",
    "p232": "Southern England",
    "p233": "Staffordshire",
    "p236": "Manchester",
    "p239": "SE England",
    "p240": "Southern England",
    "p243": "London",
    "p244": "Manchester",
    "p250": "SE England",
    "p254": "Surrey",
    "p256": "Birmingham",
    "p257": "Southern England",
    "p258": "Southern England",
    "p259": "Nottingham",
    "p267": "Yorkshire",
    "p268": "Southern England",
    "p269": "Newcastle",
    "p270": "Yorkshire",
    "p273": "Suffolk",
    "p274": "Essex",
    "p276": "Oxford",
    "p277": "NE England",
    "p278": "Cheshire",
    "p279": "Leicester",
    "p282": "Newcastle",
    "p286": "Newcastle",
    "p287": "York",
}
SOUTHERN = ("Southern England", "SE England", "Surrey", "London", "Essex", "Oxford", "Suffolk")
# Held out from training: logits check + PER (four Southern England speakers, 3 F / 1 M,
# plus one Northern male for contrast).
EVAL_SPEAKERS = ("p225", "p227", "p228", "p229", "p232")
# Shards holding each English speaker's mic1 clips (read from the Parquet metadata at
# VCTK_REVISION with `python -m tools.models.data --index`).
SPEAKER_SHARDS = {
    "p225": (22,),
    "p226": (
        27,
        28,
    ),
    "p227": (10,),
    "p228": (
        9,
        10,
    ),
    "p229": (10,),
    "p230": (
        18,
        19,
    ),
    "p231": (32,),
    "p232": (33,),
    "p233": (26,),
    "p236": (
        26,
        27,
    ),
    "p239": (
        32,
        33,
    ),
    "p240": (8,),
    "p243": (31,),
    "p244": (16,),
    "p250": (
        10,
        11,
    ),
    "p254": (24,),
    "p256": (30,),
    "p257": (20,),
    "p258": (
        16,
        17,
    ),
    "p259": (28,),
    "p267": (12,),
    "p268": (
        24,
        25,
    ),
    "p269": (3,),
    "p270": (31,),
    "p273": (11,),
    "p274": (
        12,
        13,
    ),
    "p276": (2,),
    "p277": (13,),
    "p278": (
        14,
        15,
    ),
    "p279": (
        31,
        32,
    ),
    "p282": (
        13,
        14,
    ),
    "p286": (6,),
    "p287": (
        28,
        29,
    ),
}


def shard_names(spec: str, speakers: set[str] | None = None) -> list[str]:
    """`auto` (shards holding [speakers]), `all`, or shard numbers / ranges (`0,3,5-7`)
    -> repo file names."""
    if spec == "auto":
        if speakers is None or not speakers <= set(SPEAKER_SHARDS):
            raise ValueError("--shards auto needs speakers listed in SPEAKER_SHARDS")
        indices = sorted({i for s in speakers for i in SPEAKER_SHARDS[s]})
    elif spec == "all":
        indices = list(range(VCTK_SHARDS))
    else:
        indices = []
        for part in spec.split(","):
            lo, _, hi = part.partition("-")
            indices += list(range(int(lo), int(hi or lo) + 1))
    bad = [i for i in indices if not 0 <= i < VCTK_SHARDS]
    if bad:
        raise ValueError(f"shard numbers out of range 0-{VCTK_SHARDS - 1}: {bad}")
    return [VCTK_SHARD.format(i=i) for i in indices]


def fetch_shards(names: Iterable[str], downloader=None) -> list[Path]:
    """Downloads (or reuses cached) Parquet shards at the pinned revision."""
    if downloader is None:  # pragma: no cover - network
        from huggingface_hub import hf_hub_download

        def downloader(name):
            return hf_hub_download(VCTK_REPO, name, repo_type="dataset", revision=VCTK_REVISION)

    return [Path(downloader(n)) for n in names]


def select_speakers(accent: str | None, speakers: str | None, exclude_eval: bool) -> set | None:
    """Speaker filter from CLI options (None = everyone)."""
    chosen: set[str] | None = None
    if speakers:
        chosen = set(speakers.split(","))
    elif accent == "english":
        chosen = set(VCTK_ENGLISH)
    elif accent == "southern":
        chosen = {s for s, region in VCTK_ENGLISH.items() if region in SOUTHERN}
    if exclude_eval:
        if chosen is None:
            raise ValueError("--exclude-eval needs --accent or --speakers")
        chosen -= set(EVAL_SPEAKERS)
    return chosen


def iter_rows(
    paths: Iterable[Path],
    speakers: set[str] | None = None,
    mic: str = "mic1",
) -> Iterator[dict]:
    """Yields {id, speaker, text, audio(bytes)} rows from VCTK Parquet shards."""
    for path in paths:
        table = pq.ParquetFile(path)
        for batch in table.iter_batches(batch_size=256):
            for row in batch.to_pylist():
                if mic and row.get("mic_id") not in (None, mic):
                    continue
                if speakers is not None and row["speaker_id"] not in speakers:
                    continue
                audio = row["audio"]
                yield {
                    "id": row["id"],
                    "speaker": row["speaker_id"],
                    "text": " ".join(str(row["text"]).split()),
                    "audio": audio["bytes"] if isinstance(audio, dict) else audio,
                }


def write_clips(rows: Iterable[dict], out: Path, per_speaker: int | None = None) -> Path:
    """Writes 16 kHz WAVs and manifest.tsv; keeps at most [per_speaker] clips each."""
    wav_dir = out / "wav"
    wav_dir.mkdir(parents=True, exist_ok=True)
    counts: Counter = Counter()
    manifest = out / "manifest.tsv"
    with manifest.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, delimiter="\t", lineterminator="\n")
        writer.writerow(["id", "path", "speaker", "text"])
        for row in rows:
            if per_speaker is not None and counts[row["speaker"]] >= per_speaker:
                continue
            audio = load_audio(row["audio"])
            if audio.size < SAMPLE_RATE // 4:
                continue
            path = wav_dir / f"{row['id']}.wav"
            sf.write(path, np.clip(audio, -1, 1), SAMPLE_RATE, subtype="PCM_16")
            writer.writerow([row["id"], f"wav/{path.name}", row["speaker"], row["text"]])
            counts[row["speaker"]] += 1
    print(f"wrote {sum(counts.values())} clips from {len(counts)} speakers to {manifest}")
    return manifest


def shard_index() -> dict[int, dict[str, int]]:  # pragma: no cover - network
    """{shard: {speaker: mic1 clips}} read remotely from Parquet column metadata only."""
    from huggingface_hub import HfFileSystem

    fs = HfFileSystem()
    out = {}
    for i in range(VCTK_SHARDS):
        path = f"datasets/{VCTK_REPO}@{VCTK_REVISION}/{VCTK_SHARD.format(i=i)}"
        with fs.open(path, block_size=1 << 20) as fh:
            table = pq.ParquetFile(fh).read(columns=["speaker_id", "mic_id"])
        pairs = zip(table["speaker_id"].to_pylist(), table["mic_id"].to_pylist(), strict=True)
        out[i] = dict(Counter(s for s, m in pairs if m == "mic1"))
    return out


def main(argv: list[str] | None = None, downloader=None) -> int:
    parser = argparse.ArgumentParser(description="Prepare VCTK clips (CC-BY-4.0)")
    parser.add_argument("--index", action="store_true", help="print the speaker/shard index")
    parser.add_argument("--shards", default="auto", help="`auto`, `all` or e.g. `0,3,5-7`")
    parser.add_argument("--speakers", help="comma-separated speaker ids")
    parser.add_argument("--accent", choices=["english", "southern"], help="VCTK accent filter")
    parser.add_argument("--exclude-eval", action="store_true", help="drop held-out speakers")
    parser.add_argument("--per-speaker", type=int)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    if args.index:  # pragma: no cover - network
        print(json.dumps(shard_index(), indent=1))
        return 0
    if args.out is None:
        parser.error("--out is required")
    speakers = select_speakers(args.accent, args.speakers, args.exclude_eval)
    paths = fetch_shards(shard_names(args.shards, speakers), downloader)
    write_clips(iter_rows(paths, speakers), args.out, args.per_speaker)
    return 0


if __name__ == "__main__":
    sys.exit(main())
