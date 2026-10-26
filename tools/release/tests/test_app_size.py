"""Tests for the app size check (tools/release/app_size.py)."""

from __future__ import annotations

import os
import zipfile

import pytest

from tools.release import app_size


def make_apk(path, entries):
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for name, data in entries.items():
            z.writestr(name, data)
    return path


@pytest.mark.parametrize(
    ("name", "part"),
    [
        ("assets/flutter_assets/assets/models/light-model.onnx", "speech models"),
        ("lib/arm64-v8a/libonnxruntime.so", "native code"),
        ("Payload/Runner.app/Frameworks/Flutter.framework/Flutter", "native code"),
        ("classes.dex", "app code (dex)"),
        ("assets/flutter_assets/assets/content/passages.v1.json", "passages and dictionary"),
        ("assets/flutter_assets/assets/fonts/NotoSans-Regular.ttf", "fonts"),
        ("Payload/Runner.app/Runner", "native code"),
        ("Payload/Runner.app/Info.plist", "other"),
        ("AndroidManifest.xml", "other"),
    ],
)
def test_part_of(name, part):
    assert app_size.part_of(name) == part


def test_breakdown_and_report(tmp_path):
    apk = make_apk(
        tmp_path / "app.apk",
        {
            "assets/flutter_assets/assets/models/light-model.onnx": os.urandom(4000),
            "lib/arm64-v8a/libapp.so": b"\0" * 10_000,
            "classes.dex": b"dex",
        },
    )
    parts = app_size.breakdown(apk)
    assert list(parts)[0] == "speech models"  # largest stored part first
    assert parts["native code"][1] == 10_000
    assert parts["native code"][0] < 10_000  # zeros compress
    ok, text = app_size.report(apk, limit_mb=1)
    assert ok and "OK" in text and "speech models" in text


def test_main_limits(tmp_path, capsys):
    apk = make_apk(tmp_path / "big.apk", {"m.onnx": os.urandom(30_000)})
    assert app_size.main([str(apk)]) == 0
    assert app_size.main([str(apk), "--limit-mb", "0.01"]) == 1
    assert "TOO LARGE" in capsys.readouterr().out
    (tmp_path / "bad.apk").write_text("not a zip")
    assert app_size.main([str(tmp_path / "bad.apk")]) == 2
