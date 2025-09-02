#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
generate_deck.py
A thin wrapper around run_build.build() that:
- loads a style YAML,
- merges CLI options with style defaults,
- passes a single 'assets' dict + palette + icons to run_build,
- supports hyphenated flags (PowerShell-friendly).

"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List, Optional

# Prefer your existing style_manager if present; otherwise parse YAML directly.
def _load_style(path: str) -> Dict:
    try:
        from style_manager import load_style  # type: ignore
        return load_style(path) if path and Path(path).exists() else {}
    except Exception:
        pass

    try:
        import yaml  # type: ignore
        if path and Path(path).exists():
            with open(path, "r", encoding="utf-8") as f:
                return yaml.safe_load(f) or {}
    except Exception:
        return {}
    return {}

def _g(p: Optional[str]) -> str:
    """Return absolute path if file exists, else ''."""
    if not p:
        return ""
    pth = Path(p)
    if pth.exists():
        return str(pth.resolve())
    return ""

def _from_style(d: Dict, *keys, default: str = "") -> str:
    """Read nested keys from style dict; return '' if missing."""
    cur = d
    try:
        for k in keys:
            if not isinstance(cur, dict):  # safety
                return default
            cur = cur.get(k, {})
        if isinstance(cur, str):
            return cur
        return default
    except Exception:
        return default

def main():
    ap = argparse.ArgumentParser(description="Generate a styled PowerPoint deck from HTML inputs.")
    ap.add_argument("-i", "--inputs", nargs="+", required=True, help="HTML input files")
    ap.add_argument("-o", "--output", required=True, help="Output PPTX filename")
    ap.add_argument("--style", default="style_template.yaml", help="Path to style YAML")
    ap.add_argument("--month", default="", help="Month label for slides, e.g., 'September 2025'")

    # Optional asset overrides (hyphenated)
    ap.add_argument("--cover", default="", help="Background image for cover slide")
    ap.add_argument("--agenda-bg", dest="agenda", default="", help="Background for agenda slide")
    ap.add_argument("--separator", default="", help="Background for separator slides")
    ap.add_argument("--conclusion-bg", dest="conclusion", default="", help="Background for conclusion slide")
    ap.add_argument("--thankyou", default="", help="Background for thank-you slide")
    ap.add_argument("--brand-bg", dest="brand_bg", default="", help="Background for item slides")
    ap.add_argument("--cover-title", default="", help="Cover slide title (override style)")
    ap.add_argument("--cover-dates", default="", help="Cover slide date text")
    ap.add_argument("--logo", default="", help="Primary logo")
    ap.add_argument("--logo2", default="", help="Secondary logo")

    # Icons
    ap.add_argument("--icon-rocket", default="", help="Icon for GA/Rollout")
    ap.add_argument("--icon-preview", default="", help="Icon for Preview")
    ap.add_argument("--icon-dev", default="", help="Icon for In Development")
    ap.add_argument("--icon-endusers", default="", help="Icon for End Users")
    ap.add_argument("--icon-admins", default="", help="Icon for Admins")

    ap.add_argument("--rail-width", default="", help="Right rail width in inches (e.g., 3.5)")
    ap.add_argument("--template", default="", help="Optional PPTX template path")
    ap.add_argument("--debug-dump", default="", help="Write merged items JSON (via run_build)")

    args = ap.parse_args()

    # Load style
    style = _load_style(args.style)

    # Resolve rail width: CLI > style > default(3.5)
    try:
        rail_width = float(args.rail_width) if args.rail_width else float(style.get("rail", {}).get("width", 3.5))
    except Exception:
        rail_width = 3.5

    # Style defaults for assets/icons (relative to style file if paths are relative)
    style_root = Path(args.style).resolve().parent if args.style and Path(args.style).exists() else Path.cwd()

    def sjoin(rel: str) -> str:
        if not rel:
            return ""
        p = (style_root / rel) if not Path(rel).is_absolute() else Path(rel)
        return _g(str(p))

    # Assemble assets with precedence: CLI > style > ''
    assets: Dict = {
        "cover":      _g(args.cover)      or sjoin(_from_style(style, "assets", "cover")),
        "agenda":     _g(args.agenda)     or sjoin(_from_style(style, "assets", "agenda")),
        "separator":  _g(args.separator)  or sjoin(_from_style(style, "assets", "separator")),
        "conclusion": _g(args.conclusion) or sjoin(_from_style(style, "assets", "conclusion")),
        "thankyou":   _g(args.thankyou)   or sjoin(_from_style(style, "assets", "thankyou")),
        "brand_bg":   _g(args.brand_bg)   or sjoin(_from_style(style, "assets", "brand_bg")),
        "logo":       _g(args.logo)       or sjoin(_from_style(style, "assets", "logo")),
        "logo2":      _g(args.logo2)      or sjoin(_from_style(style, "assets", "logo2")),
        "cover_title": args.cover_title or style.get("cover", {}).get("title", "M365 Technical Update Briefing"),
        "cover_dates": args.cover_dates or (args.month or style.get("cover", {}).get("dates", "")),
        # Icons
        "icon_dev":      _g(args.icon_dev)      or sjoin(_from_style(style, "icons", "dev")),
        "icon_rocket":   _g(args.icon_rocket)   or sjoin(_from_style(style, "icons", "rocket")),
        "icon_preview":  _g(args.icon_preview)  or sjoin(_from_style(style, "icons", "preview")),
        "icon_endusers": _g(args.icon_endusers) or sjoin(_from_style(style, "icons", "audience_end_users")),
        "icon_admins":   _g(args.icon_admins)   or sjoin(_from_style(style, "icons", "audience_admins")),
        # Palette (optional; run_build will have its own defaults too)
        "product_palette": style.get("product_palette", {}),
    }

    # Build
    from run_build import build  # local import so we only require it when running
    build(
        inputs=args.inputs,
        output_path=args.output,
        month=args.month,
        assets=assets,
        template=_g(args.template),
        rail_width=rail_width,
        conclusion_links=None,
        debug_dump=(args.debug_dump or None)
    )

if __name__ == "__main__":
    main()
