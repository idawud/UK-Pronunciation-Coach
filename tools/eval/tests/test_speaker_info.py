import io
import zipfile

from tools.eval import speaker_info as si

TEXT = """ID  AGE  GENDER  ACCENTS  REGION COMMENTS
p225  23  F    English    Southern  England
p232  23  M    English    Southern  England
p280  25  F    French    Paris
p315  18  M    American    Connecticut
s5  22  F  British  (mic2 only)
"""


class FakeResponse(io.BytesIO):
    def __init__(self, data, headers=None):
        super().__init__(data)
        self.headers = headers or {}


def range_opener(blob: bytes):
    calls = []

    def opener(req):
        rng = req.headers["Range"].removeprefix("bytes=")
        lo, hi = (int(x) for x in rng.split("-"))
        calls.append((lo, hi))
        return FakeResponse(blob[lo : hi + 1], {"Content-Range": f"bytes {lo}-{hi}/{len(blob)}"})

    opener.calls = calls
    return opener


def make_zip() -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("VCTK-Corpus-0.92/wav48/p225_001.flac", b"\0" * 50000)
        z.writestr("VCTK-Corpus-0.92/speaker-info.txt", TEXT)
    return buf.getvalue()


def test_fetch_reads_member_with_range_requests():
    blob = make_zip()
    opener = range_opener(blob)
    text = si.fetch_speaker_info("http://example/zip", opener=opener)
    assert text == TEXT
    assert all(hi - lo < len(blob) for lo, hi in opener.calls)  # never the whole file


def test_http_range_file_seek_and_read():
    blob = bytes(range(100))
    f = si.HttpRangeFile("http://u", opener=range_opener(blob))
    assert f.size == 100 and f.seekable() and f.readable()
    f.seek(-10, 2)
    assert f.tell() == 90 and f.read() == blob[90:]
    assert f.read(5) == b""
    f.seek(5)
    f.seek(5, 1)
    assert f.read(3) == blob[10:13]


def test_parse_speaker_info():
    info = si.parse_speaker_info(TEXT)
    assert info["p225"] == ("23", "F", "English", "Southern England")
    assert info["p280"][2] == "French"
    assert "s5" not in info


def test_committed_speaker_info_confirms_eval_speakers():
    from tools.eval.build_set import EVALSET_DIR, SPEAKERS

    info = si.parse_speaker_info((EVALSET_DIR / "speaker-info.txt").read_text(encoding="utf-8"))
    for spk, (region, _) in SPEAKERS.items():
        assert info[spk][2] == "English" and info[spk][3] == region
