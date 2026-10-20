"""Licence check (CI "licences" job).

Fails when:
  * a Dart package resolved in .dart_tool/package_config.json (i.e. pubspec.lock) is
    GPL or AGPL licensed;
  * a Python package listed in any tools/**/requirements*.txt is GPL or AGPL (as
    reported by its installed metadata);
  * a model, voice or dictionary file under assets/ (or in assets/models/manifest.json)
    is not mentioned in docs/licences.md.

Human-approved exceptions go in tools/ci/licence_allowlist.txt, one
`name  # reason` per line. Note: the MPL-2.0 text names the GNU Affero licence as a
possible "Secondary License" (its section 1.12), so classify() reports MPL-2.0
packages as AGPL; approved ones (`dbus`, `nm`) are allowlisted by name. eSpeak NG is used as a binary, not a package, so it never
appears here; keep it out of anything shipped.

    python3 tools/ci/check_licences.py [--root .]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections.abc import Callable, Iterable
from importlib import metadata
from pathlib import Path
from urllib.parse import unquote, urlparse

LICENCE_FILES = ("LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "COPYING", "COPYING.md")
ASSET_DIRS = ("assets/models", "assets/voices")
DICTIONARY_PATTERN = re.compile(r"(britfone|lexicon|dictionary|dict)", re.IGNORECASE)
IGNORED_ASSETS = {"README.md", ".gitkeep", "manifest.json", "SOURCES.md"}


def classify(text: str) -> str:
    """Returns 'agpl', 'gpl', 'lgpl' or 'ok' for licence text or metadata."""
    t = text.upper()
    if "AFFERO" in t or re.search(r"\bAGPL", t):
        return "agpl"
    if "LESSER GENERAL PUBLIC" in t or "LIBRARY GENERAL PUBLIC" in t or re.search(r"\bLGPL", t):
        return "lgpl"
    if "GNU GENERAL PUBLIC LICENSE" in t or re.search(r"\bGPL", t):
        return "gpl"
    return "ok"


def load_allowlist(root: Path) -> set[str]:
    """Package names a human has approved despite the rules."""
    path = root / "tools" / "ci" / "licence_allowlist.txt"
    if not path.exists():
        return set()
    names = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        name = line.split("#", 1)[0].strip()
        if name:
            names.add(name.lower())
    return names


def dart_packages(root: Path) -> list[tuple[str, Path]]:
    """(name, root directory) for every package in package_config.json."""
    config_path = root / ".dart_tool" / "package_config.json"
    if not config_path.exists():
        raise FileNotFoundError(f"{config_path} missing: run `flutter pub get` first")
    config = json.loads(config_path.read_text(encoding="utf-8"))
    base = config_path.parent
    out = []
    for pkg in config.get("packages", []):
        uri = pkg["rootUri"]
        parsed = urlparse(uri)
        if parsed.scheme == "file":
            path = Path(unquote(parsed.path))
        else:
            path = (base / unquote(uri)).resolve()
        out.append((pkg["name"], path))
    return out


def own_package_name(root: Path) -> str | None:
    """The app's own package name from pubspec.yaml."""
    pubspec = root / "pubspec.yaml"
    if not pubspec.exists():
        return None
    match = re.search(r"^name:\s*(\S+)", pubspec.read_text(encoding="utf-8"), re.M)
    return match.group(1) if match else None


def flutter_sdk_root(packages: list[tuple[str, Path]]) -> Path | None:
    """The Flutter SDK directory (parent of packages/flutter), if resolved."""
    for name, path in packages:
        if name == "flutter" and path.parent.name == "packages":
            return path.parent.parent
    return None


