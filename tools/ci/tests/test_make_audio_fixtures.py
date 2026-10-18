import json
import os
import stat
import sys
import textwrap
import wave

import numpy as np

from tools.ci import make_audio_fixtures as maf


def fake_espeak(tmp_path):
    """A stand-in for espeak-ng: writes 1 s of a 22.05 kHz tone to the -w path."""
    script = tmp_path / "espeak-ng"
    script.write_text(
        textwrap.dedent(
            f"""\
            #!{sys.executable}
            import sys, wave, math, struct
            out = sys.argv[sys.argv.index("-w") + 1]
            with wave.open(out, "wb") as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(22050)
                frames = b"".join(
                    struct.pack("<h", int(8000 * math.sin(2 * math.pi * 220 * i / 22050)))
                    for i in range(22050)
                )
                w.writeframes(frames)
            """
        ),
        encoding="utf-8",
    )
    script.chmod(script.stat().st_mode | stat.S_IEXEC)
    return str(script)


def test_build_writes_16k_clips_and_manifest(tmp_path, monkeypatch):
    monkeypatch.setenv("ESPEAK_DATA", str(tmp_path))
    out = tmp_path / "audio"
    assert maf.main(["--espeak", fake_espeak(tmp_path), "--out", str(out)]) == 0
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert set(manifest) >= {"clean_read.wav", "silence.wav", "noise.wav", "quiet_read.wav"}
    for name, meta in manifest.items():
        with wave.open(str(out / name), "rb") as w:
            assert w.getframerate() == 16000
            assert w.getnchannels() == 1
            assert w.getsampwidth() == 2
            assert w.getnframes() * 1000 // 16000 == meta["durationMs"]
    assert manifest["quiet_read.wav"]["peakDbfs"] == -40.0
    assert manifest["clean_read.wav"]["approxSpeechMs"]
    assert manifest["noise.wav"]["expectedQuality"] == "tooNoisy"


def test_helpers(tmp_path):
    tone = np.sin(np.linspace(0, 100, 22050)).astype(np.float32) * 0.5
    assert len(maf.resample(tone, 22050, 16000)) == 16000
    assert len(maf.resample(tone, 16000, 16000)) == len(tone)
    assert len(maf.resample(tone[:100], 8000, 16000)) == 200
    assert maf.peak_dbfs(np.zeros(10)) == float("-inf")
    path = tmp_path / "x.wav"
    maf.write_wav(path, tone)
    back, rate = maf.read_wav(path)
    assert rate == 16000 and np.allclose(back, tone, atol=1e-4)
    with wave.open(str(tmp_path / "stereo.wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(b"\0" * 8)
    try:
        maf.read_wav(tmp_path / "stereo.wav")
    except ValueError:
        pass
    else:
        raise AssertionError("stereo should be rejected")
    rng = np.random.default_rng(0)
    speechy = np.concatenate([maf.silence(0.5, rng), tone[:8000], maf.silence(0.5, rng)])
    assert maf.speech_regions(speechy) == [[500, 1000]]
    assert maf.speech_regions(np.full(1600, 0.5, dtype=np.float32)) == [[0, 100]]
    assert os.path.basename(maf.OUT) == "audio"
