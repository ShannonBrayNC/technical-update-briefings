### File: C:\technical_update_briefings\tools\ppt_working\full_build.py ###

import os
from pptx import Presentation
from style_manager import load_style
from layout import Layout
from parsers import parse_message_center_html, parse_roadmap_html
from dataclasses import dataclass, field
from typing import List

# Define your Item dataclass
@dataclass
class Item:
    title: str = ""
    summary: str = ""
    description: str = ""
    roadmap_id: str = ""
    url: str = ""
    month: str = ""
    product: str = ""
    products: List[str] = field(default_factory=list)
    platforms: List[str] = field(default_factory=list)
    audience: List[str] = field(default_factory=list)
    clouds: List[str] = field(default_factory=list)
    status: str = ""
    phases: str = ""
    created: str = ""
    modified: str = ""
    ga: str = ""

def parse_html_files(file_paths, month):
    """Parse your HTML files and convert to Item objects."""
    items = []
    for path in file_paths:
        if "messagecenter" in path.lower() or "briefing" in path.lower():
            dicts = parse_message_center_html(path, month)
        else:
            dicts = parse_roadmap_html(path, month)

        for d in dicts:
            # convert dict to Item
            item = Item(
                title=d.get("title", ""),
                summary=d.get("summary", ""),
                description=d.get("description", ""),
                roadmap_id=d.get("roadmap_id", ""),
                url=d.get("url", ""),
                month=month,
                product=d.get("product", ""),
                products=d.get("products", []),
                platforms=d.get("platforms", []),
                audience=d.get("audience", []),
                clouds=d.get("clouds", []),
                status=d.get("status", ""),
                phases=d.get("phases", ""),
                created=d.get("created", ""),
                modified=d.get("modified", ""),
                ga=d.get("ga", ""),
            )
            items.append(item)
    return items

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Full deck generator")
    parser.add_argument("-i", "--inputs", nargs="+", required=True, help="HTML input files")
    parser.add_argument("-o", "--output", required=True, help="Output PPTX filename")
    parser.add_argument("--style", default="style_template.yaml", help="Path to style YAML")
    parser.add_argument("--month", default="", help="Month string")
    args = parser.parse_args()

    # Load style config
    style_cfg = load_style(args.style)

    # Parse items
    items = parse_html_files(args.inputs, args.month)

    # Deduplicate and sort
    seen_keys = set()
    unique_items = []
    for it in items:
        key = (it.roadmap_id or it.title or it.url).lower()
        if key and key not in seen_keys:
            seen_keys.add(key)
            unique_items.append(it)
    unique_items.sort(key=lambda i: (i.products or [], i.title))

    # Prepare Assets dict (simulate fixing paths)
    assets = {
        "cover": None,
        "agenda": None,
        "separator": None,
        "conclusion": None,
        "thankyou": None,
        "cover_title": "My Quarterly Update",
        "cover_dates": args.month,
    }

    # Initialize presentation
    prs = Presentation()

    # Initialize layout with style
    layout = Layout(style_cfg)

    # Add cover slide
    content = {"title": assets["cover_title"], "dates": assets["cover_dates"]}
    layout.add_cover_slide(prs, assets, content)

    # Group items by product for sections
    grouped = {}
    order = []
    for item in unique_items:
        p = item.products[0] if item.products else "General"
        if p not in grouped:
            grouped[p] = []
            order.append(p)
        grouped[p].append(item)

    # Generate slides: separator + item per group
    for prod in order:
        layout.add_separator_slide(prs, assets, f"{prod} updates")
        for item in grouped[prod]:
            layout.add_item_slide(prs, item, args.month, assets=assets)

    # Add conclusion slide
    links = [
        ("Security", "https://www.microsoft.com/security"),
        ("Azure", "https://azure.microsoft.com/"),
        ("Docs", "https://learn.microsoft.com/")
    ]
    layout.add_conclusion_slide(prs, assets, links)

    # Add thank you slide
    layout.add_thankyou_slide(prs, assets)

    # Save the presentation
    prs.save(args.output)
    print(f"Deck created: {args.output}")

# Entry point
if __name__ == "__main__":
    main()

--- End of full_build.py ---


### File: C:\technical_update_briefings\tools\ppt_working\generate_deck.py ###

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

--- End of generate_deck.py ---


### File: C:\technical_update_briefings\tools\ppt_working\layout.py ###

from pptx.util import Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor

def inches_to_emu(x):
    return int(x * 914400)

def add_full_bg(slide, img_path):
    # Just a placeholder, replace with actual background filling if needed.
    pass

def add_title_box(slide, text, *, left_in, top_in, width_in, height_in, font_size_pt=60, color="#FFFFFF", bold=True, align=PP_ALIGN.CENTER):
    from pptx.util import Inches
    textbox = slide.shapes.add_textbox(Inches(left_in), Inches(top_in), Inches(width_in), Inches(height_in))
    tf = textbox.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.auto_size = True
    p = tf.paragraphs[0]
    p.alignment = align
    r = p.add_run()
    r.text = text
    r.font.size = Pt(font_size_pt)
    r.font.bold = bold
    r.font.color.rgb = RGBColor.from_string(color)