def check_dart(root: Path, allow: set[str]) -> tuple[list[str], list[str]]:
    """Returns (errors, warnings) for Dart packages."""
    errors, warnings = [], []
    own = own_package_name(root)
    packages = dart_packages(root)
    sdk = flutter_sdk_root(packages)
    for name, path in packages:
        if name == own or name.lower() in allow:
            continue
        if sdk is not None and path.is_relative_to(sdk):
            # Flutter SDK packages (BSD-3-Clause). sky_engine's LICENSE aggregates the
            # engine's third-party notices and would be misread as GPL.
            continue
        licence = next((path / f for f in LICENCE_FILES if (path / f).exists()), None)
        if licence is None:
            warnings.append(f"dart package {name}: no licence file found in {path}")
            continue
        kind = classify(licence.read_text(encoding="utf-8", errors="replace"))
        if kind in ("gpl", "agpl"):
            errors.append(f"dart package {name}: {kind.upper()} licence ({licence})")
        elif kind == "lgpl":
            warnings.append(f"dart package {name}: LGPL licence, needs review")
    return errors, warnings


def requirement_names(files: Iterable[Path]) -> list[str]:
    """Package names from requirements files (ignores options, comments and URLs)."""
    names = []
    for f in files:
        for line in f.read_text(encoding="utf-8").splitlines():
            line = line.split("#", 1)[0].strip()
            if not line or line.startswith(("-", "git+", "http")):
                continue
            match = re.match(r"[A-Za-z0-9][A-Za-z0-9._-]*", line)
            if match:
                names.append(match.group(0))
    return sorted(set(names), key=str.lower)


def python_licence(name: str) -> str | None:
    """Licence text from installed metadata, or None when not installed."""
    try:
        meta = metadata.metadata(name)
    except metadata.PackageNotFoundError:
        return None
    parts = [meta.get("License") or "", meta.get("License-Expression") or ""]
    parts += [c for c in meta.get_all("Classifier") or [] if c.startswith("License")]
    return " ".join(parts)


def check_python(
    root: Path,
    allow: set[str],
    lookup: Callable[[str], str | None] = python_licence,
) -> tuple[list[str], list[str]]:
    """Returns (errors, warnings) for Python requirements under tools/."""
    errors, warnings = [], []
    files = sorted((root / "tools").rglob("requirements*.txt"))
    for name in requirement_names(files):
        if name.lower() in allow:
            continue
        text = lookup(name)
        if text is None:
            warnings.append(f"python package {name}: not installed, licence not checked")
            continue
        kind = classify(text)
        if kind in ("gpl", "agpl"):
            errors.append(f"python package {name}: {kind.upper()} licence ({text.strip()})")
        elif kind == "lgpl":
            warnings.append(f"python package {name}: LGPL licence, needs review")
    return errors, warnings


def shipped_assets(root: Path) -> list[str]:
    """File names of models, voices and dictionaries that must be in docs/licences.md."""
    names: set[str] = set()
    for folder in ASSET_DIRS:
        d = root / folder
        if d.is_dir():
            for f in d.rglob("*"):
                if f.is_file() and f.name not in IGNORED_ASSETS and f.suffix != ".dart":
                    names.add(f.name)
    manifest = root / "assets" / "models" / "manifest.json"
    if manifest.exists():
        data = json.loads(manifest.read_text(encoding="utf-8"))
        for entry in data.get("files", []):
            names.add(Path(entry["name"]).name)
    content = root / "assets" / "content"
    if content.is_dir():
        for f in content.rglob("*"):
            if f.is_file() and DICTIONARY_PATTERN.search(f.name):
                names.add(f.name)
    return sorted(names)


def check_licence_doc(root: Path) -> list[str]:
    """Every shipped model / voice / dictionary file must be named in docs/licences.md."""
    doc = root / "docs" / "licences.md"
    assets = shipped_assets(root)
    if not doc.exists():
        return ["docs/licences.md is missing"] if assets else []
    text = doc.read_text(encoding="utf-8")
    return [f"docs/licences.md does not mention {name}" for name in assets if name not in text]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Licence check")
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--skip-dart", action="store_true")
    args = parser.parse_args(argv)
    allow = load_allowlist(args.root)
    errors: list[str] = []
    warnings: list[str] = []
    if not args.skip_dart:
        e, w = check_dart(args.root, allow)
        errors += e
        warnings += w
    e, w = check_python(args.root, allow)
    errors += e
    warnings += w
    errors += check_licence_doc(args.root)
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"ERROR: {e}")
    print("licence check:", "FAILED" if errors else "passed")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
