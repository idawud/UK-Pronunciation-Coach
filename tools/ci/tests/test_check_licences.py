import json
from pathlib import Path

from tools.ci import check_licences as cl

MIT = "Permission is hereby granted, free of charge, to any person obtaining a copy"
GPL = "GNU GENERAL PUBLIC LICENSE Version 3"


def make_repo(tmp_path: Path, packages: dict[str, str | None]) -> Path:
    (tmp_path / ".dart_tool").mkdir()
    (tmp_path / "pubspec.yaml").write_text("name: app\n", encoding="utf-8")
    entries = [{"name": "app", "rootUri": "../"}]
    for name, licence in packages.items():
        pkg = tmp_path / "cache" / name
        pkg.mkdir(parents=True)
        if licence is not None:
            (pkg / "LICENSE").write_text(licence, encoding="utf-8")
        entries.append({"name": name, "rootUri": pkg.as_uri()})
    entries.append({"name": "rel", "rootUri": "../cache/rel"})
    (tmp_path / "cache" / "rel").mkdir(parents=True)
    (tmp_path / "cache" / "rel" / "LICENSE.md").write_text(MIT, encoding="utf-8")
    (tmp_path / ".dart_tool" / "package_config.json").write_text(
        json.dumps({"configVersion": 2, "packages": entries}), encoding="utf-8"
    )
    return tmp_path


def test_flutter_sdk_packages_are_skipped(tmp_path):
    root = make_repo(tmp_path, {})
    sdk = tmp_path / "flutter"
    for rel in ("packages/flutter", "bin/cache/pkg/sky_engine"):
        (sdk / rel).mkdir(parents=True)
    (sdk / "bin/cache/pkg/sky_engine/LICENSE").write_text(GPL, encoding="utf-8")
    config = root / ".dart_tool" / "package_config.json"
    data = json.loads(config.read_text(encoding="utf-8"))
    data["packages"] += [
        {"name": "flutter", "rootUri": (sdk / "packages/flutter").as_uri()},
        {"name": "sky_engine", "rootUri": (sdk / "bin/cache/pkg/sky_engine").as_uri()},
    ]
    config.write_text(json.dumps(data), encoding="utf-8")
    errors, warnings = cl.check_dart(root, set())
    assert errors == [] and warnings == []


def test_classify():
    assert cl.classify(MIT) == "ok"
    assert cl.classify(GPL) == "gpl"
    assert cl.classify("GNU AFFERO GENERAL PUBLIC LICENSE") == "agpl"
    assert cl.classify("GNU LESSER GENERAL PUBLIC LICENSE") == "lgpl"
    assert cl.classify("License :: OSI Approved :: GNU General Public License v3 (GPLv3)") == "gpl"


def test_dart_packages_flagged(tmp_path):
    root = make_repo(
        tmp_path,
        {"good": MIT, "bad": GPL, "lesser": "GNU LESSER GENERAL PUBLIC", "none": None},
    )
    errors, warnings = cl.check_dart(root, set())
    assert errors == [f"dart package bad: GPL licence ({root / 'cache/bad/LICENSE'})"]
    assert any("lesser" in w for w in warnings)
    assert any("none" in w for w in warnings)
    errors, _ = cl.check_dart(root, {"bad"})
    assert errors == []


def test_python_requirements(tmp_path):
    req = tmp_path / "tools" / "x" / "requirements.txt"
    req.parent.mkdir(parents=True)
    req.write_text(
        "# comment\nnumpy==2.0\n-r other.txt\nphonemizer>=3\nmissing\nlgplpkg\n",
        encoding="utf-8",
    )
    licences = {"numpy": "BSD-3-Clause", "phonemizer": "GPL-3.0", "lgplpkg": "LGPL-2.1"}
    errors, warnings = cl.check_python(tmp_path, set(), licences.get)
    assert len(errors) == 1 and "phonemizer" in errors[0]
    assert any("missing" in w for w in warnings)
    assert any("lgplpkg" in w for w in warnings)
    errors, _ = cl.check_python(tmp_path, {"phonemizer"}, licences.get)
    assert errors == []
    assert cl.python_licence("definitely-not-installed-pkg") is None
    assert cl.python_licence("pytest") is not None


def test_licence_doc_lists_assets(tmp_path):
    assert cl.check_licence_doc(tmp_path) == []
    models = tmp_path / "assets" / "models"
    models.mkdir(parents=True)
    (models / "light.onnx").write_bytes(b"x")
    (models / "README.md").write_text("x", encoding="utf-8")
    (models / "manifest.json").write_text(
        json.dumps({"files": [{"name": "full/full.onnx"}]}), encoding="utf-8"
    )
    content = tmp_path / "assets" / "content"
    content.mkdir(parents=True)
    (content / "britfone.tsv").write_text("x", encoding="utf-8")
    (content / "passages.v1.json").write_text("[]", encoding="utf-8")
    assert cl.check_licence_doc(tmp_path) == ["docs/licences.md is missing"]
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "licences.md").write_text("light.onnx britfone.tsv", encoding="utf-8")
    assert cl.check_licence_doc(tmp_path) == ["docs/licences.md does not mention full.onnx"]


def test_allowlist_and_main(tmp_path, capsys):
    root = make_repo(tmp_path, {"good": MIT})
    (root / "tools" / "ci").mkdir(parents=True)
    (root / "tools" / "ci" / "licence_allowlist.txt").write_text(
        "# approved\nSomePkg  # reason\n", encoding="utf-8"
    )
    assert cl.load_allowlist(root) == {"somepkg"}
    assert cl.main(["--root", str(root)]) == 0
    make_bad = root / "cache" / "good" / "LICENSE"
    make_bad.write_text(GPL, encoding="utf-8")
    assert cl.main(["--root", str(root)]) == 1
    assert cl.main(["--root", str(root), "--skip-dart"]) == 0
    assert "ERROR" in capsys.readouterr().out


def test_missing_package_config(tmp_path):
    try:
        cl.dart_packages(tmp_path)
    except FileNotFoundError as e:
        assert "flutter pub get" in str(e)
    else:
        raise AssertionError("expected FileNotFoundError")
    assert cl.own_package_name(tmp_path) is None