def add_text_box(slide, text, *, left_in, top_in, width_in, height_in, font_size_pt=16, color="#FFFFFF", bold=False, align=PP_ALIGN.LEFT):
    from pptx.util import Inches
    textbox = slide.shapes.add_textbox(Inches(left_in), Inches(top_in), Inches(width_in), Inches(height_in))
    tf = textbox.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.auto_size = True
    p = tf.paragraphs[0]
    p.alignment = align
    r = p.add_run()
    r.text = text
    r.font.size = Pt(font_size_pt)
    r.font.bold = bold
    r.font.color.rgb = RGBColor.from_string(color)

class Layout:
    def __init__(self, assets):
        self.assets = assets

    def add_cover_slide(self, prs, assets, content):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        add_full_bg(slide, assets.get("cover"))
        add_title_box(
            slide,
            content.get('title', 'Title'),
            left_in=0.5, top_in=2, width_in=9, height_in=2,
            font_size_pt=52, color="#FFFFFF", bold=True
        )
        add_text_box(
            slide,
            content.get('dates', ''),
            left_in=0.5, top_in=4, width_in=9, height_in=1,
            font_size_pt=30, color="#FFFFFF"
        )

    def add_item_slide(self, prs, item, month_str, assets, rail_left_in=0):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        # Fill background if needed
        add_full_bg(slide, assets.get("cover"))  # or custom background

        # Title
        add_title_box(slide, item.title or 'Title', left_in=0.5, top_in=0.5, width_in=9, height_in=1.8, font_size_pt=36)
        # Summary
        add_text_box(slide, item.summary or '', left_in=0.5, top_in=2.5, width_in=9, height_in=3, font_size_pt=16)

        # Meta info (e.g., feature_id, status)
        add_text_box(slide, f"ID: {item.roadmap_id}", left_in=0.5, top_in=6, width_in=3, height_in=0.5, font_size_pt=12)
        add_text_box(slide, f"Status: {item.status}", left_in=3.5, top_in=6, width_in=3, height_in=0.5, font_size_pt=12)

    def add_separator_slide(self, prs, assets, title):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        add_full_bg(slide, assets.get("separator"))
        add_title_box(slide, title, left_in=0.5, top_in=1.0, width_in=9, height_in=1.5, font_size_pt=48)

    def add_conclusion_slide(self, prs, assets, links):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        add_full_bg(slide, assets.get("conclusion"))
        add_title_box(slide, "Final Thoughts", left_in=0.5, top_in=1.0, width_in=9, height_in=1.5, font_size_pt=48)
        top = 3
        for text, url in links:
            add_text_box(slide, f"{text}: {url}", left_in=0.5, top_in=top, width_in=9, height_in=0.5, font_size_pt=16)
            top += 0.6

    def add_thankyou_slide(self, prs, assets):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        add_full_bg(slide, assets.get("thankyou"))

--- End of layout.py ---


### File: C:\technical_update_briefings\tools\ppt_working\run_build.py ###

# run_build.py
from pptx import Presentation
from layout import Layout
from parsers import parse_message_center_html, parse_roadmap_html
import os


def load_style(path: str) -> dict:
    with open(path, 'r') as f:
        return yaml.safe_load(f)


# run_build.py

from pptx import Presentation
from layout import Layout
from parsers import parse_message_center_html, parse_roadmap_html
import os
import logging

