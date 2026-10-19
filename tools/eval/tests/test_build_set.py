import io
import json
import wave

import numpy as np
import pyarrow as pa
import pyarrow.parquet as pq

from tools.eval import build_set as bs
from tools.eval import lexicon as lx


def wav_bytes(seconds=0.2, sr=16000):
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(np.zeros(int(sr * seconds), dtype="<i2").tobytes())
    return buf.getvalue()


def test_read_shards_keeps_mic1_of_chosen_speakers(tmp_path):
    rows = [
        ("p225_001_mic1", "Ask her.", "p225", "mic1"),
        ("p225_001_mic2", "Ask her.", "p225", "mic2"),
        ("p999_001_mic1", "Other.", "p999", "mic1"),
    ]
    table = pa.table(
        {
            "id": [r[0] for r in rows],
            "text": [r[1] for r in rows],
            "speaker_id": [r[2] for r in rows],
            "audio": [{"bytes": wav_bytes(), "path": r[0] + ".wav"} for r in rows],
            "mic_id": [r[3] for r in rows],
        }
    )
    path = tmp_path / "shard.parquet"
    pq.write_table(table, path, row_group_size=2)
    clips = bs.read_shards([path], {"p225"})
    assert list(clips) == ["p225_001"]
    assert clips["p225_001"]["text"] == "Ask her." and clips["p225_001"]["audio"][:4] == b"RIFF"


def test_select_prefers_shared_sentences(lexicon):
    texts = {
        "pa_001": ("pa", "Ask her to bring these things."),
        "pb_001": ("pb", "Ask her to bring these things."),
        "pa_002": ("pa", "Bring the book from the store."),
        "pb_003": ("pb", "Think with the cat to the dog."),
        "pb_004": ("pb", "Zork the hot dog with her."),  # not all in Britfone
        "pa_005": ("pa", "Too short."),
    }
    rows = bs.select_clips(texts, lexicon, per_speaker=2)
    assert [r[0] for r in rows] == ["pa_001", "pa_002", "pb_001", "pb_003"]
    assert all(r[2] == "tune" for r in rows)


def test_write_wav_round_trip(tmp_path):
    p = tmp_path / "x" / "a.wav"
    bs.write_wav(p, np.array([0.0, 0.5, -2.0], dtype=np.float32))
    with wave.open(str(p)) as w:
        assert w.getframerate() == 16000 and w.getnframes() == 3
        data = np.frombuffer(w.readframes(3), dtype="<i2")
    assert list(data) == [0, 16384, -32767]


def test_edit_distance():
    assert bs.edit_distance(list("kat"), list("kat")) == 0
    assert bs.edit_distance(list("kat"), list("bot")) == 2
    assert bs.edit_distance([], list("ab")) == 2


def test_build_items_makes_native_and_probes(lexicon):
    rows = [
        ("p1_001", "p1", "tune", "Ask her to bring these things with the book."),
        ("p2_001", "p2", "heldout", "Think of the hot cat from the store."),
    ]
    passages, manifest = bs.build_items(rows, lexicon)
    kinds = [(m["item"], m["kind"]) for m in manifest]
    assert ("p1_001", "native") in kinds and ("p1_001.swap", "swap") in kinds
    assert ("p1_001.sub", "sub") in kinds
    by_id = {p["id"]: p for p in passages}
    for m in manifest:
        p = by_id[m["passage"]]
        assert m["wav"] == f"wav/{m['item'].split('.')[0]}.wav"
        for w in p["words"]:
            assert p["text"][w["offset"] : w["offset"] + len(w["text"])] == w["text"]
        if m["kind"] == "native":
            continue
        t = int(m["target"])
        native = by_id[m["item"].split(".")[0]]
        assert p["words"][t]["phonemes"] != native["words"][t]["phonemes"]
        changed = [
            i for i, (a, b) in enumerate(zip(p["words"], native["words"], strict=True)) if a != b
        ]
        # only the target word differs (offsets may shift after a swap)
        assert t in changed
        if m["kind"] == "sub":
            assert changed == [t] and ":" in m["probe"] and "->" in m["probe"]
            assert p["text"] == native["text"].replace(".", "").replace(",", "")
        else:
            assert "->" in m["probe"]
    # deterministic
    assert bs.build_items(rows, lexicon) == (passages, manifest)


def test_probes_none_when_no_candidates(lexicon):
    words = lx.tokenize("the a")
    for w in words:
        w.pron = lexicon.lookup(w.text)
    assert bs.swap_probe("x", "the a", words, []) is None
    assert bs.sub_probe("x", words) is None
    cat = lx.tokenize("cat")
    cat[0].pron = lexicon.lookup("cat")
    assert bs.swap_probe("x", "cat", cat, [("cat", cat[0].pron)]) is None


def test_write_items_and_tsv_round_trip(tmp_path, lexicon):
    rows = [("p1_001", "p1", "tune", "Ask her to bring these things.")]
    n = bs.write_items(rows, lexicon, tmp_path)
    manifest = bs.read_tsv(tmp_path / "manifest.tsv")
    assert len(manifest) == n and manifest[0]["item"] == "p1_001"
    passages = json.loads((tmp_path / "passages.json").read_text(encoding="utf-8"))
    assert [p["id"] for p in passages] == [m["passage"] for m in manifest]
    clips = tmp_path / "clips.tsv"
    bs.write_tsv(clips, [dict(zip(["clip", "speaker", "split", "text"], rows[0], strict=True))],
                 ["clip", "speaker", "split", "text"])  # fmt: skip
    assert bs.clip_rows(clips) == rows


def test_committed_clip_list_is_consistent():
    rows = bs.clip_rows()
    assert len(rows) == 250
    per = {}
    for cid, spk, split, text in rows:
        assert cid.startswith(spk + "_") and text
        assert split == bs.SPEAKERS[spk][1]
        per[spk] = per.get(spk, 0) + 1
    assert per == {s: bs.PER_SPEAKER for s in bs.SPEAKERS}


def test_make_lexicon_uses_given_file(britfone_path, monkeypatch):
    monkeypatch.delenv("ESPEAK_NG", raising=False)
    monkeypatch.setattr(lx.shutil, "which", lambda name: None)
    lex = bs.make_lexicon(britfone_path)
    assert lex.espeak is None and "THINK" in lex.entries
