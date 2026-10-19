"""Shared fixtures for tools/eval tests: a tiny Britfone extract and word-CSV rows."""

from __future__ import annotations

import subprocess

import pytest

from tools.eval import lexicon as lx

# A few lines in Britfone 3.0.1 format (MIT, Jose Llarena).
BRITFONE = """\
A(1), ə
A(2), ˈeɪ
ASK, ˈɑː s k
BOOK, b ˈʊ k
BRING, b ɹ ˈɪ ŋ
CAT, k ˈæ t
DOG, d ˈɒ g
FROM, f ɹ ˈɒ m
HER, h ˈɜː
HOT, h ˈɒ t
OPTION, ˈɒ p ʃ ə n
STORE, s t ˈɔː
THE(1), ð ə
THESE, ð ˈiː z
THINGS, θ ˈɪ ŋ z
THINK, θ ˈɪ ŋ k
TO(1), t ə
WITH, w ˈɪ ð
CHURCH, tʃ ˈɜː tʃ
BUS, b ˈɐ s
"""

ESPEAK_OUT = {"zork": "z_ˈɔː_k\n", "bottle": "b_ˈɒ_t_əl\n"}


def fake_espeak(cmd, **kwargs):
    return subprocess.CompletedProcess(cmd, 0, stdout=ESPEAK_OUT.get(cmd[-1], ""), stderr="")


@pytest.fixture
def britfone_path(tmp_path):
    p = tmp_path / "britfone.csv"
    p.write_text(BRITFONE, encoding="utf-8")
    return p


@pytest.fixture
def lexicon(britfone_path):
    return lx.Lexicon.load(britfone_path)


@pytest.fixture
def lexicon_espeak(britfone_path):
    lex = lx.Lexicon.load(britfone_path, espeak="/fake/espeak-ng")
    lex.runner = fake_espeak
    return lex


def word_row(**kw) -> dict:
    """A harness word-CSV row with defaults."""
    row = {
        "config": "default",
        "item": "c1",
        "speaker": "p1",
        "split": "tune",
        "kind": "native",
        "passage": "c1",
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
