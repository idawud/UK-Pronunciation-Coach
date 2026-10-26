"""App size check (R1-release): SPEC target, download under 150 MB.

Reads a built APK, AAB or IPA (all zip files) and prints its size by part, then
fails when the file is larger than the limit. A split-per-ABI APK or an IPA is close
to what a phone downloads (the stores compress a little further); for an AAB, use
bundletool for the per-device figure (docs/release.md, "App size").

    python -m tools.release.app_size build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
    python -m tools.release.app_size --limit-mb 150 build/ios/ipa/*.ipa
"""

from __future__ import annotations

import argparse
import sys
import zipfile
from collections import defaultdict
from pathlib import Path

MB = 1_000_000
DEFAULT_LIMIT_MB = 150.0

# (part, file-name endings, path fragments); first match wins.
PARTS = (
    ("speech models", (".onnx",), ()),
    (
        "native code",
        (".so", ".dylib", "Flutter.framework/Flutter", "App.framework/App", ".app/Runner"),
        (),
    ),
    ("app code (dex)", (".dex",), ()),
    ("passages and dictionary", (), ("assets/content/",)),
    ("fonts", (".ttf", ".otf"), ()),
)


def part_of(name: str) -> str:
    """Which part of the app a zip entry belongs to."""
    for part, endings, fragments in PARTS:
        if name.endswith(endings) or any(f in name for f in fragments):
            return part
    return "other"


def breakdown(path: Path) -> dict[str, tuple[int, int]]:
    """part -> (bytes stored in the archive, bytes once installed)."""
    sizes: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    with zipfile.ZipFile(path) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            entry = sizes[part_of(info.filename)]
            entry[0] += info.compress_size
            entry[1] += info.file_size
    return {k: (v[0], v[1]) for k, v in sorted(sizes.items(), key=lambda kv: -kv[1][0])}


def report(path: Path, limit_mb: float) -> tuple[bool, str]:
    """(within the limit, printable report) for one archive."""
    size = path.stat().st_size
    lines = [f"{path.name}: {size / MB:.1f} MB (limit {limit_mb:.0f} MB)"]
    for part, (stored, installed) in breakdown(path).items():
        lines.append(
            f"  {part:<26} {stored / MB:8.1f} MB stored {installed / MB:8.1f} MB installed"
        )
    ok = size <= limit_mb * MB
    lines.append("  OK" if ok else "  TOO LARGE")
    return ok, "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="App size by part, against a limit.")
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--limit-mb", type=float, default=DEFAULT_LIMIT_MB)
    args = parser.parse_args(argv)
    all_ok = True
    for path in args.files:
        try:
            ok, text = report(path, args.limit_mb)
        except (OSError, zipfile.BadZipFile) as e:
            print(f"{path}: cannot read ({e})", file=sys.stderr)
            return 2
        print(text)
        all_ok &= ok
    return 0 if all_ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