def build(
    inputs,
    output_path,
    month,
    assets,
    template=None,
    rail_width=3.5,
    conclusion_links=None
):
    print("Starting build process...")

    # Load or create presentation
    if template and os.path.exists(template):
        prs = Presentation(template)
        print(f"Loaded template: {template}")
    else:
        prs = Presentation()
        print("Created new presentation.")

    # Parse all HTML inputs
    all_items = []
    for file_path in inputs:
        if not os.path.exists(file_path):
            print(f"Input file not found: {file_path}")
            continue
        filename_lower = file_path.lower()
        if "messagecenter" in filename_lower:
            parsed = parse_message_center_html(file_path, month)
        elif "roadmap" in filename_lower:
            parsed = parse_roadmap_html(file_path, month)
        else:
            print(f"Unrecognized input type: {file_path}")
            parsed = []
        print(f"Parsed {len(parsed)} items from {file_path}")
        all_items.extend(parsed)

    # Deduplicate items based on roadmap_id, title, or URL
    seen = set()
    unique_items = []
    for item in all_items:
        key = (item.get("roadmap_id") or item.get("title") or item.get("url") or "").lower()
        if key and key not in seen:
            seen.add(key)
            unique_items.append(item)
    print(f"Total unique items: {len(unique_items)}")

    # Sort items (optional)
    unique_items.sort(key=lambda i: (i.get("products", [""])[0], i.get("title", "")))

    # Initialize layout with style
    style_cfg = load_style("style_template.yaml")
    layout = Layout(style_cfg)

    # Add cover slide
    cover_title = assets.get("cover_title", "My Quarterly Update")
    cover_dates = assets.get("cover_dates", month)
    layout.add_cover_slide(prs, assets, {"title": cover_title, "dates": cover_dates})

    # Group items by product (for sections)
    grouped = {}
    order = []
    for item in unique_items:
        products = item.get("products", [])
        product_name = products[0] if products else "General"
        if product_name not in grouped:
            grouped[product_name] = []
            order.append(product_name)
        grouped[product_name].append(item)

    # Generate section slides per product
    for product in order:
        layout.add_separator_slide(prs, assets, f"{product} updates")
        for item in grouped[product]:
            layout.add_item_slide(prs, item, month, assets)

    # Add conclusion slide
    links = conclusion_links or [
        ("Security", "https://www.microsoft.com/security"),
        ("Azure", "https://azure.microsoft.com/"),
        ("Docs", "https://learn.microsoft.com/")
    ]
    layout.add_conclusion_slide(prs, assets, links)

    # Add thank you slide
    layout.add_thankyou_slide(prs, assets)

    # Save the presentation
    prs.save(output_path)
    print(f"Presentation saved to {output_path}")
    """
    Generate PPTX from input HTML files.
    """
    print("Starting deck build...")
    # Aggregate parsed items
    all_items = []
    for file_path in inputs:
        ext = os.path.splitext(file_path)[1].lower()
        if "messagecenter" in file_path.lower():
            parsed = parse_message_center_html(file_path, month)
        elif "roadmap" in file_path.lower():
            parsed = parse_roadmap_html(file_path, month)
        else:
            parsed = []  # For unknown types or extend as needed
        all_items.extend(parsed)

    # Deduplicate
    seen = set()
    unique_items = []
    for item in all_items:
        key = (item.get("roadmap_id") or item.get("title") or item.get("url") or "").lower()
        if key and key not in seen:
            seen.add(key)
            unique_items.append(item)

    # Sort for presentation flow (by product, title)
    unique_items.sort(key=lambda i: (i.get("products", []), i.get("title", "")))

    # Create presentation
    if template and os.path.exists(template):
        prs = Presentation(template)
    else:
        prs = Presentation()

    # Initialize Layout with style
    style_cfg = load_style("style_template.yaml")
    layout = Layout(style_cfg)

    # Add cover slide
    cover_title = assets.get("cover_title", "My Quarterly Update")
    cover_dates = assets.get("cover_dates", month)
    layout.add_cover_slide(prs, assets, {"title": cover_title, "dates": cover_dates})

    # Group items by product
    grouped = {}
    order = []
    for item in unique_items:
        product = item.get("products", ["General"])[0] if item.get("products") else "General"
        if product not in grouped:
            grouped[product] = []
            order.append(product)
        grouped[product].append(item)

    # Generate product section slides
    for product in order:
        layout.add_separator_slide(prs, assets, f"{product} updates")
        for item in grouped[product]:
            layout.add_item_slide(prs, item, month, assets)

    # Add conclusion slide
    links = conclusion_links or [
        ("Security", "https://www.microsoft.com/security"),
        ("Azure", "https://azure.microsoft.com/"),
        ("Docs", "https://learn.microsoft.com/")
    ]
    layout.add_conclusion_slide(prs, assets, links)

    # Add thank you
    layout.add_thankyou_slide(prs, assets)

    # Save presentation
    prs.save(output_path)
    print(f"Deck saved to {output_path}")

--- End of run_build.py ---


### File: C:\technical_update_briefings\tools\ppt_working\slides.py ###

import os
from pptx.util import Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor

# Helper functions for conversions
def inches_to_emu(x):
    return int(x * 914400)  # EMU per inch



def add_full_slide_picture(slide, prs, image_path):
    """Add a background image stretched over the full slide."""
    if not image_path or not os.path.exists(image_path):
        return
    slide.shapes.add_picture(
        image_path,
        0,
        0,
        width=inches_to_emu(10),
        height=inches_to_emu(7.5),
    )

def add_picture_safe(slide, image_path, left_in, top_in, width_in=None, height_in=None):
    """Safely add a picture if file exists."""
    if not image_path or not os.path.exists(image_path):
        return
    try:
        from pptx.util import Inches
        if width_in is None and height_in is None:
            slide.shapes.add_picture(image_path, inches_to_emu(left_in), inches_to_emu(top_in))
        elif width_in is not None and height_in is None:
            slide.shapes.add_picture(image_path, inches_to_emu(left_in), inches_to_emu(top_in), width=inches_to_emu(width_in))
        elif width_in is None and height_in is not None:
            slide.shapes.add_picture(image_path, inches_to_emu(left_in), inches_to_emu(top_in), height=inches_to_emu(height_in))
        else:
            slide.shapes.add_picture(image_path, inches_to_emu(left_in), inches_to_emu(top_in), width=inches_to_emu(width_in), height=inches_to_emu(height_in))
    except Exception as e:
        print(f"Error adding picture {image_path}: {e}")

