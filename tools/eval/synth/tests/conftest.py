"""Fixtures for the synthetic-set tests: a tiny Britfone lexicon and harness rows."""

from __future__ import annotations

import pytest

from tools.eval import lexicon as lx

# A few lines in Britfone 3.0.1 format (MIT, Jose Llarena).
BRITFONE = """\
ASK, ˈɑː s k
BOOK, b ˈʊ k
BRING, b ɹ ˈɪ ŋ
CAT, k ˈæ t
HER, h ˈɜː
THE(1), ð ə
TO(1), t ə
THINK, θ ˈɪ ŋ k
"""


@pytest.fixture
def lexicon(tmp_path):
    p = tmp_path / "britfone.csv"
    p.write_text(BRITFONE, encoding="utf-8")
    return lx.Lexicon.load(p)


def word_row(**kw) -> dict:
    """A harness word-CSV row with defaults."""
    row = {
        "config": "default",
        "item": "s1__v1__clean",
        "speaker": "v1",
        "split": "tune",
        "kind": "clean",
        "passage": "s1",
        "word_index": "0",
        "word": "cat",
        "is_target": "0",
        "status": "good",
        "score": "90",
        "expected": "k æ t",
        "stress": "0 1 0",
        "heard": "k æ t",
        "phoneme_scores": "90 90 90",
    }
    row.update({k: str(v) for k, v in kw.items()})
    return row
