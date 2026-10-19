"""Build the SHA-256 manifest for a release folder and (optionally) publish it as GitHub
Release assets with the `gh` CLI.

Dry run by default: prints the `gh` commands and uploads nothing. Pass `--publish` to
really create the release (a human decision; agents never do this).

    python -m tools.models.release --release-dir tools/models/release \
        --repo OWNER/REPO --tag models-v1            # manifest + SHA256SUMS, dry run
    python -m tools.models.release ... --publish     # creates the release, uploads assets

Assets are flat names (`full-model.onnx`, `full-vocab.json`, `light-model.onnx`, ...)
plus `manifest.json` and `SHA256SUMS`. After publishing, copy manifest.json to
`assets/models/manifest.json` (A2 owns that folder) so CI's tools/ci/fetch_models.py
downloads and caches the files by SHA-256.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from tools.models import manifest as mf


def gh_commands(release_dir: Path, manifest: dict, repo: str, tag: str, staging: Path) -> list:
    """The `gh` command lines that publish [manifest]'s files from [staging] (which holds
    flat-named copies). Release notes carry the checksums."""
    assets = [str(staging / f["asset"]) for f in manifest["files"]]
    assets += [str(release_dir / "manifest.json"), str(release_dir / "SHA256SUMS")]
    notes = "Phoneme models for UK Pronunciation Coach. SHA-256:\n\n" + "\n".join(
        f"    {f['sha256']}  {f['asset']}  ({f['size']} bytes)" for f in manifest["files"]
    )
    return [
        ["gh", "release", "create", tag, "--repo", repo, "--title", f"Models {tag}"]
        + ["--notes", notes, "--latest=false"]
        + assets
    ]


def stage_assets(release_dir: Path, manifest: dict, staging: Path) -> None:
    """Copies `<tier>/<file>` to flat asset names in [staging] (hard link when possible)."""
    staging.mkdir(parents=True, exist_ok=True)
    for f in manifest["files"]:
        src, dst = release_dir / f["name"], staging / f["asset"]
        if dst.exists():
            dst.unlink()
        try:
            dst.hardlink_to(src)
        except OSError:  # pragma: no cover - cross-device
            shutil.copyfile(src, dst)


def run(
    release_dir: Path,
    repo: str,
    tag: str,
    publish: bool = False,
    runner=subprocess.run,
    which=shutil.which,
) -> int:
    """Writes manifest.json + SHA256SUMS, verifies them, then prints or runs `gh`."""
    manifest = mf.build_manifest(release_dir, tag=tag, repo=repo)
    mf.write_manifest(release_dir, manifest)
    problems = mf.verify_manifest(release_dir)
    if problems:
        for p in problems:
            print(f"ERROR: {p}")
        return 1
    for f in manifest["files"]:
        print(f"{f['sha256']}  {f['name']}  {f['size']:,} bytes")
    if not publish:
        staging = Path(tempfile.gettempdir()) / f"coach-models-{tag}"
        for cmd in gh_commands(release_dir, manifest, repo, tag, staging):
            print("dry run, would run:", " ".join(cmd[:8]), "... <assets>")
        print("dry run: nothing uploaded (pass --publish to create the release)")
        return 0
    if repo == mf.DEFAULT_REPO:
        print("ERROR: pass --repo OWNER/REPO to publish")
        return 2
    if not which("gh"):
        print("ERROR: the GitHub CLI `gh` is required to publish")
        return 127
    with tempfile.TemporaryDirectory() as tmp:
        staging = Path(tmp)
        stage_assets(release_dir, manifest, staging)
        for cmd in gh_commands(release_dir, manifest, repo, tag, staging):
            runner(cmd, check=True)
    print(f"published {tag}; copy {release_dir / 'manifest.json'} to assets/models/manifest.json")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Manifest + GitHub Release for model files")
    parser.add_argument("--release-dir", type=Path, default=Path("tools/models/release"))
    parser.add_argument("--repo", default=mf.DEFAULT_REPO, help="OWNER/REPO on GitHub")
    parser.add_argument("--tag", default="models-v1")
    parser.add_argument("--publish", action="store_true", help="really create the release")
    args = parser.parse_args(argv)
    return run(args.release_dir, args.repo, args.tag, args.publish)


if __name__ == "__main__":
    sys.exit(main())
