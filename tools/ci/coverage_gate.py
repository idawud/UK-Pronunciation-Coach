"""Per-folder line-coverage gate for Flutter's coverage/lcov.info.

    python3 tools/ci/coverage_gate.py coverage/lcov.info
    python3 tools/ci/coverage_gate.py coverage/lcov.info --gate lib/engine/=85

Default gates (docs/testing.md): 85% for lib/engine/, lib/practice/ and lib/data/,
70% for lib/ui/. Generated files (*.g.dart, *.freezed.dart) are ignored.

`flutter test --coverage` only reports files that some test imports, so a file nobody
tests would be invisible. The gate therefore scans each gated folder and counts the
code lines of unreported files as uncovered (disable with --no-untested).
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_GATES: dict[str, float] = {
    "lib/engine/": 85.0,
    "lib/practice/": 85.0,
    "lib/data/": 85.0,
    "lib/ui/": 70.0,
}
GENERATED = (".g.dart", ".freezed.dart", ".gr.dart", ".mocks.dart")
_NOT_CODE = re.compile(
    r"^\s*(//.*|/\*.*|\*.*|import\s.*|export\s.*|part\s.*|library\b.*|@\w+.*|[{}()\[\];,]*)\s*$"
)


@dataclass
class FileCov:
    """Line counts for one source file."""

    found: int = 0
    hit: int = 0
    lines: dict[int, int] = field(default_factory=dict)


def parse_lcov(text: str, root: Path | None = None) -> dict[str, FileCov]:
    """Parses lcov text into {relative path: FileCov} using DA records."""
    files: dict[str, FileCov] = {}
    current: FileCov | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("SF:"):
            path = Path(line[3:])
            if root is not None and path.is_absolute():
                try:
                    path = path.relative_to(root.resolve())
                except ValueError:
                    pass
            current = files.setdefault(path.as_posix(), FileCov())
        elif line.startswith("DA:") and current is not None:
            number, count = line[3:].split(",")[:2]
            current.lines[int(number)] = max(current.lines.get(int(number), 0), int(count))
        elif line == "end_of_record":
            current = None
    for cov in files.values():
        cov.found = len(cov.lines)
        cov.hit = sum(1 for c in cov.lines.values() if c > 0)
    return files


def is_generated(path: str) -> bool:
    """True for code-generator output."""
    return path.endswith(GENERATED)


def code_lines(source: str) -> int:
    """Rough count of executable lines in a Dart file that no test loaded."""
    count = 0
    in_block_comment = False
    for line in source.splitlines():
        stripped = line.strip()
        if in_block_comment:
            in_block_comment = "*/" not in stripped
            continue
        if stripped.startswith("/*"):
            in_block_comment = "*/" not in stripped
            continue
        if not stripped or _NOT_CODE.match(stripped):
            continue
        count += 1
    return count


@dataclass
class GateResult:
    """Outcome for one folder."""

    folder: str
    minimum: float
    found: int
    hit: int
    untested: list[str]

    @property
    def percent(self) -> float | None:
        return None if self.found == 0 else 100.0 * self.hit / self.found

    @property
    def passed(self) -> bool:
        return self.percent is None or self.percent + 1e-9 >= self.minimum


def evaluate(
    files: dict[str, FileCov],
    gates: dict[str, float],
    root: Path,
    include_untested: bool = True,
) -> list[GateResult]:
    """Applies each folder gate."""
    results = []
    for folder, minimum in gates.items():
        found = hit = 0
        reported = set()
        for path, cov in files.items():
            if path.startswith(folder) and not is_generated(path):
                found += cov.found
                hit += cov.hit
                reported.add(path)
        untested = []
        folder_dir = root / folder
        if include_untested and folder_dir.is_dir():
            for dart in sorted(folder_dir.rglob("*.dart")):
                rel = dart.relative_to(root).as_posix()
                if rel in reported or is_generated(rel):
                    continue
                lines = code_lines(dart.read_text(encoding="utf-8"))
                if lines:
                    untested.append(rel)
                    found += lines
        results.append(GateResult(folder, minimum, found, hit, untested))
    return results


def parse_gate(value: str) -> tuple[str, float]:
    """Parses 'folder=percent'."""
    folder, _, percent = value.partition("=")
    if not folder or not percent:
        raise argparse.ArgumentTypeError(f"expected folder=percent, got {value!r}")
    return (folder if folder.endswith("/") else folder + "/", float(percent))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Per-folder coverage gate")
    parser.add_argument("lcov", type=Path)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--gate", type=parse_gate, action="append", default=None)
    parser.add_argument("--no-untested", action="store_true")
    args = parser.parse_args(argv)
    if not args.lcov.exists():
        print(f"coverage gate: {args.lcov} not found (run flutter test --coverage)")
        return 2
    gates = dict(args.gate) if args.gate else DEFAULT_GATES
    files = parse_lcov(args.lcov.read_text(encoding="utf-8"), args.root)
    results = evaluate(files, gates, args.root, not args.no_untested)
    failed = False
    for r in results:
        if r.percent is None:
            print(f"  skip  {r.folder:<16} no Dart code yet (gate {r.minimum:.0f}%)")
            continue
        status = "ok  " if r.passed else "FAIL"
        print(
            f"  {status}  {r.folder:<16} {r.percent:5.1f}% "
            f"({r.hit}/{r.found} lines, gate {r.minimum:.0f}%)"
        )
        for path in r.untested:
            print(f"          untested file counted as 0%: {path}")
        failed |= not r.passed
    print("coverage gate:", "FAILED" if failed else "passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
