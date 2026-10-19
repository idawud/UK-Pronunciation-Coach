"""SHA-256 manifest for a model release folder.

A release folder looks like this (never committed; `tools/models/release/` is git-ignored):

    release/
      full/model.onnx   full/vocab.json
      light/model.onnx  light/vocab.json
      manifest.json     SHA256SUMS

`manifest.json` uses the format `tools/ci/fetch_models.py` reads (A2 copies it to
`assets/models/manifest.json` once the release is published):

    {"release": "models-v1",
     "files": [{"name": "full/model.onnx", "tier": "full", "asset": "full-model.onnx",
                "url": "https://github.com/<owner>/<repo>/releases/download/models-v1/full-model.onnx",
                "sha256": "<64 hex>", "size": 123, "bundle": false}, ...]}

`SHA256SUMS` is the same information in `sha256sum -c` format (asset names).
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

URL_PLACEHOLDER = "https://github.com/{repo}/releases/download/{tag}/{asset}"
DEFAULT_REPO = "OWNER/REPO"
MODEL_FILES = ("model.onnx", "vocab.json")


def sha256_of(path: Path) -> str:
    """Hex SHA-256 of a file, read in 1 MiB chunks."""
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def asset_name(name: str) -> str:
    """Flat GitHub Release asset name: `full/model.onnx` -> `full-model.onnx`."""
    return name.replace("/", "-")


def build_manifest(
    release_dir: Path,
    tag: str = "models-v1",
    repo: str = DEFAULT_REPO,
    bundle_tiers: tuple[str, ...] = ("light",),
) -> dict:
    """Lists every `<tier>/<file>` in [release_dir] with its SHA-256, size and download URL.

    Light-tier files are marked `bundle: true` (shipped inside the app); the full tier is
    downloaded once on device. Raises FileNotFoundError when no model files are present.
    """
    files = []
    for tier_dir in sorted(p for p in release_dir.iterdir() if p.is_dir()):
        for fname in MODEL_FILES:
            path = tier_dir / fname
            if not path.exists():
                continue
            name = f"{tier_dir.name}/{fname}"
            asset = asset_name(name)
            files.append(
                {
                    "name": name,
                    "tier": tier_dir.name,
                    "asset": asset,
                    "url": URL_PLACEHOLDER.format(repo=repo, tag=tag, asset=asset),
                    "sha256": sha256_of(path),
                    "size": path.stat().st_size,
                    "bundle": tier_dir.name in bundle_tiers,
                }
            )
    if not files:
        raise FileNotFoundError(f"no <tier>/model.onnx or vocab.json under {release_dir}")
    return {"release": tag, "files": files}


def write_manifest(release_dir: Path, manifest: dict) -> tuple[Path, Path]:
    """Writes manifest.json and SHA256SUMS into [release_dir]; returns both paths."""
    manifest_path = release_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    sums_path = release_dir / "SHA256SUMS"
    lines = [f"{f['sha256']}  {f['asset']}" for f in manifest["files"]]
    sums_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return manifest_path, sums_path


def verify_manifest(release_dir: Path) -> list[str]:
    """Re-hashes every file listed in release_dir/manifest.json.

    Returns a list of problems (missing file, size or checksum mismatch); empty when OK.
    """
    manifest = json.loads((release_dir / "manifest.json").read_text(encoding="utf-8"))
    problems = []
    for entry in manifest["files"]:
        path = release_dir / entry["name"]
        if not path.exists():
            problems.append(f"{entry['name']}: missing")
            continue
        if path.stat().st_size != entry["size"]:
            problems.append(f"{entry['name']}: size {path.stat().st_size} != {entry['size']}")
        actual = sha256_of(path)
        if actual != entry["sha256"]:
            problems.append(f"{entry['name']}: sha256 {actual} != {entry['sha256']}")
    return problems
