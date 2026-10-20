import csv
import json
import wave

import numpy as np

from tools.eval import agreement as ag
from tools.eval.synth import build as B
from tools.eval.synth.voices import VOICES


def ph(*pairs):
    return [{"ipa": p, "stress": s} for p, s in pairs]


PASSAGE = {
    "id": "s1",
    "level": 1,
    "title": "s1",
    "text": "I think the cat is here.",
    "words": [
        {"text": "I", "index": 0, "offset": 0, "scorable": True, "phonemes": ph(("aɪ", 1))},
        {
            "text": "think",
            "index": 1,
            "offset": 2,
            "scorable": True,
            "phonemes": ph(("θ", 0), ("ɪ", 1), ("ŋ", 0), ("k", 0)),
        },
        {
            "text": "the",
            "index": 2,
            "offset": 8,
            "scorable": True,
            "phonemes": ph(("ð", 0), ("ə", 0)),
        },
        {
            "text": "cat",
            "index": 3,
            "offset": 12,
            "scorable": True,
            "phonemes": ph(("k", 0), ("æ", 1), ("t", 0)),
        },
        {
            "text": "is",
            "index": 4,
            "offset": 16,
            "scorable": True,
            "phonemes": ph(("ɪ", 0), ("z", 0)),
        },
        {
            "text": "here",
            "index": 5,
            "offset": 19,
            "scorable": True,
            "phonemes": ph(("h", 0), ("ɪə", 1)),
        },
    ],
}
VOICES2 = [VOICES["bf_emma"], VOICES["cori_high"]]


def test_plan_items_reads_labels_and_symbols():
    manifest, labels, items = B.plan_items([PASSAGE], VOICES2, 1)
    assert len(manifest) == len(items) == 4
    assert len(labels) == 4 * 6
    assert {m["kind"] for m in manifest} == {"clean", "error"}
    by_item = {i["item"]: i for i in items}
    clean = by_item["s1__bf_emma__clean"]
    assert clean["symbols"] == "ˈI θˈɪŋk ðə kˈat ɪz hˈɪə."
    assert by_item["s1__cori_high__clean"]["symbols"] == "ˈaɪ θˈɪŋk ðə kˈat ɪz hˈiə."
    for m in manifest:
        assert m["passage"] == "s1" and m["wav"].endswith(f"{m['kind']}.wav")
    for item in by_item:
        rows = [r for r in labels if r["item"] == item]
        wrong = [r for r in rows if r["label"] == "wrong"]
        if item.endswith("clean"):
            assert not wrong
        else:
            assert 1 <= len(wrong) <= 3
            assert all(r["error"] and r["notes"] for r in wrong)
            assert by_item[item]["symbols"] != by_item[item.replace("error", "clean")]["symbols"]
    assert all(r["teacher"] == "synthetic" for r in labels)
    assert {r["split"] for r in labels} == {"tune", "heldout"}


def test_plan_is_deterministic():
    assert B.plan_items([PASSAGE], VOICES2, 1) == B.plan_items([PASSAGE], VOICES2, 1)


def test_write_plan_and_labels_readable_by_agreement(tmp_path):
    stats = B.write_plan(tmp_path, [PASSAGE], VOICES2, 1)
    assert stats["items"] == 4 and stats["words"] == 24
    assert 0 < stats["wrong_share"] < stats["wrong_share_error_reads"]
    labels = ag.read_csv(tmp_path / "labels.csv")
    assert all(ag.parse_label(r["label"]) is not None for r in labels)
    passages = json.loads((tmp_path / "passages.json").read_text())
    assert passages[0]["id"] == "s1"
    with open(tmp_path / "manifest.tsv", newline="") as f:
        assert len(list(csv.DictReader(f, delimiter="\t"))) == 4
    items = B.read_tsv(tmp_path / "items.tsv")
    assert len(B.pending(items, tmp_path)) == 4


class FakeEngine:
    def synth(self, symbols, voice, speed):
        n = int(24000 * 0.5 / speed)
        return (0.3 * np.sin(np.arange(n) * 0.05)).astype(np.float32), 24000


