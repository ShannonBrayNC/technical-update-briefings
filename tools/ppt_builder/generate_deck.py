# -*- coding: utf-8 -*-
"""
Generate a PowerPoint deck from Roadmap/Message Center HTML exports.

Stable build:
- Avoids fragile type hints around python-pptx; uses Any where needed
- One definition per helper (_clean, _txt, etc.)
- Slide geometry taken from `prs.slide_width/slide_height` (never slide.part.*)
- add_item_slide() has a single stable signature, with rail geometry args
- Parsing is defensive; missing fields become "", [] rather than crashing
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional, Tuple, cast

from bs4 import BeautifulSoup
from bs4.element import Tag, NavigableString

# python-pptx
import pptx
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN
from pptx.enum.dml import MSO_THEME_COLOR
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

# -------------------------
# Colors / style constants
# -------------------------
GOLD = RGBColor(214, 168, 76)
DARK_PURPLE = RGBColor(51, 18, 54)
GRAY = RGBColor(90, 90, 90)
WHITE = RGBColor(255, 255, 255)

# -------------------------
# Data model
# -------------------------
@dataclass
class Item:
    title: str
    description: str
    roadmap_id: str
    url: str
    month: str
    products: List[str]
    platforms: List[str]
    phases: List[str]        # e.g., ["Rolling out", "In development"]
    audience: List[str]
    created: str = ""
    modified: str = ""
    ga: str = ""             # GA date if present

# -------------------------
# Small safe helpers (single definitions)
# -------------------------
def _clean(s: Any) -> str:
    """Coerce bs4 attribute or text into a plain string."""
    if s is None:
        return ""
    # Some bs4 attributes are lists (AttributeValueList); join them.
    if isinstance(s, (list, tuple)):
        return " ".join(_clean(x) for x in s if x is not None).strip()
    return str(s).strip()

def _txt(x: Any) -> str:
    """Inner text for Tag/NavigableString; else empty."""
    if isinstance(x, (Tag, NavigableString)):
        return x.get_text(strip=True)
    return ""

def _txt_or_none(x: Any) -> Optional[str]:
    t = _txt(x)
    return t if t else None

def _first_tag(parent: Any, name: str, **kwargs: Any) -> Optional[Tag]:
    """Return first child Tag (never a PageElement placeholder)."""
    if not isinstance(parent, Tag):
        return None
    found = parent.find(name, **kwargs)
    return found if isinstance(found, Tag) else None

def _first_a_by_text(parent: Any, needle: str) -> Optional[Tag]:
    """First <a> whose text contains needle (case-insensitive)."""
    if not isinstance(parent, Tag):
        return None
    needle_l = needle.lower()
    # cast to help Pylance understand items are Tag, not PageElement
    for a_tag in cast(List[Tag], parent.find_all("a")):
        if _txt(a_tag).lower().find(needle_l) != -1:
            return a_tag
    return None

def _attr(tag: Any, name: str) -> Optional[str]:
    """Safe attribute access that returns a cleaned string or None."""
    if isinstance(tag, Tag):
        val = tag.get(name)  # bs4-safe
        if val is None:
            return None
        return _clean(val)
    return None

def _split_csv(text: str) -> List[str]:
    parts = [p.strip() for p in text.split(",")] if text else []
    return [p for p in parts if p]

# -------------------------
# Parsing (defensive)
# -------------------------
def parse_roadmap_html(path: str) -> List[Item]:
    """
    Parse the HTML you exported for the Roadmap (or Message Center styled).
    Tries a few common structures; never throws on missing bits.
    """
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        soup = BeautifulSoup(f.read(), "lxml")

    rows: List[Tag] = []
    # Try table rows
    rows.extend(soup.select("table tr"))
    # Try card-like blocks
    rows.extend(soup.select(".item, .message, .mc-post, .roadmap-card"))

    items: List[Item] = []

    for row in rows:
        # Title – try common selectors
        title_tag = (
            _first_tag(row, "h1")
            or _first_tag(row, "h2")
            or _first_tag(row, "h3")
            or _first_tag(row, "a")
        )
        title = _txt(title_tag)
        if not title:
            # skip table header rows etc.
            continue

        # Roadmap ID – look for an <a> or a text like "ID: MC123456 / RM123456"
        rid = ""
        # try anchor with "roadmap" or "mc" in href
        for a in cast(List[Tag], row.find_all("a")):
            href = _attr(a, "href")
            if href and ("roadmap" in href.lower() or "messagecenter" in href.lower() or "mc" in href.lower()):
                # often the anchor text is the ID too
                rid = _txt(a) or rid
                break
        if not rid:
            # last resort: any text like ID: XXX
            text = row.get_text(" ", strip=True)
            for token in text.split():
                if token.upper().startswith(("RM", "MC")) and any(ch.isdigit() for ch in token):
                    rid = token
                    break

        # URL – prefer first anchor that looks like roadmap/message center
        url = ""
        a_pref: Optional[Tag] = None
        for a in cast(List[Tag], row.find_all("a")):
            href = _attr(a, "href")
            if href and ("microsoft.com" in href.lower() or "roadmap" in href.lower() or "messagecenter" in href.lower()):
                a_pref = a
                break
        if a_pref is not None:
            url = _attr(a_pref, "href") or ""

        # Description / summary
        # Prefer paragraph-like content under row
        desc_tag = (
            _first_tag(row, "p")
            or _first_tag(row, "div", class_="description")
            or _first_tag(row, "div", class_="content")
        )
        description = _txt(desc_tag)

        # Month – look for "Month:" or date-y text
        month = ""
        month_tag = _first_a_by_text(row, "Month:") or _first_tag(row, "span", class_="month")
        if month_tag:
            month = _txt(month_tag)
        if not month:
            # try any text that looks like "Aug 2025"
            text = row.get_text(" ", strip=True)
            for m in (
                "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
            ):
                if f"{m} " in text:
                    month = text[text.find(m):text.find(m)+8]
                    break

        # Product / Platform / Audience / Phase chips
        products: List[str] = []
        platforms: List[str] = []
        phases: List[str] = []
        audience: List[str] = []

        # Common chips containers
        for chip in row.select(".chip, .tag, .badge, .pill, .label"):
            label = _txt(chip)
            labl = label.lower()
            if not label:
                continue
            if any(w in labl for w in ("windows", "mac", "ios", "android", "web", "gcc", "dod", "gcc high")):
                platforms.append(label)
            elif any(w in labl for w in ("rolling out", "in development", "preview", "launched")):
                phases.append(label)
            elif any(w in labl for w in ("admin", "end user", "developer", "education", "enterprise")):
                audience.append(label)
            else:
                products.append(label)

        # If there are csv-like meta fields
        meta = row.select_one(".meta, .details, .properties")
        if isinstance(meta, Tag):
            products = products or _split_csv(_txt_or_none(meta.find(attrs={"data-key": "products"}) or "") or "")
            platforms = platforms or _split_csv(_txt_or_none(meta.find(attrs={"data-key": "platforms"}) or "") or "")
            audience = audience or _split_csv(_txt_or_none(meta.find(attrs={"data-key": "audience"}) or "") or "")

        items.append(
            Item(
                title=title,
                description=description,
                roadmap_id=_clean(rid),
                url=_clean(url),
                month=_clean(month),
                products=sorted(set([_clean(p) for p in products if p])),
                platforms=sorted(set([_clean(p) for p in platforms if p])),
                phases=sorted(set([_clean(p) for p in phases if p])),
                audience=sorted(set([_clean(p) for p in audience if p])),
            )
        )

    return items

# -------------------------
# PPT helpers
# -------------------------
def _add_textbox(
    slide: Any,
    left_in: float,
    top_in: float,
    width_in: float,
    height_in: float,
    text: str,
    font_size: int = 18,
    bold: bool = False,
    color: Optional[RGBColor] = None,
    align: PP_ALIGN = PP_ALIGN.LEFT,
) -> Any:
    tx = slide.shapes.add_textbox(Inches(left_in), Inches(top_in), Inches(width_in), Inches(height_in))
    tf = tx.text_frame
    tf.clear()
    p = tf.paragraphs[0]
    run = p.add_run()
    run.text = text or ""
    font = run.font
    font.size = Pt(font_size)
    font.bold = bold
    if color:
        font.color.rgb = color
    p.alignment = align
    return tx

def _add_picture_cover(slide: Any, prs: Any, image_path: Optional[str]) -> None:
    if not image_path or not os.path.isfile(image_path):
        return
    # full-bleed
    sw, sh = prs.slide_width, prs.slide_height
    slide.shapes.add_picture(image_path, 0, 0, width=sw, height=sh)

def draw_side_rail(slide: Any, prs: Any, left_in: float, width_in: float, color: RGBColor = DARK_PURPLE) -> None:
    """Simple vertical rail rectangle."""
    EMU_PER_IN = 914400
    height_in = float(prs.slide_height) / EMU_PER_IN
    rect = slide.shapes.add_shape(
        MSO_SHAPE.RECTANGLE,
        Inches(left_in),
        Inches(0.0),
        Inches(width_in),
        Inches(height_in),
    )
    fill = rect.fill
    fill.solid()
    fill.fore_color.rgb = color
    rect.line.fill.background()




def _truncate(text: str, max_chars: int) -> str:
    if not text:
        return ""
    return text if len(text) <= max_chars else text[: max_chars - 1].rstrip() + "…"

# -------------------------
# Slide builders
# -------------------------
def add_cover_slide(
    prs: Any,
    month_str: str,
    cover_title: str,
    cover_dates: str,
    bg_path: Optional[str] = None,
    logo_path: Optional[str] = None,
    logo2_path: Optional[str] = None,
) -> Any:
    slide_layout = prs.slide_layouts[6]  # blank
    slide = prs.slides.add_slide(slide_layout)

    # background
    _add_picture_cover(slide, prs, bg_path)

    # title
    _add_textbox(slide, 1.2, 1.2, 9.0, 1.2, cover_title or "Roadmap & Updates", 42, True, GOLD)
    # dates/month
    _add_textbox(slide, 1.2, 2.1, 9.0, 0.7, month_str or cover_dates or "", 20, False, WHITE)

    # logos (optional)
    if logo_path and os.path.isfile(logo_path):
        slide.shapes.add_picture(logo_path, Inches(10.5), Inches(0.6), width=Inches(1.3))
    if logo2_path and os.path.isfile(logo2_path):
        slide.shapes.add_picture(logo2_path, Inches(10.5), Inches(2.1), width=Inches(1.3))

    return slide

def add_separator_slide(prs: Any, title: str, bg_path: Optional[str] = None) -> Any:
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    _add_picture_cover(slide, prs, bg_path)
    _add_textbox(slide, 1.5, 1.8, 9.0, 1.2, title or "", 36, True, WHITE)
    return slide

def add_item_slide(
    prs: Any,
    it: Item,
    month_str: str,
    rail_left_in: float,
    rail_width_in: float,
    assets: Dict[str, Optional[str]],
) -> Any:
    slide = prs.slides.add_slide(prs.slide_layouts[6])

    # Background brand if provided
    brand_bg = assets.get("brand_bg") if assets else None
    _add_picture_cover(slide, prs, brand_bg)

    # Side rail
    draw_side_rail(slide, prs, rail_left_in, rail_width_in, DARK_PURPLE)

    # Geometry (content area to the right of the rail)
    content_left = rail_left_in + rail_width_in + 0.3
    content_width = 12.8 - content_left  # assuming 13.3" width slide; it's fine with small margin
    content_top = 0.6

    # Bubble (product or first phase)
    bubble = (it.products[0] if it.products else (it.phases[0] if it.phases else "")).upper()
    _add_textbox(slide, content_left, content_top, content_width, 0.5, bubble, 14, True, GOLD)

    # Title (gold)
    _add_textbox(slide, content_left, content_top + 0.5, content_width, 0.9, it.title, 28, True, GOLD)

    # Summary / description
    _add_textbox(
        slide,
        content_left,
        content_top + 1.2,
        content_width,
        2.4,
        it.description,
        16,
        False,
        WHITE,
    )

    # Right rail content (ID, phases, platforms, audience, link)
    rail_text_top = 0.6
    right_pad = rail_left_in + 0.2
    # Month in a colored chip look (just text styled)
    _add_textbox(slide, 0.3, rail_text_top, rail_left_in - 0.5, 0.4, month_str, 14, True, WHITE, PP_ALIGN.CENTER)

    rail_text_top += 0.6
    _add_textbox(slide, 0.3, rail_text_top, rail_left_in - 0.5, 0.4, f"ID: {it.roadmap_id}", 14, False, WHITE)
    rail_text_top += 0.45
    _add_textbox(slide, 0.3, rail_text_top, rail_left_in - 0.5, 0.6, "Phases: " + ", ".join(it.phases), 12, False, WHITE)
    rail_text_top += 0.5
    _add_textbox(slide, 0.3, rail_text_top, rail_left_in - 0.5, 0.6, "Platforms: " + ", ".join(it.platforms), 12, False, WHITE)
    rail_text_top += 0.5
    _add_textbox(slide, 0.3, rail_text_top, rail_left_in - 0.5, 0.6, "Audience: " + ", ".join(it.audience), 12, False, WHITE)
    rail_text_top += 0.5
    if it.url:
        _add_textbox(slide, 0.3, rail_text_top, rail_left_in - 0.5, 0.6, it.url, 10, False, WHITE)

    # Speaker notes (branding summary etc., optional)
    notes = slide.notes_slide.notes_text_frame
    notes.text = (
        f"{it.title}\n\n"
        f"URL: {it.url}\n"
        f"ID: {it.roadmap_id}\n"
        f"Month: {it.month}\n"
        f"Products: {', '.join(it.products)}\n"
        f"Platforms: {', '.join(it.platforms)}\n"
        f"Phases: {', '.join(it.phases)}\n"
        f"Audience: {', '.join(it.audience)}\n"
    )

    return slide

def add_thankyou_slide(prs: Any, bg_path: Optional[str] = None, logo_path: Optional[str] = None) -> Any:
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    _add_picture_cover(slide, prs, bg_path)
    _add_textbox(slide, 1.8, 2.2, 8.0, 1.0, "Thank you!", 40, True, WHITE, PP_ALIGN.LEFT)
    if logo_path and os.path.isfile(logo_path):
        slide.shapes.add_picture(logo_path, Inches(11.0), Inches(0.8), width=Inches(1.8))
    return slide

# -------------------------
# Build
# -------------------------
def build(
    inputs: List[str],
    output_path: str,
    month_str: str,
    assets: Dict[str, Optional[str]],
    template: Optional[str],
    rail_width: float = 3.5,
) -> None:
    # Load template or default
    prs = pptx.Presentation(template) if template else pptx.Presentation()

    # Optional cover
    add_cover_slide(
        prs,
        month_str=month_str,
        cover_title=_clean(assets.get("cover_title")),
        cover_dates=_clean(assets.get("cover_dates")),
        bg_path=assets.get("cover"),
        logo_path=assets.get("logo"),
        logo2_path=assets.get("logo2"),
    )

    # Agenda (optional)
    if assets.get("agenda_bg"):
        add_separator_slide(prs, "Agenda", assets.get("agenda_bg"))

    # Parse all inputs
    all_items: List[Item] = []
    for path in inputs:
        if not path or not os.path.isfile(path):
            continue
        all_items.extend(parse_roadmap_html(path))

    # Items separator
    if assets.get("separator"):
        add_separator_slide(prs, "Roadmap Items", assets.get("separator"))

    # Each item slide
    rail_left_in: float = 0.0
    for it in all_items:
        add_item_slide(
            prs=prs,
            it=it,
            month_str=month_str or it.month,
            rail_left_in=rail_left_in,
            rail_width_in=rail_width,
            assets=assets,
        )

    # Conclusion / Thank you
    if assets.get("conclusion_bg"):
        add_separator_slide(prs, "Wrap Up", assets.get("conclusion_bg"))

    add_thankyou_slide(prs, bg_path=assets.get("thankyou"), logo_path=assets.get("logo"))

    # Save
    prs.save(output_path)

# -------------------------
# CLI
# -------------------------
def _assets_dict_from_args(args: argparse.Namespace) -> Dict[str, Optional[str]]:
    return {
        "cover": args.cover,
        "agenda_bg": args.agenda_bg,
        "separator": args.separator,
        "conclusion_bg": args.conclusion_bg,
        "thankyou": args.thankyou,
        "brand_bg": args.brand_bg,
        "cover_title": args.cover_title,
        "cover_dates": args.cover_dates,
        "separator_title": args.separator_title,
        "logo": args.logo,
        "logo2": args.logo2,
        "rocket": args.rocket,
        "magnifier": args.magnifier,
    }

def month_display_str(raw_month: Optional[str]) -> str:
    if raw_month:
        return raw_month
    today = dt.date.today()
    return today.strftime("%b %Y")

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("-i", "--inputs", nargs="+", required=True, help="One or more HTML files")
    p.add_argument("-o", "--output", required=True, help="Output PPTX path")
    p.add_argument("--month", default="", help="Display month (e.g., 'Aug 2025')")
    p.add_argument("--cover", default=None)
    p.add_argument("--agenda-bg", dest="agenda_bg", default=None)
    p.add_argument("--separator", default=None)
    p.add_argument("--conclusion-bg", dest="conclusion_bg", default=None)
    p.add_argument("--thankyou", default=None)
    p.add_argument("--brand-bg", dest="brand_bg", default=None)
    p.add_argument("--cover-title", dest="cover_title", default="Technical Update Briefing")
    p.add_argument("--cover-dates", dest="cover_dates", default="")
    p.add_argument("--separator-title", dest="separator_title", default="Roadmap Items")
    p.add_argument("--logo", default=None)
    p.add_argument("--logo2", default=None)
    p.add_argument("--rocket", default=None)
    p.add_argument("--magnifier", default=None)
    p.add_argument("--template", default=None)
    p.add_argument("--rail-width", dest="rail_width", type=float, default=3.5)
    args = p.parse_args()
    assets = _assets_dict_from_args(args)
    
    print(f"[ppt_builder] Total parsed items: {len(items)} from {len(inputs)} input file(s)")

    
    build(
        inputs=args.inputs,
        output_path=args.output,
        month_str=month_display_str(args.month),
        assets=assets,
        template=args.template or None,
        rail_width=float(args.rail_width or 3.5),
    )

if __name__ == "__main__":
    main()
