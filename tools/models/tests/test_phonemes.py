import json

import pytest

from tools.models import phonemes as ph
from tools.models.tests.conftest import VOCAB


def test_vocab_helpers(tmp_path):
    path = tmp_path / "vocab.json"
    path.write_text(json.dumps(VOCAB, ensure_ascii=False), encoding="utf-8")
    vocab = ph.load_vocab(path)
    assert ph.vocab_list(vocab)[:2] == ["<pad>", "<s>"]
    assert ph.blank_index(vocab) == 0
    with pytest.raises(ValueError):
        ph.vocab_list({"a": 0, "b": 2})


def test_espeak_binary_from_env_or_missing(monkeypatch):
    monkeypatch.setenv("ESPEAK_NG", "/opt/espeak-ng")
    assert ph.espeak_binary() == "/opt/espeak-ng"
    monkeypatch.delenv("ESPEAK_NG")
    monkeypatch.setattr(ph.shutil, "which", lambda name: None)
    with pytest.raises(FileNotFoundError):
        ph.espeak_binary()


def test_espeak_ipa_strips_stress(espeak):
    words = ph.espeak_ipa("Please call Stella.", runner=espeak)
    assert words == [["p", "l", "iː", "z"], ["k", "ɔː", "l"], ["s", "t", "ɛ", "l", "ɐ"]]


def test_espeak_ipa_passes_voice_and_flags(monkeypatch):
    monkeypatch.setenv("ESPEAK_NG", "espeak-ng")
    seen = {}

    def runner(cmd, **kwargs):
        seen["cmd"] = cmd
        return type("R", (), {"stdout": "ˌa_b __ \n"})()

    assert ph.espeak_ipa("hi", "en-us", runner) == [["a", "b"]]
    assert seen["cmd"] == ["espeak-ng", "-q", "--ipa", "--sep=_", "-v", "en-us", "hi"]


def test_to_vocab_tokens_greedy_split():
    vocab = {"a", "aɪ", "ə", "ɑːɹ", "ɑː", "t"}
    assert ph.to_vocab_tokens(["aɪə", "ɑːɹ", "tʰ", "t"], vocab) == ["aɪ", "ə", "ɑːɹ", "t", "t"]
    assert ph.to_vocab_tokens(["ʔ"], vocab) == []


def test_text_to_tokens(espeak):
    tokens = ph.text_to_tokens("Please call Stella.", set(VOCAB), runner=espeak)
    assert tokens == ["p", "l", "iː", "z", "k", "ɔː", "l", "s", "t", "ɛ", "l", "ɐ"]


def test_ctc_greedy_and_per():
    assert ph.ctc_greedy([0, 3, 3, 0, 3, 4, 4, 0]) == [3, 3, 4]
    assert ph.edit_distance("kitten", "sitting") == 3
    assert ph.edit_distance([], ["a"]) == 1
    assert ph.phoneme_error_rate([(["a", "b"], ["a", "c"]), (["d", "e"], ["d", "e"])]) == 0.25
    assert ph.phoneme_error_rate([]) == 0.0


def test_normalise_for_per():
    assert ph.normalise_for_per(["ɑːɹ", "iː", "ɹ", "ː"]) == ["ɑ", "i", "ɹ", "ː"]


def test_build_light_vocab():
    full = {"<pad>": 0, "<s>": 1, "</s>": 2, "<unk>": 3, "n": 4, "s": 5, "t": 6, "ə": 7}
    light = ph.build_light_vocab([["t", "ə"], ["s", "t"]], full)
    assert light == {"<pad>": 0, "<s>": 1, "</s>": 2, "<unk>": 3, "s": 4, "t": 5, "ə": 6}
    with pytest.raises(ValueError, match="not in the full vocab"):
        ph.build_light_vocab([["θ"]], full)
