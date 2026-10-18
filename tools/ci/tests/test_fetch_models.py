import hashlib
import json

import pytest

from tools.ci import fetch_models as fm


def setup_manifest(tmp_path, payload: bytes, sha: str | None = None, bundle=True):
    source = tmp_path / "release" / "light.onnx"
    source.parent.mkdir()
    source.write_bytes(payload)
    manifest = {
        "files": [
            {
                "name": "light/model.onnx",
                "tier": "light",
                "url": source.as_uri(),
                "sha256": sha or hashlib.sha256(payload).hexdigest(),
                "bundle": bundle,
            },
            {"name": "full/model.onnx", "tier": "full", "url": "unused", "sha256": "0" * 64},
        ]
    }
    path = tmp_path / "assets" / "models" / "manifest.json"
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps(manifest), encoding="utf-8")
    return source


def test_no_manifest_is_a_noop(tmp_path):
    assert fm.fetch(tmp_path, tmp_path / "cache") == []
    assert fm.main(["--root", str(tmp_path), "--cache", str(tmp_path / "c")]) == 0


def test_downloads_verifies_caches_and_bundles(tmp_path):
    setup_manifest(tmp_path, b"model-bytes")
    calls = []

    def downloader(url, dest):
        calls.append(url)
        fm.download(url, dest)

    cache = tmp_path / "cache"
    [cached] = fm.fetch(tmp_path, cache, tier="light", downloader=downloader)
    assert cached.read_bytes() == b"model-bytes"
    assert (tmp_path / "assets/models/light/model.onnx").read_bytes() == b"model-bytes"
    fm.fetch(tmp_path, cache, tier="light", downloader=downloader)
    assert len(calls) == 1  # second run uses the cache


def test_checksum_mismatch(tmp_path):
    setup_manifest(tmp_path, b"model-bytes", sha="f" * 64)
    with pytest.raises(ValueError, match="sha256"):
        fm.fetch(tmp_path, tmp_path / "cache", tier="light")
    assert (
        fm.main(["--root", str(tmp_path), "--cache", str(tmp_path / "c"), "--tier", "light"]) == 1
    )


def test_sha256_of(tmp_path):
    f = tmp_path / "x"
    f.write_bytes(b"abc")
    assert fm.sha256_of(f) == hashlib.sha256(b"abc").hexdigest()
