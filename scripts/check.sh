#!/usr/bin/env bash
# Local pre-push check. Mirrors the ci.yml jobs that can run on a laptop:
# format, analyze, tests + coverage gate, goldens (Linux only), Python (ruff + pytest),
# content check and licence check. Android builds and on-device tests run in CI only.
#
#   scripts/check.sh            # everything
#   scripts/check.sh --quick    # skip goldens and Python
set -euo pipefail
cd "$(dirname "$0")/.."

QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

if ! command -v flutter >/dev/null 2>&1 && [[ -x "$HOME/flutter/bin/flutter" ]]; then
  export PATH="$HOME/flutter/bin:$PATH"
fi
if [[ -x .venv/bin/python ]]; then PY=.venv/bin/python; else PY=python3; fi

step() { printf '\n==> %s\n' "$*"; }
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "check.sh: '$1' not found. $2" >&2
    exit 127
  fi
}
need flutter "Install the Flutter SDK (see docs/testing.md)."
need dart "Install the Flutter SDK (see docs/testing.md)."

step "flutter pub get"
flutter pub get >/dev/null

step "dart format (generated *.g.dart / *.freezed.dart excluded)"
git ls-files -co --exclude-standard -- '*.dart' |
  grep -vE '\.(g|freezed)\.dart$' |
  xargs dart format --output=none --set-exit-if-changed

step "flutter analyze --fatal-infos"
flutter analyze --fatal-infos

step "flutter test --coverage (timing tests excluded)"
if [[ "$(uname -s)" == "Linux" && $QUICK == 0 ]]; then
  flutter test --coverage --exclude-tags perf
else
  echo "(golden tests skipped: readable goldens only render on Linux; CI runs them)"
  flutter test --coverage --exclude-tags golden,perf
fi

step "timing tests (tag perf), one at a time"
flutter test --tags perf --concurrency=1

step "coverage gate"
"$PY" tools/ci/coverage_gate.py coverage/lcov.info

if [[ $QUICK == 0 ]]; then
  step "python: ruff + pytest (tools/)"
  if ! "$PY" -c 'import pytest, ruff' >/dev/null 2>&1 && ! "$PY" -m ruff --version >/dev/null 2>&1; then
    echo "check.sh: pytest/ruff missing. Run: python3 -m venv .venv && .venv/bin/pip install -r tools/requirements-dev.txt" >&2
    exit 127
  fi
  "$PY" -m ruff check tools
  "$PY" -m ruff format --check tools
  "$PY" -m pytest tools --cov -q
fi

step "content check"
"$PY" tools/ci/check_content.py

step "licence check"
"$PY" tools/ci/check_licences.py

printf '\nAll checks passed.\n'