def add_title_box(slide, text, *, left_in, top_in, width_in, height_in, font_size_pt=60, bold=True, color="#FFFFFF", align=PP_ALIGN.LEFT):
    """Add a styled title textbox."""
    from pptx.util import Inches
    textbox = slide.shapes.add_textbox(Inches(left_in), Inches(top_in), Inches(width_in), Inches(height_in))
    tf = textbox.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.auto_size = True
    p = tf.paragraphs[0]
    p.alignment = align
    r = p.add_run()
    r.text = text or ""
    r.font.size = Pt(font_size_pt)
    r.font.bold = bold
    r.font.color.rgb = RGBColor.from_string(color)

def add_text_box(slide, text, *, left_in, top_in, width_in, height_in, font_size_pt=18, bold=False, color="#FFFFFF", align=PP_ALIGN.LEFT):
    """Add styled text box."""
    from pptx.util import Inches
    textbox = slide.shapes.add_textbox(Inches(left_in), Inches(top_in), Inches(width_in), Inches(height_in))
    tf = textbox.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.auto_size = True
    p = tf.paragraphs[0]
    p.alignment = align
    r = p.add_run()
    r.text = text or ""
    r.font.size = Pt(font_size_pt)
    r.font.bold = bold
    r.font.color.rgb = RGBColor.from_string(color)

# Now define your slide templates functions:

def add_cover_slide(prs, assets, cover_title, cover_dates, logo1_path, logo2_path):
    slide = prs.slides.add_slide(prs.slide_layouts[6])  # blank layout
    add_full_slide_picture(slide, prs, assets.get("cover"))
    # Title text
    add_title_box(
        slide,
        cover_title or "Title",
        left_in=0.5,
        top_in=2,
        width_in=9,
        height_in=2,
        font_size_pt=52,
        color="#FFFFFF",
        align=PP_ALIGN.CENTER
    )
    # Dates text
    if cover_dates:
        add_text_box(
            slide,
            cover_dates,
            left_in=0.5,
            top_in=4,
            width_in=9,
            height_in=1,
            font_size_pt=30,
            color="#FFFFFF",
            align=PP_ALIGN.CENTER
        )
    # Logos
    if logo1_path:
        add_picture_safe(slide, logo1_path, left_in=0.4, top_in=6.6, height_in=0.6)
    if logo2_path:
        add_picture_safe(slide, logo2_path, left_in=8.0, top_in=6.6, height_in=0.6)

def add_agenda_slide(prs, assets, agenda_lines=None):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    add_full_slide_picture(slide, prs, assets.get("agenda"))
    sw_in = 10
    # Title
    add_title_box(
        slide,
        "Agenda",
        left_in=0.5,
        top_in=0.9,
        width_in=sw_in - 1,
        height_in=1.2,
        font_size_pt=52,
        color="#FFFFFF",
        align=PP_ALIGN.LEFT
    )
    if not agenda_lines:
        agenda_lines = ["Overview", "Key updates by product", "Timeline & rollout status", "Q&A"]
    top = 2.4
    for line in agenda_lines:
        add_text_box(
            slide,
            f"• {line}",
            left_in=0.5,
            top_in=top,
            width_in=sw_in - 1,
            height_in=0.5,
            font_size_pt=26,
            color="#FFFFFF",
            align=PP_ALIGN.LEFT
        )
        top += 0.6

def add_separator_slide(prs, assets, title):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    add_full_slide_picture(slide, prs, assets.get("separator"))
    sw_in = 10
    add_title_box(
        slide,
        title,
        left_in=0.5,
        top_in=3.2,
        width_in=9,
        height_in=1.5,
        font_size_pt=56,
        color="#FFFFFF",
        align=PP_ALIGN.CENTER,
    )

def add_conclusion_slide(prs, assets, links):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    add_full_slide_picture(slide, prs, assets.get("conclusion"))
    sw_in = 10
    add_title_box(
        slide,
        "Final Thoughts",
        left_in=0.5,
        top_in=0.9,
        width_in=9,
        height_in=1.2,
        font_size_pt=52,
        color="#FFFFFF",
        align=PP_ALIGN.CENTER,
    )
    top = 2.4
    for text, url in links:
        add_text_box(
            slide,
            f"{text}: {url}",
            left_in=0.5,
            top_in=top,
            width_in=9,
            height_in=0.5,
            font_size_pt=22,
            color="#FFFFFF",
            align=PP_ALIGN.LEFT
        )
        top += 0.6

def add_thankyou_slide(prs, assets):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    add_full_slide_picture(slide, prs, assets.get("thankyou"))

# slides.py

