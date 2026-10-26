"""Tests for the icon generator (tools/release/icons.py)."""

from __future__ import annotations

import json
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

from tools.release import icons

REPO = Path(__file__).resolve().parents[3]


def test_committed_icons_are_up_to_date():
    assert icons.main(["--root", str(REPO), "--check"]) == 0


def test_check_reports_stale_files_and_write_fixes_them(tmp_path):
    appicon = tmp_path / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    appicon.mkdir(parents=True)
    shutil.copy(REPO / appicon.relative_to(tmp_path) / "Contents.json", appicon)
    assert icons.main(["--root", str(tmp_path), "--check"]) == 1
    assert icons.main(["--root", str(tmp_path)]) == 0
    assert icons.main(["--root", str(tmp_path), "--check"]) == 0


def test_full_bleed_icon_is_opaque_and_navy_at_the_corner():
    img = icons.render(64)
    assert img.mode == "RGB"  # the App Store rejects icons with alpha
    assert img.size == (64, 64)
    assert img.getpixel((0, 0)) == (0x1F, 0x4E, 0x79)
    # The bubble is white between the bars, near its top.
    assert img.getpixel((29, 15)) == (255, 255, 255)


def test_transparent_render_keeps_alpha():
    img = icons.render(32, view=(0, 0, 108, 108), background=None)
    assert img.mode == "RGBA"
    assert img.getpixel((0, 0))[3] == 0


def test_artwork_fits_the_adaptive_icon_safe_area():
    # Launchers mask to a circle of diameter 66 (Android 12 splash: 72) around (54, 54).
    corners = [
        (icons.BUBBLE.x0 + icons.BUBBLE.r * 0.3, icons.BUBBLE.y0 + icons.BUBBLE.r * 0.3),
        (icons.BUBBLE.x1 - icons.BUBBLE.r * 0.3, icons.BUBBLE.y1 - icons.BUBBLE.r * 0.3),
        *icons.TAIL,
    ]
    for x, y in corners:
        assert ((x - 54) ** 2 + (y - 54) ** 2) ** 0.5 <= 36


def test_vectors_are_valid_xml_with_the_expected_paths():
    ns = "{http://schemas.android.com/apk/res/android}"
    fg = ET.fromstring(icons.foreground_vector().split("\n", 2)[2])
    assert [p.get(f"{ns}fillColor") for p in fg] == ["#FFFFFF", "#1F4E79"]
    mono = ET.fromstring(icons.silhouette_vector(24).split("\n", 2)[2])
    assert mono.get(f"{ns}width") == "24dp"
    assert [p.get(f"{ns}fillType") for p in mono] == ["evenOdd"]
    ET.fromstring(icons.ADAPTIVE_XML.split("\n", 2)[2])
    svg = ET.fromstring(icons.master_svg().split("\n", 2)[2])
    assert svg.get("width") == "1024"


def test_round_rect_path_has_four_arcs():
    path = icons.round_rect_path(icons.RoundRect(0, 0, 10, 10, 2))
    assert path.count("A") == 4 and path.startswith("M2,0") and path.endswith("Z")


def test_ios_icon_sizes_from_contents_json():
    contents = json.dumps(
        {
            "images": [
                {"size": "83.5x83.5", "scale": "2x", "filename": "a.png"},
                {"size": "20x20", "scale": "3x", "filename": "b.png"},
                {"size": "60x60", "scale": "2x"},
            ]
        }
    )
    assert icons.ios_icon_sizes(contents) == {"a.png": 167, "b.png": 60}


def test_generated_ios_icons_match_their_declared_sizes():
    appicon = REPO / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    sizes = icons.ios_icon_sizes((appicon / "Contents.json").read_text(encoding="utf-8"))
    for name, px in sizes.items():
        with Image.open(appicon / name) as img:
            assert img.size == (px, px), name
            assert img.mode == "RGB", name
