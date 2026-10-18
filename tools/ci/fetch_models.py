"""Download model files listed in assets/models/manifest.json and verify SHA-256.

Used by CI (integration.yml) and developers. Files are cached by SHA-256 in a cache
directory (CI caches it with actions/cache keyed on the manifest), then copied to
their destination. Nothing here runs inside the app.

Manifest format (A4 publishes the files as GitHub Release assets, A2 loads them):

    {
      "files": [
        {"name": "light/model.onnx", "tier": "light",
         "url": "https://github.com/<owner>/<repo>/releases/download/models-v1/light-model.onnx",
         "sha256": "<64 hex>", "size": 94371840, "bundle": true}
      ]
    }

`bundle: true` files are copied into assets/models/<name> (bundled in the app build);
others (the full tier) are only cached for on-device tests.

    python3 tools/ci/fetch_models.py [--root .] [--cache .model-cache] [--tier light]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import urllib.request
from pathlib import Path

MANIFEST = Path("assets/models/manifest.json")


def sha256_of(path: Path) -> str:
    """Hex SHA-256 of a file."""
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, dest: Path) -> None:
    """Downloads [url] to [dest] atomically."""
    tmp = dest.with_suffix(dest.suffix + ".part")
    with urllib.request.urlopen(url) as response, tmp.open("wb") as out:  # noqa: S310
        shutil.copyfileobj(response, out)
    tmp.replace(dest)


def fetch(
    root: Path,
    cache: Path,
    tier: str | None = None,
    downloader=download,
) -> list[Path]:
    """Ensures every manifest file is cached and verified; copies bundled ones into
    assets/models/. Returns the cached paths. Raises ValueError on a bad checksum."""
    manifest_path = root / MANIFEST
    if not manifest_path.exists():
        print(f"fetch models: {MANIFEST} not found yet (A4/A2 add it); nothing to do")
        return []
    entries = json.loads(manifest_path.read_text(encoding="utf-8")).get("files", [])
    cache.mkdir(parents=True, exist_ok=True)
    cached = []
    for entry in entries:
        if tier and entry.get("tier") not in (None, tier):
            continue
        expected = entry["sha256"].lower()
        target = cache / expected
        if not target.exists() or sha256_of(target) != expected:
            print(f"downloading {entry['name']}")
            downloader(entry["url"], target)
            actual = sha256_of(target)
            if actual != expected:
                target.unlink()
                raise ValueError(f"{entry['name']}: sha256 {actual} != {expected}")
        else:
            print(f"cached {entry['name']}")
        cached.append(target)
        if entry.get("bundle"):
            dest = root / "assets" / "models" / entry["name"]
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(target, dest)
    return cached


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Fetch model files")
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--cache", type=Path, default=Path(".model-cache"))
    parser.add_argument("--tier", choices=["light", "full"])
    args = parser.parse_args(argv)
    try:
        fetch(args.root, args.cache, args.tier)
    except ValueError as e:
        print(f"ERROR: {e}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
