"""Tests for the Play feature graphic generator (tools/release/feature_graphic.py)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from tools.release import feature_graphic as fg
from tools.release.icons import NAVY

REPO = Path(__file__).resolve().parents[3]


def test_committed_graphic_is_1024_by_500_rgb_and_up_to_date():
    with Image.open(REPO / fg.OUTPUT) as img:
        assert img.size == (1024, 500)
        assert img.mode == "RGB"  # Play: 24-bit PNG or JPEG, no alpha
    assert fg.main(["--root", str(REPO), "--check"]) == 0


def test_background_is_the_app_navy():
    assert fg.render_graphic().getpixel((0, 0)) == (0x1F, 0x4E, 0x79)
    assert NAVY == "#1F4E79"


def test_text_fits_inside_the_canvas():
    draw = ImageDraw.Draw(Image.new("RGB", fg.SIZE))
    for text, size in ((fg.TITLE, 48), (fg.TAGLINE, 28), (fg.SUBLINE, 24)):
        right = fg.TEXT_X + draw.textlength(text, font=fg._font(size))
        assert right <= fg.SIZE[0] - fg.MARGIN, text


def test_check_fails_when_stale_and_write_fixes_it(tmp_path):
    assert fg.main(["--root", str(tmp_path), "--check"]) == 1
    assert fg.main(["--root", str(tmp_path)]) == 0
    assert fg.main(["--root", str(tmp_path), "--check"]) == 0
