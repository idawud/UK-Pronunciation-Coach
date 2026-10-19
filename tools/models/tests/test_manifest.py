import json

import pytest

from tools.models import manifest as mf


def make_release(root):
    for tier, payload in (("full", b"full-model"), ("light", b"light-model")):
        (root / tier).mkdir(parents=True)
        (root / tier / "model.onnx").write_bytes(payload)
        (root / tier / "vocab.json").write_text('{"<pad>": 0}', encoding="utf-8")
    return root


def test_build_manifest_lists_every_file(tmp_path):
    release = make_release(tmp_path / "release")
    manifest = mf.build_manifest(release, tag="models-v9", repo="me/coach")
    names = [f["name"] for f in manifest["files"]]
    assert names == ["full/model.onnx", "full/vocab.json", "light/model.onnx", "light/vocab.json"]
    full = manifest["files"][0]
    assert full["sha256"] == mf.sha256_of(release / "full" / "model.onnx")
    assert full["size"] == len(b"full-model")
    assert full["asset"] == "full-model.onnx"
    assert full["url"] == "https://github.com/me/coach/releases/download/models-v9/full-model.onnx"
    assert full["bundle"] is False
    assert manifest["files"][2]["bundle"] is True
    assert manifest["release"] == "models-v9"


def test_write_and_verify(tmp_path):
    release = make_release(tmp_path / "release")
    manifest_path, sums = mf.write_manifest(release, mf.build_manifest(release))
    assert json.loads(manifest_path.read_text())["files"]
    first = sums.read_text().splitlines()[0]
    assert first.endswith("  full-model.onnx") and len(first.split()[0]) == 64
    assert mf.verify_manifest(release) == []


def test_verify_detects_tampering_and_missing_files(tmp_path):
    release = make_release(tmp_path / "release")
    mf.write_manifest(release, mf.build_manifest(release))
    (release / "full" / "model.onnx").write_bytes(b"FULL-model")  # same size, new bytes
    (release / "light" / "vocab.json").write_text("{}", encoding="utf-8")
    (release / "light" / "model.onnx").unlink()
    problems = mf.verify_manifest(release)
    assert any(p.startswith("full/model.onnx: sha256") for p in problems)
    assert "light/model.onnx: missing" in problems
    assert any(p.startswith("light/vocab.json: size") for p in problems)


def test_manifest_is_readable_by_ci_fetch(tmp_path):
    from tools.ci import fetch_models

    release = make_release(tmp_path / "release")
    manifest = mf.build_manifest(release)
    for f in manifest["files"]:
        f["url"] = (release / f["name"]).as_uri()
    target = tmp_path / "repo" / "assets" / "models" / "manifest.json"
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(manifest), encoding="utf-8")
    cached = fetch_models.fetch(tmp_path / "repo", tmp_path / "cache")
    assert len(cached) == 4
    assert (tmp_path / "repo" / "assets" / "models" / "light" / "model.onnx").exists()


def test_empty_release_dir_raises(tmp_path):
    (tmp_path / "full").mkdir()
    with pytest.raises(FileNotFoundError):
        mf.build_manifest(tmp_path)
