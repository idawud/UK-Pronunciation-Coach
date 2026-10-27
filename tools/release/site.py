"""Builds the privacy-policy web page for GitHub Pages (R1-release). Dev-side only.

Turns store/privacy-policy.md (the single source) into plain HTML: no scripts, no external
fonts, no trackers. The Pages workflow runs it and publishes the output folder:

    python -m tools.release.site --out _site
"""

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
POLICY = REPO / "store/privacy-policy.md"
POLICY_URL = "https://idawud.github.io/UK-Pronunciation-Coach/privacy/"

_CSS = (
    "body{font:1rem/1.6 system-ui,sans-serif;max-width:40rem;margin:2rem auto;padding:0 1rem;"
    "color:#1b1b1b;background:#fff}h1{font-size:1.6rem;color:#1f4e79}li{margin:.5rem 0}"
    "@media(prefers-color-scheme:dark){body{color:#e8e8e8;background:#121212}"
    "h1{color:#9ec5ea}}"
)


def _inline(text: str) -> str:
    return re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", html.escape(text, quote=False))


def markdown_to_html(md: str) -> str:
    """Converts the small Markdown subset the policy uses: #, ##, paragraphs, - lists, **bold**."""
    out: list[str] = []
    in_list = False
    title = "Privacy policy"
    for raw in md.splitlines():
        line = raw.rstrip()
        item = re.match(r"^[-*] (.*)", line)
        if in_list and not item and not line.startswith("  "):
            out.append("</ul>")
            in_list = False
        if not line:
            continue
        if item:
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{_inline(item.group(1))}")
        elif line.startswith("  ") and in_list:
            out[-1] += " " + _inline(line.strip())
        elif m := re.match(r"^(#{1,3}) (.*)", line):
            level = len(m.group(1))
            if level == 1:
                title = m.group(2)
            out.append(f"<h{level}>{_inline(m.group(2))}</h{level}>")
        else:
            out.append(f"<p>{_inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    body = "\n".join(o + "</li>" if o.startswith("<li>") else o for o in out)
    return (
        '<!doctype html>\n<html lang="en-GB">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width,initial-scale=1">\n'
        f"<title>{html.escape(title)}</title>\n<style>{_CSS}</style>\n</head>\n"
        f"<body>\n{body}\n</body>\n</html>\n"
    )


def build(out: Path, policy: Path = POLICY) -> list[Path]:
    """Writes the site under out/ and returns the files written."""
    page = markdown_to_html(policy.read_text(encoding="utf-8"))
    files = {
        out / "privacy/index.html": page,
        out / "index.html": (
            '<!doctype html>\n<html lang="en-GB"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            "<title>UK Pronunciation Coach</title></head><body>"
            '<p><a href="privacy/">Privacy policy</a></p></body></html>\n'
        ),
        out / ".nojekyll": "",
    }
    for path, text in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return list(files)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=Path("_site"))
    args = parser.parse_args(argv)
    written = build(args.out)
    print(f"{len(written)} file(s) written to {args.out}; policy URL: {POLICY_URL}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
