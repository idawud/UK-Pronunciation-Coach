import csv
import io

import numpy as np
import pyarrow as pa
import pyarrow.parquet as pq
import pytest
import soundfile as sf

from tools.models import data
from tools.models.tests.conftest import tone


def wav_bytes(seconds, sr=48000):
    buf = io.BytesIO()
    sf.write(buf, np.stack([tone(seconds, 300, sr)] * 2, axis=1), sr, format="WAV")
    return buf.getvalue()


def make_shard(path, rows):
    table = pa.table(
        {
            "id": [r[0] for r in rows],
            "text": [r[2] for r in rows],
            "speaker_id": [r[1] for r in rows],
            "audio": [{"bytes": wav_bytes(r[3]), "path": f"{r[0]}.wav"} for r in rows],
            "mic_id": [r[4] for r in rows],
        }
    )
    pq.write_table(table, path)
    return path


def test_shard_names():
    assert data.shard_names("0,3-4") == [
        "data/train-00000-of-00034.parquet",
        "data/train-00003-of-00034.parquet",
        "data/train-00004-of-00034.parquet",
    ]
    assert len(data.shard_names("all")) == 34
    assert data.shard_names("auto", {"p225", "p228"}) == [
        data.VCTK_SHARD.format(i=i) for i in (9, 10, 22)
    ]
    with pytest.raises(ValueError):
        data.shard_names("40")
    with pytest.raises(ValueError):
        data.shard_names("auto", None)


def test_eval_speakers_are_english_and_indexed():
    assert set(data.EVAL_SPEAKERS) <= set(data.VCTK_ENGLISH)
    assert set(data.SPEAKER_SHARDS) == set(data.VCTK_ENGLISH)


def test_select_speakers():
    assert data.select_speakers(None, None, False) is None
    assert data.select_speakers(None, "p1,p2", False) == {"p1", "p2"}
    english = data.select_speakers("english", None, True)
    assert "p226" in english and not english & set(data.EVAL_SPEAKERS)
    southern = data.select_speakers("southern", None, False)
    assert "p243" in southern and "p269" not in southern
    with pytest.raises(ValueError):
        data.select_speakers(None, None, True)


def test_main_writes_16k_clips_and_manifest(tmp_path, capsys):
    shard = make_shard(
        tmp_path / "s.parquet",
        [
            ("p225_001_mic1", "p225", "Please  call Stella.", 0.6, "mic1"),
            ("p225_001_mic2", "p225", "Please call Stella.", 0.6, "mic2"),
            ("p225_002_mic1", "p225", "Ask her.", 0.5, "mic1"),
            ("p226_001_mic1", "p226", "Too short.", 0.1, "mic1"),
            ("p300_001_mic1", "p300", "Other speaker.", 0.5, "mic1"),
        ],
    )
    out = tmp_path / "out"
    args = ["--shards", "0", "--speakers", "p225,p226", "--per-speaker", "1", "--out", str(out)]
    assert data.main(args, downloader=lambda name: shard) == 0
    with (out / "manifest.tsv").open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f, delimiter="\t"))
    assert rows == [
        {"id": "p225_001_mic1", "path": "wav/p225_001_mic1.wav", "speaker": "p225",
         "text": "Please call Stella."}
    ]  # fmt: skip
    audio, sr = sf.read(out / rows[0]["path"])
    assert sr == 16000 and audio.ndim == 1 and abs(audio.size - 9600) < 10
    assert "wrote 1 clips from 1 speakers" in capsys.readouterr().out


def test_main_requires_out():
    with pytest.raises(SystemExit):
        data.main(["--shards", "0"])
