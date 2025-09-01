# generate_deck.py — CLI front-end that loads style, resolves assets, and calls run_build.build

import os
import argparse
from style_manager import load_style

def main():
    parser = argparse.ArgumentParser(description="Generate a styled PowerPoint deck from HTML inputs.")
    parser.add_argument("-i", "--inputs", nargs="+", required=True, help="HTML input files")
    parser.add_argument("-o", "--output", required=True, help="Output PPTX filename")
    parser.add_argument("--style", default="style_template.yaml", help="Path to style YAML; default: style_template.yaml")
    parser.add_argument("--month", default="", help="Month label for slides, e.g., 'September 2025'")

    # Asset images (optional)
    parser.add_argument("--cover", default="", help="Background image for cover slide")
    parser.add_argument("--agenda-bg", dest="agenda", default="", help="Background for agenda slide")
    parser.add_argument("--separator", default="", help="Background for separator slides")
    parser.add_argument("--conclusion-bg", dest="conclusion", default="", help="Background for conclusion slide")
    parser.add_argument("--thankyou", default="", help="Background for thank-you slide")
    parser.add_argument("--brand-bg", dest="brand_bg", default="", help="Background for item slides (brand)")
    parser.add_argument("--cover-title", default="M365 Technical Update Briefing", help="Cover slide title")
    parser.add_argument("--cover-dates", default="", help="Cover slide date text")
    parser.add_argument("--logo", default="", help="Path to primary logo")
    parser.add_argument("--logo2", default="", help="Path to secondary logo")

    # Icons for status
    parser.add_argument("--icon-rocket", dest="icon_rocket", default="", help="Icon for GA/Rollout")
    parser.add_argument("--icon-preview", dest="icon_preview", default="", help="Icon for Preview/In Dev")

    # Other
    parser.add_argument("--rail-width", dest="rail_width", default="", help="Rail width in inches")
    parser.add_argument("--template", default="", help="Optional PPTX template path")
    parser.add_argument("--debug-dump", dest="debug_dump", default="", help="Optional JSON dump of merged items")

    args = parser.parse_args()

    # Load style config
    style_cfg = load_style(args.style)

    def g(path):
        return path if path and os.path.exists(path) else ""

    # Resolve palette + icons from style file
    icons_cfg = (style_cfg.get("icons") or {}) if isinstance(style_cfg, dict) else {}
    assets_cfg = (style_cfg.get("assets") or {}) if isinstance(style_cfg, dict) else {}
    palette_cfg = (style_cfg.get("product_palette") or {}) if isinstance(style_cfg, dict) else {}

    # Resolve asset paths; CLI overrides style.yaml
    assets = {
        "cover":      g(args.cover)      or g(assets_cfg.get("cover","")),
        "agenda":     g(args.agenda)     or g(assets_cfg.get("agenda","")),
        "separator":  g(args.separator)  or g(assets_cfg.get("separator","")),
        "conclusion": g(args.conclusion) or g(assets_cfg.get("conclusion","")),
        "thankyou":   g(args.thankyou)   or g(assets_cfg.get("thankyou","")),
        "brand_bg":   g(args.brand_bg)   or g(assets_cfg.get("brand_bg","")),
        "logo":       g(args.logo)       or g(assets_cfg.get("logo","")),
        "logo2":      g(args.logo2)      or g(assets_cfg.get("logo2","")),
        "cover_title": args.cover_title,
        "cover_dates": args.cover_dates or args.month,
        # icons
        "icon_rocket": g(args.icon_rocket) or g(icons_cfg.get("rocket","")),
        "icon_preview": g(args.icon_preview) or g(icons_cfg.get("preview","")),
        # palette
        "product_palette": { (k or "").lower(): v for k,v in palette_cfg.items() } if palette_cfg else {},
    }

    # rail width: CLI > style.defaults.rail_width > 3.5
    def rail_width_value():
        if args.rail_width:
            try: return float(args.rail_width)
            except ValueError: pass
        try:
            dfl = style_cfg.get("defaults",{}).get("rail_width", 3.5)
            return float(dfl)
        except Exception:
            return 3.5

    from run_build import build
    build(
        inputs=args.inputs,
        output_path=args.output,
        month=args.month,
        assets=assets,
        template=args.template or "",
        rail_width=rail_width_value(),
        conclusion_links=None,
        debug_dump=(args.debug_dump or None),
    )

if __name__ == "__main__":
    main()