def test_render_item_writes_augmented_and_dry_wavs(tmp_path):
    B.write_plan(tmp_path, [PASSAGE], VOICES2, 1)
    items = B.read_tsv(tmp_path / "items.tsv")
    secs = B.render_item(items[0], tmp_path, tmp_path, engine=FakeEngine())
    assert secs >= 0
    rel = f"{items[0]['voice']}/{items[0]['sentence']}.{items[0]['read']}.wav"
    for kind in ("wav", "dry"):
        with wave.open(str(tmp_path / kind / rel)) as w:
            assert w.getframerate() == 16000 and w.getnchannels() == 1
            assert w.getnframes() > 16000 * 0.4
    assert len(B.pending(items, tmp_path)) == 3
    (tmp_path / "dry" / rel).unlink()
    assert len(B.pending(items, tmp_path)) == 4
    assert len(B.pending(items, tmp_path, ("wav",))) == 3


def test_load_passages_uses_committed_sentences(monkeypatch, lexicon):
    rows = [
        {"id": "vctk.001", "source": "vctk", "text": "Ask her to bring the book."},
        {"id": "l1-001.s1", "source": "content", "text": ""},
    ]
    monkeypatch.setattr(B.sentences, "read_rows", lambda: rows)
    monkeypatch.setattr(B.lx, "fetch_britfone", lambda: None)
    monkeypatch.setattr(B.lx.Lexicon, "load", classmethod(lambda cls, p: lexicon))
    out = B.load_passages()
    assert [p["id"] for p in out] == ["vctk.001", "l1-001.s1"]


def test_engine_for_caches_per_model(monkeypatch, tmp_path):
    made = []

    class Fake:
        def __init__(self, *a):
            made.append(a)

    monkeypatch.setattr("tools.eval.synth.voices.KokoroEngine", Fake)
    monkeypatch.setattr("tools.eval.synth.voices.PiperEngine", Fake)
    monkeypatch.setattr(B, "_ENGINES", {})
    a = B.engine_for(VOICES["bf_emma"], tmp_path)
    assert B.engine_for(VOICES["bm_george"], tmp_path) is a
    B.engine_for(VOICES["cori_high"], tmp_path)
    assert len(made) == 2


def test_tuning_voices_share_sentences():
    tune = [v for v in VOICES.values() if v.split == "tune"]
    for n in range(6):
        readers = [v for v in tune if B.reads_sentence(v, n)]
        assert len(readers) == 2 and {v.sex for v in readers} == {"F", "M"}
    assert B.reads_sentence(VOICES["bm_george"], 1)
    assert B.reads_sentence(tune[0], 1, share=1)
    manifest, _, _ = B.plan_items([PASSAGE, {**PASSAGE, "id": "s2"}], VOICES2)
    assert {m["item"] for m in manifest if m["speaker"] == "bf_emma"} == {
        "s2__bf_emma__clean",
        "s2__bf_emma__error",
    }


def test_render_order_groups_sentences_and_subset(tmp_path):
    two = [PASSAGE, {**PASSAGE, "id": "s2"}]
    B.write_plan(tmp_path, two, VOICES2, 1)
    items = B.read_tsv(tmp_path / "items.tsv")
    order = B.render_order(items)
    assert sorted(order, key=lambda r: r["item"]) == sorted(items, key=lambda r: r["item"])
    sents = [r["sentence"] for r in order]
    assert sents == sorted(sents, key=sents.index)  # each sentence contiguous
    assert B.complete_sentences(items, tmp_path) == set()
    for r in items:
        if r["sentence"] == "s2":
            B.render_item(r, tmp_path, tmp_path, engine=FakeEngine())
    assert B.complete_sentences(items, tmp_path) == {"s2"}
    stats = B.write_subset(tmp_path, items)
    assert stats == {"sentences": 1, "items": 4, "words": 24}
    labels = ag.read_csv(tmp_path / "labels.complete.csv")
    assert {r["passage"] for r in labels} == {"s2"}