def add_item_slide(self, prs, item, month_str, assets, rail_left_in=0, rail_width_in=3):
    """
    Create a slide for a feature item.
    """
    from pptx.util import Inches, Pt
    slide = prs.slides.add_slide(prs.slide_layouts[6])  # blank layout

    # Add full slide background if specified
    add_full_slide_picture(slide, prs, assets.get("cover"))  # Or use other background

    # Title
    title_text = item.title or 'Untitled Feature'
    add_title_box(
        slide,
        title_text,
        left_in=0.5,
        top_in=0.5,
        width_in=9,
        height_in=1.8,
        font_size_pt=36,
        color="#FFFFFF"
    )

    # Summary
    summary = item.summary or "No description provided."
    add_text_box(
        slide,
        summary,
        left_in=0.5,
        top_in=2.5,
        width_in=9,
        height_in=3,
        font_size_pt=16,
        color="#FFFFFF"
    )

    # Metadata (ID and Status)
    roadmap_id = item.roadmap_id or "N/A"
    status = item.status or "Unknown"
    add_text_box(
        slide,
        f"ID: {roadmap_id}",
        left_in=0.5,
        top_in=6,
        width_in=3,
        height_in=0.5,
        font_size_pt=12,
        color="#CCCCCC"
    )
    add_text_box(
        slide,
        f"Status: {status}",
        left_in=3.7,
        top_in=6,
        width_in=3,
        height_in=0.5,
        font_size_pt=12,
        color="#CCCCCC"
    )

    # Optionally, add more info like URL
    url = item.url
    if url:
        add_text_box(
            slide,
            f"Learn more: {url}",
            left_in=0.5,
            top_in=6.7,
            width_in=9,
            height_in=0.5,
            font_size_pt=12,
            color="#66CCFF"
        )

--- End of slides.py ---


### File: C:\technical_update_briefings\tools\ppt_working\style_manager.py ###

import yaml

def load_style(path: str) -> dict:
    with open(path, 'r') as f:
        return yaml.safe_load(f)

--- End of style_manager.py ---


### File: C:\technical_update_briefings\tools\ppt_working\parsers\__init__.py ###

# tools/ppt_builder/parsers/__init__.py
from .message_center import parse_message_center_html  # re-export for convenience
from .roadmap_html import parse_roadmap_html

__all__ = ["parse_message_center_html", "parse_roadmap_html"]

--- End of __init__.py ---


### File: C:\technical_update_briefings\tools\ppt_working\parsers\message_center.py ###

# tools/ppt_builder/parsers/message_center.py
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Dict, List, Optional

from bs4 import BeautifulSoup, Tag
from bs4.element import NavigableString
from collections.abc import Sequence

ItemDict = Dict[str, Any]


# --- local safety helpers (kept here to avoid cross-module churn) ----------------
def _clean(s: Any) -> str:
    if s is None:
        return ""
    try:
        txt = str(s)
    except Exception:
        return ""
    txt = re.sub(r"\s+", " ", txt).strip()
    return txt


def _to_text(element):
    """
    Convert a BeautifulSoup element, list, or string to a plain string.
    Handles nested lists, tags, strings, and None gracefully.
    """
    if element is None:
        return ""
    elif isinstance(element, NavigableString):
        return str(element).strip()
    elif isinstance(element, Tag):
        return element.get_text(strip=True)
    elif isinstance(element, str):
        return element.strip()
    elif isinstance(element, Sequence):
        # process each item recursively and join
        return " ".join(_to_text(e) for e in element).strip()
    else:
        # fallback
        return str(element).strip()



def _safe_find_all(node: Any, *args: Any, **kwargs: Any) -> List[Any]:
    fa = getattr(node, "find_all", None)
    if not callable(fa):
        return []
    try:
        out = fa(*args, **kwargs) or []
        return list(out)
    except Exception:
        return []


def _safe_find(node: Any, *args: Any, **kwargs: Any) -> Optional[Any]:
    fd = getattr(node, "find", None)
    if not callable(fd):
        return None
    try:
        return fd(*args, **kwargs)
    except Exception:
        return None


def _attr(node: Any, name: str) -> str:
    if node is None:
        return ""
    # use .get to avoid __getitem__ typing drama
    try:
        v = node.get(name)
    except Exception:
        v = None
    if isinstance(v, (list, tuple)):
        v = v[0] if v else ""
    return _clean(v)


# --- small extractors ------------------------------------------------------------
_ROADMAP_URL_PAT = re.compile(r"(featureid=|\broadmap\b|\bmicrosoft-365-roadmap\b)", re.I)
_FEATURE_ID_PAT = re.compile(r"\b(feature\s*id|id)\s*[:#]?\s*(\d{3,})\b", re.I)


def _find_url(card: Any) -> str:
    for a in _safe_find_all(card, "a", href=True):
        href = _attr(a, "href")
        if _ROADMAP_URL_PAT.search(href):
            return href
    a0 = _safe_find(card, "a", href=True)
    return _attr(a0, "href") if a0 else ""


