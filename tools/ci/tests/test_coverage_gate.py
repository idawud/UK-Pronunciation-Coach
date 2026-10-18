import argparse
from pathlib import Path

import pytest

from tools.ci import coverage_gate as cg

LCOV = """SF:lib/engine/scoring/a.dart
DA:1,1
DA:2,0
DA:3,4
end_of_record
SF:lib/engine/scoring/a.g.dart
DA:1,0
end_of_record
SF:{root}/lib/ui/home/home.dart
DA:1,1
DA:2,1
end_of_record
"""


def write(root: Path, rel: str, text: str) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def test_parse_lcov_relative_and_absolute(tmp_path):
    files = cg.parse_lcov(LCOV.format(root=tmp_path.resolve()), tmp_path)
    assert files["lib/engine/scoring/a.dart"].found == 3
    assert files["lib/engine/scoring/a.dart"].hit == 2
    assert files["lib/ui/home/home.dart"].hit == 2


def test_code_lines_ignores_comments_imports_and_braces():
    src = """// comment
import 'x.dart';
/* block
   still */
@override
int f() {
  return 1;
}
"""
    assert cg.code_lines(src) == 2


def test_evaluate_counts_untested_files(tmp_path):
    write(tmp_path, "lib/engine/scoring/a.dart", "int a() {\n  return 1;\n}\n")
    write(tmp_path, "lib/engine/scoring/b.dart", "int b() {\n  return 2;\n}\n")
    write(tmp_path, "lib/engine/scoring/b.freezed.dart", "int c() => 3;\n")
    files = cg.parse_lcov(LCOV.format(root=tmp_path), tmp_path)
    [engine] = cg.evaluate(files, {"lib/engine/": 85}, tmp_path)
    assert engine.untested == ["lib/engine/scoring/b.dart"]
    assert engine.found == 3 + 2
    assert not engine.passed
    [engine2] = cg.evaluate(files, {"lib/engine/": 60}, tmp_path, include_untested=False)
    assert engine2.percent == pytest.approx(200 / 3)
    assert engine2.passed


def test_empty_folder_is_skipped(tmp_path):
    [r] = cg.evaluate({}, {"lib/practice/": 85}, tmp_path)
    assert r.percent is None and r.passed


def test_main_pass_fail_and_missing(tmp_path, capsys):
    lcov = tmp_path / "lcov.info"
    lcov.write_text(LCOV.format(root=tmp_path), encoding="utf-8")
    assert cg.main([str(lcov), "--root", str(tmp_path), "--gate", "lib/ui=70"]) == 0
    assert cg.main([str(lcov), "--root", str(tmp_path), "--gate", "lib/engine/=90"]) == 1
    assert cg.main([str(lcov), "--root", str(tmp_path)]) == 1  # default gates
    assert cg.main([str(tmp_path / "nope.info")]) == 2
    out = capsys.readouterr().out
    assert "FAIL" in out and "skip" in out


def test_parse_gate_rejects_garbage():
    with pytest.raises(argparse.ArgumentTypeError):
        cg.parse_gate("lib/engine")
    assert cg.parse_gate("lib/x=50") == ("lib/x/", 50.0)
