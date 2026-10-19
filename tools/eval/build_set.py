"""Builds the native-British eval set and the controlled-error probes.

Source: CSTR VCTK Corpus 0.92 (CC-BY-4.0), via the silence-trimmed Parquet mirror
`jspaulsen/vctk` @ fb74847 (the mirror A4 uses). Speakers: five Southern England
speakers (accents checked against the corpus's own speaker-info.txt, see
`tools/eval/evalset/SOURCES.md`). `mic1` only.

    # 1. choose clips (writes tools/eval/evalset/clips.tsv, committed)
    python -m tools.eval.build_set select --shards tools/eval/data/vctk
    # 2. extract audio + write manifest / passages (into tools/eval/data/evalset, ignored)
    python -m tools.eval.build_set build --shards tools/eval/data/vctk

`build` writes `<out>/wav/<clip>.wav` (16 kHz mono PCM16), `<out>/passages.json`
(`Passage` JSON list) and `<out>/manifest.tsv`, one row per scored item:

    item  wav  passage  speaker  split  kind  target  probe

`kind` is `native` (the real transcript), `swap` (one word of the expected text replaced
by a different word the speaker did not say) or `sub` (one phoneme of one word's
expected pronunciation replaced by a typical learner error). For probes, `target` is the
word index that should come out red and `probe` describes the change.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
import wave
from collections.abc import Iterable
from pathlib import Path

import numpy as np

from tools.eval import lexicon as lx

EVALSET_DIR = Path(__file__).parent / "evalset"
DEFAULT_OUT = Path(__file__).parent / "data" / "evalset"

# Speaker: (VCTK region as in speaker-info.txt, split). Tune on three, hold out two.
SPEAKERS = {
    "p225": ("Southern England", "tune"),
    "p228": ("Southern England", "tune"),
    "p229": ("Southern England", "tune"),
    "p231": ("Southern England", "heldout"),
    "p232": ("Southern England", "heldout"),
}
PER_SPEAKER = 50
MIN_WORDS, MAX_WORDS = 4, 20
SEED = 20261019

# Learner-style substitutions for the `sub` probe: expected phoneme -> wrong phoneme
# written into the expected transcript (the audio has the right one).
SUBSTITUTIONS = {
    "θ": "t",
    "ð": "d",
    "v": "w",
    "w": "v",
    "ɪ": "iː",
    "iː": "ɪ",
    "æ": "ɛ",
    "ʃ": "s",
    "z": "s",
    "ɒ": "əʊ",
    "ʊ": "uː",
    "ɹ": "l",
    "l": "ɹ",
    "p": "b",
    "b": "p",
    "ɜː": "ɑː",
    "ɐ": "ɒ",
    "eɪ": "ɛ",
}

STOPWORDS = {"the", "a", "an", "of", "to", "and", "in", "is", "it", "on", "at", "be", "by"}


def read_shards(paths: Iterable[Path], speakers: set[str]) -> dict[str, dict]:
    """{clip id (`p225_001`): {speaker, text, audio bytes}} for mic1 clips of [speakers]."""
    import pyarrow.parquet as pq

    clips = {}
    for path in paths:
        f = pq.ParquetFile(path)
        for g in range(f.num_row_groups):
            t = f.read_row_group(g, columns=["id", "text", "speaker_id", "mic_id"])
            rows = [
                i
                for i, (s, m) in enumerate(
                    zip(
                        t.column("speaker_id").to_pylist(),
                        t.column("mic_id").to_pylist(),
                        strict=True,
                    )
                )
                if s in speakers and m == "mic1"
            ]
            if not rows:
                continue
            full = f.read_row_group(g, columns=["id", "text", "speaker_id", "audio"])
            for i in rows:
                r = full.slice(i, 1).to_pylist()[0]
                cid = r["id"].removesuffix("_mic1")
                clips[cid] = {
                    "speaker": r["speaker_id"],
                    "text": r["text"].strip(),
                    "audio": r["audio"]["bytes"],
                }
    return clips


def sentence_number(cid: str) -> int:
    return int(cid.split("_")[1])


def fully_britfone(text: str, lex: lx.Lexicon) -> bool:
    words = lx.tokenize(text)
    return bool(words) and all(
        (p := lex.lookup(w.text)) and p.source.startswith("britfone") for w in words
    )


def select_clips(
    texts: dict[str, tuple[str, str]],
    lex: lx.Lexicon,
    per_speaker: int = PER_SPEAKER,
    seed: int = SEED,
):
    """Chooses clips: [texts] is {clip id: (speaker, text)}. Prefers sentences every speaker
    read (VCTK's shared elicitation sentences), then fills each speaker up to
    [per_speaker] with random sentences whose words are all in Britfone. Returns rows
    (clip, speaker, split, text) sorted by clip id."""
    by_speaker: dict[str, dict[int, str]] = {}
    for cid, (spk, text) in texts.items():
        by_speaker.setdefault(spk, {})[sentence_number(cid)] = text

    def ok(text: str) -> bool:
        return MIN_WORDS <= len(lx.tokenize(text)) <= MAX_WORDS and fully_britfone(text, lex)

    speakers = sorted(by_speaker)
    shared = sorted(
        n
        for n in set.intersection(*(set(v) for v in by_speaker.values()))
        if len({by_speaker[s][n] for s in speakers}) == 1 and ok(by_speaker[speakers[0]][n])
    )
    rng = random.Random(seed)
    rows = []
    for spk in speakers:
        chosen = shared[: per_speaker // 2]
        rest = sorted(n for n, t in by_speaker[spk].items() if n not in chosen and ok(t))
        rng.shuffle(rest)
        chosen = sorted(chosen + rest[: per_speaker - len(chosen)])
        for n in chosen:
            rows.append(
                (f"{spk}_{n:03d}", spk, SPEAKERS.get(spk, ("", "tune"))[1], by_speaker[spk][n])
            )
    return sorted(rows)


def write_wav(path: Path, audio: np.ndarray, sr: int = 16000) -> None:
    pcm = (np.clip(audio, -1.0, 1.0) * 32767.0).round().astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def stable_rng(*parts: str) -> random.Random:
    return random.Random(int(hashlib.sha256("|".join(parts).encode()).hexdigest()[:12], 16))


def edit_distance(a: list[str], b: list[str]) -> int:
    d = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        prev, d[0] = d[0], i
        for j, y in enumerate(b, 1):
            prev, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, prev + (x != y))
    return d[len(b)]


def content_words(words: list[lx.Word]) -> list[lx.Word]:
    return [
        w
        for w in words
        if w.scorable and w.text.lower() not in STOPWORDS and len(w.pron.phonemes) >= 3
    ]


def swap_probe(cid: str, text: str, words: list[lx.Word], pool: list[tuple[str, lx.Pron]]):
    """Replaces one content word of the expected text with a clearly different word.
    Returns (passage words, target index, description) or None."""
    rng = stable_rng("swap", cid)
    cands = content_words(words)
    if not cands:
        return None
    target = rng.choice(cands)
    sym = [p.ipa for p in target.pron.phonemes]
    options = [
        (w, p)
        for w, p in pool
        if w.lower() != target.text.lower()
        and abs(len(p.phonemes) - len(sym)) <= 1
        and edit_distance([q.ipa for q in p.phonemes], sym) >= max(2, (len(sym) + 1) // 2)
    ]
    if not options:
        return None
    new_text, new_pron = rng.choice(sorted(options, key=lambda o: o[0]))
    out = [lx.Word(w.text, w.index, w.offset, w.pron) for w in words]
    out[target.index] = lx.Word(new_text.lower(), target.index, target.offset, new_pron)
    return out, target.index, f"{target.text}->{new_text.lower()}"


def sub_probe(cid: str, words: list[lx.Word]):
    """Replaces one phoneme of one word's expected pronunciation with a learner error.
    Returns (passage words, target index, description) or None."""
    rng = stable_rng("sub", cid)
    cands = [
        (w, i)
        for w in words
        if w.scorable and w.text.lower() not in STOPWORDS
        for i, p in enumerate(w.pron.phonemes)
        if p.ipa in SUBSTITUTIONS
    ]
    if not cands:
        return None
    w, i = rng.choice(cands)
    ph = list(w.pron.phonemes)
    old = ph[i]
    ph[i] = lx.Phoneme(
        SUBSTITUTIONS[old.ipa], old.stress if SUBSTITUTIONS[old.ipa] in lx.VOWELS else 0
    )
    out = [lx.Word(x.text, x.index, x.offset, x.pron) for x in words]
    out[w.index] = lx.Word(w.text, w.index, w.offset, lx.Pron(ph, w.pron.source))
    return out, w.index, f"{w.text}:{old.ipa}->{ph[i].ipa}"


MANIFEST_FIELDS = ["item", "wav", "passage", "speaker", "split", "kind", "target", "probe"]


def build_items(rows: list[tuple[str, str, str, str]], lex: lx.Lexicon, wav_dir: str = "wav"):
    """Passages and manifest rows (native + probes) for selected clips."""
    passages, manifest = [], []
    pool: dict[str, lx.Pron] = {}
    tokenized = {}
    for cid, _, _, text in rows:
        words = lx.tokenize(text)
        for w in words:
            w.pron = lex.lookup(w.text)
            if w.scorable and w.pron.source == "britfone" and len(w.pron.phonemes) >= 3:
                pool.setdefault(w.text.lower(), w.pron)
        tokenized[cid] = words
    pool_list = sorted(pool.items())
    for cid, spk, split, text in rows:
        words = tokenized[cid]
        wav = f"{wav_dir}/{cid}.wav"
        base = {"wav": wav, "speaker": spk, "split": split}
        passages.append(lx.words_to_passage(cid, text, words))
        manifest.append(
            {**base, "item": cid, "passage": cid, "kind": "native", "target": "", "probe": ""}
        )
        for kind, probe in (
            ("swap", swap_probe(cid, text, words, pool_list)),
            ("sub", sub_probe(cid, words)),
        ):
            if probe is None:
                continue
            pwords, target, desc = probe
            pid = f"{cid}.{kind}"
            ptext = " ".join(w.text for w in pwords)
            off = 0
            for w in pwords:  # recompute offsets for the rewritten text
                w.offset = off
                off += len(w.text) + 1
            passages.append(lx.words_to_passage(pid, ptext, pwords))
            manifest.append(
                {
                    **base,
                    "item": pid,
                    "passage": pid,
                    "kind": kind,
                    "target": str(target),
                    "probe": desc,
                }
            )
    return passages, manifest


def dump_passages(passages: list[dict]) -> str:
    """One compact passage per line (small, diff-friendly)."""
    body = ",\n".join(json.dumps(p, ensure_ascii=False, separators=(",", ":")) for p in passages)
    return f"[\n{body}\n]\n"


def write_tsv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def read_tsv(path: Path) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def make_lexicon(britfone: Path | None) -> lx.Lexicon:
    path = britfone or lx.fetch_britfone()
    return lx.Lexicon.load(path, espeak=lx.find_espeak())


def write_items(rows: list[tuple[str, str, str, str]], lex: lx.Lexicon, out: Path) -> int:
    """Writes `<out>/passages.json` and `<out>/manifest.tsv`; returns the item count."""
    passages, manifest = build_items(rows, lex)
    out.mkdir(parents=True, exist_ok=True)
    (out / "passages.json").write_text(dump_passages(passages), encoding="utf-8")
    write_tsv(out / "manifest.tsv", manifest, MANIFEST_FIELDS)
    return len(manifest)


def clip_rows(path: Path = EVALSET_DIR / "clips.tsv") -> list[tuple[str, str, str, str]]:
    return [(r["clip"], r["speaker"], r["split"], r["text"]) for r in read_tsv(path)]


def main(argv: list[str] | None = None) -> int:  # pragma: no cover - needs the shards
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("step", choices=["select", "build", "passages"])
    ap.add_argument("--shards", type=Path, help="folder with VCTK Parquet shards")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--britfone", type=Path)
    args = ap.parse_args(argv)
    lex = make_lexicon(args.britfone)
    clips_tsv = EVALSET_DIR / "clips.tsv"
    if args.step == "passages":  # text only: no audio needed
        n = write_items(clip_rows(clips_tsv), lex, args.out)
        print(f"{n} items -> {args.out}")
        return 0
    if args.shards is None:
        ap.error("--shards is required for select / build")
    shards = sorted(args.shards.glob("*.parquet"))
    if args.step == "select":
        clips = read_shards(shards, set(SPEAKERS))
        rows = select_clips({c: (v["speaker"], v["text"]) for c, v in clips.items()}, lex)
        write_tsv(
            clips_tsv,
            [dict(zip(["clip", "speaker", "split", "text"], r, strict=True)) for r in rows],
            ["clip", "speaker", "split", "text"],
        )
        print(f"selected {len(rows)} clips -> {clips_tsv}")
        return 0
    rows = clip_rows(clips_tsv)
    clips = read_shards(shards, {r[1] for r in rows})
    from tools.models.audio import load_audio

    for cid, *_ in rows:
        write_wav(args.out / "wav" / f"{cid}.wav", load_audio(clips[cid]["audio"]))
    n = write_items(rows, lex, args.out)
    print(f"{len(rows)} clips, {n} items -> {args.out}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
