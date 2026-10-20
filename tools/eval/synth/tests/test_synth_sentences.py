import json

import pytest

from tools.eval.synth import sentences as S


def w(text, offset, ph=(("t", 0),), scorable=True):
    return {
        "text": text,
        "index": 0,
        "phonemes": [{"ipa": p, "stress": s} for p, s in ph],
        "scorable": scorable,
        "offset": offset,
    }


PASSAGE = {
    "id": "l1-009",
    "level": 1,
    "title": "T",
    "text": "Mr. Brown is here. Is it? Yes!",
    "words": [
        w("Mr", 0),
        w("Brown", 4),
        w("is", 10),
        w("here", 13),
        w("Is", 19),
        w("it", 22),
        w("Yes", 26),
    ],
}


def test_split_passage_on_sentence_punctuation_not_abbreviations():
    out = S.split_passage(PASSAGE)
    assert [s["text"] for s in out] == ["Mr. Brown is here.", "Is it?", "Yes!"]
    assert [s["id"] for s in out] == ["l1-009.s1", "l1-009.s2", "l1-009.s3"]
    second = out[1]
    assert [x["index"] for x in second["words"]] == [0, 1]
    assert [x["offset"] for x in second["words"]] == [0, 3]
    assert second["text"][second["words"][1]["offset"] :].startswith("it")


def test_real_content_splits_into_sentences():
    sents = S.content_sentences()
    assert len(sents) > 300
    for s in sents[:50]:
        for x in s["words"]:
            assert s["text"][x["offset"] :].startswith(x["text"])


def test_select_spreads_levels_and_adds_vctk():
    content = []
    for lv in (1, 2, 3):
        for i in range(10):
            content.append(
                {
                    "id": f"l{lv}-{i:03d}.s1",
                    "level": lv,
                    "text": "a b c d",
                    "words": [w(c, 0) for c in "abcd"],
                }
            )
    content.append({"id": "long", "level": 1, "text": "x", "words": [w("x", 0)] * 20})
    vctk = ["One two three four.", "Too short.", "Five six seven eight nine."]
    rows = S.select(content, vctk, n_content=6, n_vctk=5, seed=1)
    src = [r["source"] for r in rows]
    assert src.count("content") == 6 and src.count("vctk") == 2
    levels = [r["id"][1] for r in rows if r["source"] == "content"]
    assert sorted(levels) == ["1", "1", "2", "2", "3", "3"]
    assert "long" not in {r["id"] for r in rows}
    assert rows == S.select(content, vctk, n_content=6, n_vctk=5, seed=1)


def test_select_tops_up_small_levels():
    content = [
        {"id": f"l1-{i}", "level": 1, "text": "a b c d", "words": [w(c, 0) for c in "abcd"]}
        for i in range(5)
    ] + [{"id": "l2-0", "level": 2, "text": "a b c d", "words": [w(c, 0) for c in "abcd"]}]
    rows = S.select(content, [], n_content=4, n_vctk=0)
    assert len(rows) == 4


def test_rows_round_trip(tmp_path):
    rows = [{"id": "a", "source": "content", "text": "Hi there."}]
    S.write_rows(rows, tmp_path / "s.tsv")
    assert S.read_rows(tmp_path / "s.tsv") == rows


def test_passages_from_content_and_lexicon(lexicon):
    content = [{"id": "c1", "words": []}]
    rows = [
        {"id": "c1", "source": "content", "text": ""},
        {"id": "vctk.001", "source": "vctk", "text": "Ask her to bring the book."},
    ]
    out = S.passages(rows, content, lexicon)
    assert out[0] is content[0]
    assert out[1]["id"] == "vctk.001"
    assert out[1]["words"][0]["phonemes"][0] == {"ipa": "ɑː", "stress": 1}
    json.dumps(out)


def test_passages_errors(lexicon):
    with pytest.raises(KeyError):
        S.passages([{"id": "nope", "source": "content", "text": ""}], [], None)
    with pytest.raises(ValueError, match="lexicon"):
        S.passages([{"id": "v", "source": "vctk", "text": "the cat"}], [], None)
    with pytest.raises(ValueError, match="no pronunciation"):
        S.passages([{"id": "v", "source": "vctk", "text": "the zebra"}], [], lexicon)


def test_committed_sentence_list_is_valid():
    rows = S.read_rows()
    assert len(rows) == 300
    assert {r["source"] for r in rows} == {"content", "vctk"}
    ids = {s["id"] for s in S.content_sentences()}
    assert all(r["id"] in ids for r in rows if r["source"] == "content")
