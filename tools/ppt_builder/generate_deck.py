import os
import argparse
from style_manager import load_style
from layout import Layout
from parsers import parse_message_center_html, parse_roadmap_html


def main():
    parser = argparse.ArgumentParser(description="Generate a styled PowerPoint deck from HTML inputs.")
    parser.add_argument("-i", "--inputs", nargs="+", required=True, help="HTML input files")
    parser.add_argument("-o", "--output", required=True, help="Output PPTX filename")
    parser.add_argument("--style", default="style_template.yaml", help="Path to style YAML; default: style_template.yaml")
    parser.add_argument("--month", default="", help="Month label for slides, e.g., 'October 2024'")

    # Asset images (optional)
    parser.add_argument("--cover", default="", help="Background image for cover slide")
    parser.add_argument("--agenda-bg", dest="agenda", default="", help="Background for agenda slide")
    parser.add_argument("--separator", default="", help="Background for separator slides")
    parser.add_argument("--conclusion-bg", dest="conclusion", default="", help="Background for conclusion slide")
    parser.add_argument("--thankyou", default="", help="Background for thank-you slide")
    parser.add_argument("--brand-bg", default="", help="Background for item slides (brand)")
    parser.add_argument("--cover-title", default="M365 Technical Update Briefing", help="Cover slide title")
    parser.add_argument("--cover-dates", default="", help="Cover slide date text")
    parser.add_argument("--logo", default="", help="Path to primary logo")
    parser.add_argument("--logo2", default="", help="Path to secondary logo")
    parser.add_argument("--rail-width", default=str(3.5), help="Rail width in inches, default 3.5")
    parser.add_argument("--template", default="", help="Optional PPTX template path")
        # add arguments
    parser.add_argument("--icon-rocket", dest="icon_rocket", default="", help="Icon for shipped/rollout")
    parser.add_argument("--icon-preview", dest="icon_preview", default="", help="Icon for preview/in development")


    args = parser.parse_args()

        # Load style config
    style_cfg = load_style(args.style)

    # Resolve asset paths
    def p_exists(p):
        return p if p and os.path.exists(p) else ""
    assets = {
        "cover": p_exists(args.cover),
        "agenda": p_exists(args.agenda),
        "separator": p_exists(args.separator),
        "conclusion": p_exists(args.conclusion),
        "thankyou": p_exists(args.thankyou),
        "brand_bg": p_exists(args.brand_bg),
        "cover_title": args.cover_title,
        "cover_dates": args.cover_dates or args.month,
        "logo": p_exists(args.logo),
        "logo2": p_exists(args.logo2),
        "icon_rocket": p_exists(args.icon_rocket),
        "icon_preview": p_exists(args.icon_preview),
    }

    try:
        rail_width = float(args.rail_width)
    except ValueError:
        rail_width = 3.5

    from run_build import build
    build(
        inputs=args.inputs,
        output_path=args.output,
        month=args.month,
        assets=assets,
        template=args.template,
        rail_width=rail_width,
        conclusion_links=None
    )
    

if __name__ == "__main__":
    main()