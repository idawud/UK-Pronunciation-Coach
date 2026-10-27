"""Tests for the privacy-policy page builder (tools/release/site.py)."""

from __future__ import annotations

import re

from tools.release import site


def test_markdown_subset_converts():
    out = site.markdown_to_html("# T <x>\n\nHi **b**.\n\n- one\n  more\n- two\n\nEnd")
    assert "<title>T &lt;x&gt;</title>" in out
    assert "<h1>T &lt;x&gt;</h1>" in out
    assert "<strong>b</strong>" in out
    assert "<ul>\n<li>one more</li>\n<li>two</li>\n</ul>\n<p>End</p>" in out


def test_build_writes_a_page_with_no_scripts_or_external_resources(tmp_path):
    site.build(tmp_path)
    page = (tmp_path / "privacy/index.html").read_text(encoding="utf-8")
    assert "UK Pronunciation Coach" in page and "never uploaded" in page
    assert not re.search(r"<script|<link|<img|https?://", page, re.I)
    assert (tmp_path / ".nojekyll").exists()


def test_main_writes_to_out(tmp_path):
    assert site.main(["--out", str(tmp_path / "s")]) == 0
    assert (tmp_path / "s/index.html").exists()