def _find_title(card: Any) -> str:
    # preference: explicit title selectors if they exist
    t = _safe_find(card, attrs={"class": lambda c: bool(c and "title" in str(c))})
    if t:
        return _to_text(t)

    for tag in ("h1", "h2", "h3", "h4"):
        hd = _safe_find(card, tag)
        if hd:
            return _to_text(hd)

    a = _safe_find(card, "a")
    if a:
        return _to_text(a)

    # last resort: first sizeable text chunk
    paras = [p for p in _safe_find_all(card, ["p", "div", "span"]) if _to_text(p)]
    if paras:
        paras.sort(key=lambda p: len(_to_text(p)), reverse=True)
        return _to_text(paras[0])

    return _to_text(card)


def _find_summary(card: Any) -> str:
    sc = _safe_find(card, attrs={"class": lambda c: bool(c and ("summary" in str(c) or "description" in str(c)))})
    if sc:
        return _to_text(sc)

    # heuristics: longest paragraph-ish text
    paras = [p for p in _safe_find_all(card, ["p", "div", "span"]) if _to_text(p)]
    if not paras:
        return ""
    paras.sort(key=lambda p: len(_to_text(p)), reverse=True)
    return _to_text(paras[0])


def _find_feature_id(card: Any, url: str) -> str:
    # in text
    m = _FEATURE_ID_PAT.search(_to_text(card))
    if m:
        return _clean(m.group(2))
    # in url (featureid=123456)
    m2 = re.search(r"[?&#]featureid=(\d{3,})\b", url, re.I)
    if m2:
        return _clean(m2.group(1))
    return ""


def _csv_from_classes(card: Any, needle: str) -> str:
    # Look for elements whose class list contains the needle; join their text
    hits: List[str] = []
    for el in _safe_find_all(card, attrs={"class": lambda c: bool(c and needle in str(c))}):
        txt = _to_text(el)
        if txt:
            hits.append(txt)
    return ", ".join(dict.fromkeys([_clean(h) for h in hits if h]))


def _label_value(card: Any, label: str) -> str:
    """
    Look for patterns like:
      <div><span>Status:</span><span>Launched</span></div>
    or text 'Status: Launched'.
    """
    txt = _to_text(card)
    m = re.search(rf"\b{re.escape(label)}\s*[:\-]\s*([^\n\r|]+)", txt, re.I)
    if m:
        return _clean(m.group(1))
    return ""


# --- card detection --------------------------------------------------------------
def _find_cards(root: Any) -> List[Any]:
    cards: List[Any] = []
    # Common card-ish containers
    candidates = _safe_find_all(root, True, attrs={"class": lambda c: bool(c and any(k in str(c).lower()
                                                                                     for k in ("card", "ms-", "item", "tile")))})
    # Try to filter out tiny elements by looking for at least a link or a paragraph
    for el in candidates:
        if _safe_find(el, "a") or _safe_find(el, "p"):
            cards.append(el)
    # Dedup while keeping order
    seen = set()
    out: List[Any] = []
    for el in cards:
        ident = id(el)
        if ident not in seen:
            seen.add(ident)
            out.append(el)
    return out


# --- public API -----------------------------------------------------------------
def parse_message_center_html(html_path: str, month: Optional[str] = None) -> List[ItemDict]:
    """
    Parse a Message Center HTML export (card UI) into a list of item dicts.
    Returned dict keys (superset; missing keys omitted if not found):
      title, summary, roadmap_id, url, month, products, platforms, audience,
      status, phases, clouds, created, modified, ga
    """
    p = Path(html_path)
    if not p.exists():
        return []

    html = p.read_text(encoding="utf-8", errors="ignore")
    soup = BeautifulSoup(html, "lxml")

    # Try card model first
    cards = _find_cards(soup)

    items: List[ItemDict] = []

    if cards:
        for card in cards:
            url = _find_url(card)
            title = _find_title(card)
            summary = _find_summary(card)
            rid = _find_feature_id(card, url)

            products = _csv_from_classes(card, "product") or _label_value(card, "Products")
            platforms = _csv_from_classes(card, "platform") or _label_value(card, "Platform")
            audience = _csv_from_classes(card, "audience") or _label_value(card, "Audience")
            status = _csv_from_classes(card, "status") or _label_value(card, "Status")
            phases = _csv_from_classes(card, "phase") or _label_value(card, "Phase")
            clouds = _csv_from_classes(card, "cloud") or _label_value(card, "Cloud")
            created = _label_value(card, "Created")
            modified = _label_value(card, "Updated") or _label_value(card, "Modified")
            ga = _label_value(card, "GA")

            d: ItemDict = {}
            if title: d["title"] = title
            if summary: d["summary"] = summary
            if rid: d["roadmap_id"] = rid
            if url: d["url"] = url
            if month: d["month"] = month
            if products: d["products"] = products
            if platforms: d["platforms"] = platforms
            if audience: d["audience"] = audience
            if status: d["status"] = status
            if phases: d["phases"] = phases
            if clouds: d["clouds"] = clouds
            if created: d["created"] = created
            if modified: d["modified"] = modified
            if ga: d["ga"] = ga

            # only accept if we have at least a title or a URL
            if d.get("title") or d.get("url"):
                items.append(d)

        return items

    # Fallback: table-based exports
    tables = _safe_find_all(soup, "table")
    for table in tables:
        for tr in _safe_find_all(table, "tr"):
            tds = _safe_find_all(tr, "td")
            if not tds:
                continue

            def cell(i: int, default: str = "") -> str:
                return _to_text(tds[i]) if (0 <= i < len(tds)) else default

            title = cell(0)
            summary = cell(1)
            url = ""
            a0 = _safe_find(tr, "a", href=True) or _safe_find(table, "a", href=True)
            if a0:
                url = _attr(a0, "href")
            rid = ""
            m = _FEATURE_ID_PAT.search(_to_text(tr))
            if m:
                rid = _clean(m.group(2))

            d: ItemDict = {}
            if title: d["title"] = title
            if summary: d["summary"] = summary
            if rid: d["roadmap_id"] = rid
            if url: d["url"] = url
            if month: d["month"] = month
            if d:
                items.append(d)

    return items

