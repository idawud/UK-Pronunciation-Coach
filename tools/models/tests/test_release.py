import json

from tools.models import release
from tools.models.tests.test_manifest import make_release


def test_dry_run_writes_manifest_and_uploads_nothing(tmp_path, capsys):
    root = make_release(tmp_path / "release")
    calls = []
    assert release.run(root, "me/coach", "models-v1", runner=calls.append) == 0
    assert calls == []
    out = capsys.readouterr().out
    assert "dry run: nothing uploaded" in out
    manifest = json.loads((root / "manifest.json").read_text())
    assert manifest["files"][0]["url"].startswith("https://github.com/me/coach/releases/")
    assert (root / "SHA256SUMS").exists()


def test_publish_runs_gh_with_flat_assets(tmp_path):
    root = make_release(tmp_path / "release")
    calls = []

    def runner(cmd, check):
        staged = [a for a in cmd if a.endswith(".onnx")]
        assert all(open(a, "rb").read() for a in staged)  # staged copies exist during upload
        calls.append(cmd)

    code = release.run(root, "me/coach", "models-v2", True, runner, which=lambda _: "/bin/gh")
    assert code == 0
    (cmd,) = calls
    assert cmd[:4] == ["gh", "release", "create", "models-v2"]
    assert "--repo" in cmd and "me/coach" in cmd
    names = {a.rsplit("/", 1)[-1] for a in cmd if a.startswith("/")}
    assert {"full-model.onnx", "light-vocab.json", "manifest.json", "SHA256SUMS"} <= names
    notes = cmd[cmd.index("--notes") + 1]
    assert "full-model.onnx" in notes


def test_publish_guards(tmp_path, capsys):
    root = make_release(tmp_path / "release")
    assert release.run(root, release.mf.DEFAULT_REPO, "t", True) == 2
    assert release.run(root, "me/coach", "t", True, which=lambda _: None) == 127
    assert "gh" in capsys.readouterr().out


def test_bad_checksum_fails(tmp_path, monkeypatch):
    root = make_release(tmp_path / "release")
    monkeypatch.setattr(release.mf, "verify_manifest", lambda _: ["full/model.onnx: missing"])
    assert release.run(root, "me/coach", "t") == 1


def test_main_dry_run(tmp_path):
    root = make_release(tmp_path / "release")
    assert release.main(["--release-dir", str(root), "--repo", "me/coach"]) == 0
