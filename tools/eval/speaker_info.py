"""VCTK speaker accents, read from the official corpus zip's `speaker-info.txt`.

The 11.7 GB VCTK 0.92 zip on Edinburgh DataShare serves HTTP range requests, so the
member `VCTK-Corpus-0.92/speaker-info.txt` (a few KB) is read through the zip's central
directory without downloading the archive:

    python -m tools.eval.speaker_info --out tools/eval/evalset/speaker-info.txt

`parse_speaker_info` turns the file into {speaker id: (age, gender, accent, region)}.
"""

from __future__ import annotations

import argparse
import io
import urllib.request
import zipfile
from pathlib import Path

VCTK_ZIP_URL = (
    "https://datashare.ed.ac.uk/server/api/core/bitstreams/"
    "535f4286-e54c-4038-838c-a02285e32cb2/content"
)
MEMBER = "speaker-info.txt"


class HttpRangeFile(io.RawIOBase):
    """A read-only, seekable file over HTTP range requests (enough for `zipfile`)."""

    def __init__(self, url: str, size: int | None = None, opener=None) -> None:
        self.url = url
        self._open = opener or urllib.request.urlopen
        self.pos = 0
        self.size = size if size is not None else self._probe_size()

    def _probe_size(self) -> int:
        with self._open(urllib.request.Request(self.url, headers={"Range": "bytes=0-0"})) as r:
            total = r.headers["Content-Range"].rsplit("/", 1)[1]
        return int(total)

    def seekable(self) -> bool:
        return True

    def readable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.pos

    def seek(self, offset: int, whence: int = 0) -> int:
        base = {0: 0, 1: self.pos, 2: self.size}[whence]
        self.pos = max(0, base + offset)
        return self.pos

    def read(self, n: int = -1) -> bytes:
        end = self.size if n is None or n < 0 else min(self.size, self.pos + n)
        if end <= self.pos:
            return b""
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end - 1}"})
        with self._open(req) as r:
            data = r.read()
        self.pos += len(data)
        return data

    def readinto(self, b) -> int:  # pragma: no cover - zipfile uses read()
        data = self.read(len(b))
        b[: len(data)] = data
        return len(data)


def fetch_speaker_info(url: str = VCTK_ZIP_URL, opener=None) -> str:
    """Text of speaker-info.txt from the corpus zip at [url]."""
    with zipfile.ZipFile(HttpRangeFile(url, opener=opener)) as z:
        name = next(n for n in z.namelist() if n.endswith(MEMBER))
        return z.read(name).decode("utf-8", errors="replace")


def parse_speaker_info(text: str) -> dict[str, tuple[str, str, str, str]]:
    """{`p225`: (age, gender, accent, region)}; region may be empty."""
    out = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 4 or not parts[0][1:].isdigit():
            continue
        sid = parts[0] if parts[0].startswith("p") else f"p{parts[0]}"
        if not sid.startswith("p"):
            continue  # pragma: no cover
        out[sid] = (parts[1], parts[2], parts[3], " ".join(parts[4:]))
    return out


def main(argv: list[str] | None = None) -> int:  # pragma: no cover - network
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args(argv)
    text = fetch_speaker_info()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text, encoding="utf-8")
    print(f"wrote {args.out} ({len(parse_speaker_info(text))} speakers)")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