--- End of message_center.py ---


### File: C:\technical_update_briefings\tools\ppt_working\parsers\roadmap_html.py ###

# tools/ppt_builder/parsers/roadmap_html.py
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Dict, List, Optional

from bs4 import BeautifulSoup

ItemDict = Dict[str, Any]

# ---------------- safety + text helpers (local, self-contained) -----------------
def _clean(s: Any) -> str:
    if s is None:
        return ""
    try:
        s = str(s)
    except Exception:
        return ""
    s = re.sub(r"\s+", " ", s).strip()
    return s


from bs4 import  Tag
from bs4.element import NavigableString
from collections.abc import Sequence

def _to_text(element):
    """
    Convert a BeautifulSoup element, list, or string to a plain string.
    Handles nested lists, tags, strings, and None gracefully.
    """
    if element is None:
        return ""
    elif isinstance(element, NavigableString):
        return str(element).strip()
    elif isinstance(element, Tag):
        return element.get_text(strip=True)
    elif isinstance(element, str):
        return element.strip()
    elif isinstance(element, Sequence):
        # process each item recursively and join
        return " ".join(_to_text(e) for e in element).strip()
    else:
        # fallback
        return str(element).strip()


def _safe_find(node: Any, *args: Any, **kwargs: Any) -> Optional[Any]:
    fn = getattr(node, "find", None)
    if not callable(fn):
        return None
    try:
        return fn(*args, **kwargs)
    except Exception:
        return None




from bs4.element import Tag
from typing import List, Optional, Dict, Union

def _safe_find_all(
    element: Union[Tag, object],
    name: Optional[Union[str, List[str]]] = None,
    attrs: Optional[Dict[str, Union[str, List[str]]]] = None,
    recursive: bool = True
) -> List[Tag]:
    """
    Safely find all elements matching criteria, returning an empty list if the input
    isn't a Tag or if an error occurs.
    """
    if not isinstance(element, Tag):
        return []

    try:
        return [
            tag for tag in element.find_all(name, attrs=attrs, recursive=recursive)
            if isinstance(tag, Tag)
        ]
    except TypeError:
        # fallback if attrs is an invalid type
        return []
def _attr(node: Any, name: str) -> str:
    if node is None:
        return ""
    try:
        val = node.get(name)
    except Exception:
        val = None
    if isinstance(val, (list, tuple)):
        val = val[0] if val else ""
    return _clean(val)


# ---------------- field extractors / normalizers ----------------
_HDR_ALIASES = {
    "feature id": {"feature id", "featureid", "id", "roadmap id", "feature_id"},
    "title": {"title", "feature name", "feature title"},
    "description": {"description", "summary", "details"},
    "status": {"status", "release status"},
    "products": {"product", "products", "workload"},
    "platforms": {"platform", "platforms", "device"},
    "audience": {"audience"},
    "phase": {"phase", "release phase"},
    "clouds": {"cloud", "clouds"},
    "created": {"created", "date added"},
    "modified": {"modified", "last modified", "updated"},
    "ga": {"ga", "general availability", "release"},
    "url": {"more info", "learn more", "link", "url"},
}


def _normalize_hdr(s: str) -> str:
    s = _clean(s).lower()
    for key, aliases in _HDR_ALIASES.items():
        if s in aliases:
            return key
    return s


def _find_table_candidates(soup: BeautifulSoup) -> List[Any]:
    tables = _safe_find_all(soup, "table")
    out: List[Any] = []
    for t in tables:
        ths = [_normalize_hdr(_to_text(th)) for th in _safe_find_all(t, "th")]
        header_blob = " ".join(ths)
        if ("feature id" in header_blob) or ("title" in header_blob) or ("description" in header_blob):
            out.append(t)
    return out


