import subprocess

import pytest

from tools.content import espeak


def test_convert_maps_symbols():
    assert espeak.convert("p_ɹ_ˈɪ_j_ɐ") == "p ɹ ˈɪ j ə"
    assert espeak.convert("k_ˈʌ_p") == "k ˈʌ p"
    assert espeak.convert("b_ˈɐ_t") == "b ˈʌ t"
    assert espeak.convert("n_ˈiə_ɹ") == "n ˈɪə ɹ"
    assert espeak.convert("k_w_ˈaɪə_t_ɐ") == "k w ˈaɪ ə t ə"
    assert espeak.convert("θ_ˈɜː_z_d_e‍ɪ\n") == "θ ˈɜː z d eɪ"
    assert espeak.convert("h_ˈæ_p_ɪ") == "h ˈæ p i"


def test_convert_adds_stress_when_missing():
    assert espeak.convert("k_æ_t") == "k ˈæ t"
    assert espeak.convert("s_t") == "s t"


def test_convert_rejects_empty():
    with pytest.raises(ValueError):
        espeak.convert("  \n")


def test_transcribe_uses_runner():
    assert espeak.transcribe("word", lambda w: "w_ˈɜː_d") == "w ˈɜː d"


def test_run_espeak_calls_binary(monkeypatch):
    calls = []

    def fake_run(cmd, **kw):
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, stdout="k_ˈæ_t\n")

    monkeypatch.setattr(espeak.subprocess, "run", fake_run)
    monkeypatch.setenv("ESPEAK_NG", "/x/espeak-ng")
    assert espeak.run_espeak("cat") == "k_ˈæ_t\n"
    assert calls[0][:3] == ["/x/espeak-ng", "-v", espeak.VOICE]
    assert calls[0][-1] == "cat"
