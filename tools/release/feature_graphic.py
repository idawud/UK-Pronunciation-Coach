"""Google Play feature graphic, 1024 x 500 (R1-release). Dev-side only; nothing here ships.

Uses the app's own colours (navy seed #1F4E79, white) and the icon's speech-bubble and
waveform shapes from tools/release/icons.py. No stock imagery. The text makes no claim the
app cannot support. Regenerate (the PNG is committed):

    python -m tools.release.feature_graphic            # from the repo root
    python -m tools.release.feature_graphic --check    # fail if the PNG is stale
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from tools.release.icons import NAVY, WHITE, png_bytes, render

SIZE = (1024, 500)
OUTPUT = "store/play/feature-graphic.png"
TITLE = "UK Pronunciation Coach"
TAGLINE = "Read aloud. See which words to fix."
SUBLINE = "British English practice that works offline."
TEXT_X = 380
MARGIN = 60


def _font(size: int) -> ImageFont.ImageFont | ImageFont.FreeTypeFont:
    """Pillow's bundled font, so the PNG is the same on every machine (no system fonts)."""
    return ImageFont.load_default(size)


def render_graphic() -> Image.Image:
    _, h = SIZE
    img = Image.new("RGB", SIZE, NAVY)
    icon = render(280, background=None)
    img.paste(icon, (70, (h - 280) // 2), icon)
    draw = ImageDraw.Draw(img)
    x = TEXT_X
    draw.text((x, 155), TITLE, font=_font(48), fill=WHITE)
    draw.text((x, 235), TAGLINE, font=_font(28), fill=WHITE)
    draw.text((x, 282), SUBLINE, font=_font(24), fill="#C9DDF0")
    return img


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--check", action="store_true", help="fail if the PNG is stale")
    args = parser.parse_args(argv)
    path = args.root / OUTPUT
    data = png_bytes(render_graphic())
    if path.exists() and path.read_bytes() == data:
        print("0 file(s) written")
        return 0
    if args.check:
        print(f"Stale: {path} (run python -m tools.release.feature_graphic)", file=sys.stderr)
        return 1
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print("1 file(s) written")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