def _header_map(table: Any) -> Dict[str, int]:
    ths = _safe_find_all(table, "th")
    if not ths:
        # sometimes first row is header using <td>
        head_tr = _safe_find(table, "tr")
        ths = _safe_find_all(head_tr, ["th", "td"]) if head_tr else []
    mapping: Dict[str, int] = {}
    for idx, th in enumerate(ths):
        key = _normalize_hdr(_to_text(th))
        if key and key not in mapping:
            mapping[key] = idx
    return mapping


def _cell_text(tds: List[Any], i: int) -> str:
    return _to_text(tds[i]) if 0 <= i < len(tds) else ""


def _first_link_href(node: Any) -> str:
    a = _safe_find(node, "a", href=True)
    return _attr(a, "href") if a else ""


# ---------------- public API ----------------
_FEATURE_ID_PAT = re.compile(r"\b(\d{3,})\b")
_ROADMAP_URL_PAT = re.compile(r"(featureid=|\broadmap\b|\bmicrosoft-365-roadmap\b)", re.I)


def parse_roadmap_html(html_path: str, month: Optional[str] = None) -> List[ItemDict]:
    """
    Parse Microsoft 365 Roadmap HTML export.
    Prefers table-based format; falls back to card-like containers when tables aren't present.
    Returns a list of dicts with keys: title, summary, roadmap_id, url, month, status, products,
    platforms, audience, phase, clouds, created, modified, ga (present when found).
    """
    p = Path(html_path)
    if not p.exists():
        return []

    html = p.read_text(encoding="utf-8", errors="ignore")
    soup = BeautifulSoup(html, "lxml")

    items: List[ItemDict] = []

    # ---- Table-based (preferred) ----
    for table in _find_table_candidates(soup):
        hdrs = _header_map(table)
        if not hdrs:
            continue

        for tr in _safe_find_all(table, "tr"):
            tds = _safe_find_all(tr, "td")
            if not tds:
                continue

            def get(name: str) -> str:
                idx = hdrs.get(name, -1)
                return _cell_text(tds, idx) if idx >= 0 else ""

            rid = get("feature id")
            if not rid:
                # Try number-looking tokens anywhere in the row
                m = _FEATURE_ID_PAT.search(_to_text(tr))
                rid = _clean(m.group(1)) if m else ""

            title = get("title") or _cell_text(tds, 0)
            description = get("description")
            status = get("status")
            products = get("products")
            platforms = get("platforms")
            audience = get("audience")
            phase = get("phase")
            clouds = get("clouds")
            created = get("created")
            modified = get("modified")
            ga = get("ga")

            url = get("url") or _first_link_href(tr)
            if not url and rid:
                # best-effort reconstruct roadmap URL if they didn’t include one
                url = f"https://www.microsoft.com/microsoft-365/roadmap?featureid={rid}"

            d: ItemDict = {}
            if title: d["title"] = title
            if description: d["summary"] = description
            if rid: d["roadmap_id"] = rid
            if url: d["url"] = url
            if month: d["month"] = month
            if status: d["status"] = status
            if products: d["products"] = products
            if platforms: d["platforms"] = platforms
            if audience: d["audience"] = audience
            if phase: d["phases"] = phase      # normalize to plural "phases"
            if clouds: d["clouds"] = clouds
            if created: d["created"] = created
            if modified: d["modified"] = modified
            if ga: d["ga"] = ga

            # require at least a title or URL to count
            if d.get("title") or d.get("url"):
                items.append(d)

        # if we parsed at least a few from this table, we’re good
        if items:
            return items

    # ---- Fallback: card-like containers (rare in official exports) ----
    cards = _safe_find_all(
        soup,
        True,
        attrs={"class": lambda c: bool(c and any(k in str(c).lower() for k in ("card", "item", "tile", "ms-")))},
    )

    for card in cards:
        # title
        title_el = (
            _safe_find(card, attrs={"class": lambda c: c and "title" in str(c)})
            or _safe_find(card, ["h1", "h2", "h3"])
            or _safe_find(card, "a")
        )
        title = _to_text(title_el) if title_el else _to_text(card)

        # url + id
        url = _first_link_href(card)
        if not url:
            a0 = _safe_find(card, "a", href=True)
            url = _attr(a0, "href") if a0 else ""
        rid = ""
        if url:
            m = re.search(r"[?&#]featureid=(\d{3,})\b", url, re.I)
            if m:
                rid = _clean(m.group(1))
        if not rid:
            m2 = _FEATURE_ID_PAT.search(_to_text(card))
            rid = _clean(m2.group(1)) if m2 else ""

        # description (longest paragraph-ish text)
        paras = [p for p in _safe_find_all(card, ["p", "div", "span"]) if _to_text(p)]
        paras.sort(key=lambda p: len(_to_text(p)), reverse=True)
        description = _to_text(paras[0]) if paras else ""

        d: ItemDict = {}
        if title: d["title"] = title
        if description: d["summary"] = description
        if rid: d["roadmap_id"] = rid
        if url: d["url"] = url
        if month: d["month"] = month
        if d.get("title") or d.get("url"):
            items.append(d)

    return items

--- End of roadmap_html.py ---


