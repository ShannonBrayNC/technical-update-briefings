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
from typing import Any, Dict, Iterable, List, Optional, Tuple, cast, Union 
import traceback  # only if you log tracebacks; harmless otherwise
from bs4 import BeautifulSoup
from bs4.element import BsTag, NavigableString, PageElement
import re


SoupEl = Union[BsTag, NavigableString, PageElement, str]

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
    """Return visible text from a bs4 node (Tag/PageElement/NavigableString/str/None)."""
    if x is None:
        return ""
    try:
        # bs4 Tag/PageElement/NavigableString
        if hasattr(x, "get_text"):
            return x.get_text(" ", strip=True)  # type: ignore[attr-defined]
        # already a string
        if isinstance(x, str):
            return x.strip()
        # last resort
        return str(x).strip()
    except Exception:
        return str(x).strip() if x is not None else ""


def _txt_or_none(x: Any) -> Optional[str]:
    s = _txt(x)
    return s if s else None



def _href(a: Any) -> str:
    """Return anchor href safely for Pylance/static typing."""
    if isinstance(a, BsTag) and a.has_attr("href"):
        v = a.get("href")  # returns str | list[str] | None at runtime
        return v if isinstance(v, str) else ""
    return ""



def _safe_find_all(node: Any, name: Any = True, **kwargs) -> list[PageElement]:
    if hasattr(node, "find_all"):
        return node.find_all(name, **kwargs)  # type: ignore[no-any-return]
    return []

def _safe_select_one(node: Any, selector: str) -> Any:
    if hasattr(node, "select_one"):
        return node.select_one(selector)
    return None

def _safe_find(node: Any, name=None, **kwargs) -> Optional[BsTag]:
    if isinstance(node, BsTag):
        el = node.find(name, **kwargs)
        return el if isinstance(el, BsTag) else None
    return None

# Back-compat (optional)
safe_find_all = _safe_find_all
safe_find = _safe_find


def _first_tag(parent: Any, name: str, **kwargs: Any) -> Optional[BsTag]:
    """Return first child Tag (never a PageElement placeholder)."""
    if not isinstance(parent, BsTag):
        return None
    found = parent.find(name, **kwargs)
    return found if isinstance(found, BsTag) else None

def _first_a_by_text(parent: Any, needle: str) -> Optional[BsTag]:
    """First <a> whose text contains needle (case-insensitive)."""
    if not isinstance(parent, BsTag):
        return None
    needle_l = needle.lower()
    # cast to help Pylance understand items are BsTag, not PageElement
    for a_tag in cast(List[BsTag], parent.find_all("a")):
        if _txt(a_tag).lower().find(needle_l) != -1:
            return a_tag
    return None

def _attr(tag: Any, name: str) -> Optional[str]:
    """Safe attribute access that returns a cleaned string or None."""
    if isinstance(tag, BsTag):
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

import inspect

def _safe_item(**kwargs):
    """
    Call Item(**filtered_kwargs) where filtered_kwargs are limited
    to the parameters actually accepted by Item's __init__.
    Also provides light aliasing (summary -> description, status -> phases).
    """
    params = set(inspect.signature(Item).parameters.keys())

    # light aliasing so either side compiles:
    if "summary" in kwargs and "description" not in kwargs and "description" in params:
        kwargs["description"] = kwargs["summary"]
    if "status" in kwargs and "phases" not in kwargs and "phases" in params:
        # single status -> single-phase list if phases is list-like; otherwise pass the string
        if "phases" in params:
            kwargs["phases"] = [kwargs["status"]] if isinstance(kwargs["status"], str) else kwargs["status"]

    filtered = {k: v for k, v in kwargs.items() if k in params}
    return Item(**filtered)



def parse_roadmap_html(path: str) -> List[Item]:
    """
    Parse the HTML you exported for the Roadmap (or Message Center styled).
    Tries a few common structures; never throws on missing bits.
    """
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        soup = BeautifulSoup(f.read(), "lxml")

    rows: List[BsTag] = []
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
        for a in cast(List[BsTag], row.find_all("a")):
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
        a_pref: Optional[BsTag] = None
        for a in cast(List[BsTag], row.find_all("a")):
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
        if isinstance(meta, BsTag):
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

def _read_html(path: str) -> str:
    """Read text file as UTF-8 with a tolerant fallback."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except UnicodeDecodeError:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()

def sniff_source(html: str) -> str:
    """
    Very light-weight heuristic to decide which parser to use.
    Return 'roadmap', 'msgcenter', or 'unknown'.
    """
    txt = html.lower()
    if "roadmap id" in txt or "feature id" in txt or "target audience" in txt:
        return "roadmap"
    if "message center" in txt or "mc" in txt and "id:" in txt:
        return "msgcenter"
    # fallbacks: look for common class/id hooks you’ve seen before
    if 'class="ms-roadmap' in txt or 'data-roadmap-id=' in txt:
        return "roadmap"
    return "unknown"

def parse_inputs(inputs: list[str], debug: bool = False):
    """
    Load each input, pick a parser, and aggregate Items.
    Requires your existing parse_roadmap_html / parse_message_center_html functions.
    """
    all_items = []
    for path in inputs:
        try:
            html = _read_html(path)
            kind = sniff_source(html)
            if debug:
                print(f"[parse] {path} -> sniff='{kind}', size={len(html):,} bytes")

            if kind == "roadmap":
                items = parse_roadmap_html(html)  # your existing function
            elif kind == "msgcenter":
                items = parse_message_center_html(html)  # your existing function
            else:
                print(f"[warn] Could not determine format for: {path}. Skipping.")
                items = []

            if debug:
                print(f"[parse] {path} -> {len(items)} item(s)")
                for i, it in enumerate(items[:3]):
                    title = getattr(it, "title", "(no title)")
                    rid = getattr(it, "roadmap_id", getattr(it, "rid", ""))
                    print(f"  - {i+1:02d}. {title} [{rid}]")

            all_items.extend(items)
        except Exception as ex:
            print(f"[error] Exception parsing {path}: {ex}")
            traceback.print_exc()

    if debug:
        print(f"[parse] TOTAL items: {len(all_items)}")
    return all_items


# --- small helpers (safe for Pylance) ----------------------------------------

def _tx(x: Any) -> str:
    if x is None:
        return ""
    if isinstance(x, (BsTag, NavigableString)):
        return x.get_text(strip=True)
    return str(x).strip()

def _csv_list(s: str) -> List[str]:
    s = (s or "").strip()
    if not s:
        return []
    # split on comma/semicolon/pipe and normalize
    parts = [p.strip() for p in re.split(r"[;,|]", s) if p.strip()]
    # de-dup while preserving order
    seen: set[str] = set()
    out: List[str] = []
    for p in parts:
        k = p.lower()
        if k not in seen:
            seen.add(k)
            out.append(p)
    return out

def _first_roadmap_link(container: BsTag) -> str:
    # Prefer official roadmap links if present
    for a in container.find_all("a", href=True):
        href = _href(a)
        href_l = href.lower()
        if "microsoft-365/roadmap" in href_l or "office365/roadmap" in href_l or "roadmap" in href_l:
            return href
    # fallback: first link
    a = container.find("a", href=True)
    return _href(a)



def _first_nonempty(*vals: str) -> str:
    for v in vals:
        if v and v.strip():
            return v.strip()
    return ""

def _normalize_label(s: str) -> str:
    # Make header/label matching tolerant
    return (
        (s or "")
        .strip()
        .lower()
        .replace("feature id", "roadmap id")
        .replace("id:", "id")
        .replace("target audience", "audience")
        .replace("status / phase", "status")
        .replace("release phase", "status")
        .replace("release", "status")
        .replace("cloud instances", "cloud")
    )

# --- table-style parser -------------------------------------------------------

def _parse_mc_table(table: BsTag) -> List[Item]:
    items: List[Item] = []
    headers: List[str] = []
    # collect headers
    thead = table.find("thead")
    if isinstance(thead, BsTag):
        ths = thead.find_all("th")
        if ths:
            headers = [_normalize_label(_tx(th)) for th in ths]
    if not headers:
        # try first row as header
        first_tr = table.find("tr")
        if isinstance(first_tr, BsTag):
            ths = first_tr.find_all(["th", "td"])
            headers = [_normalize_label(_tx(th)) for th in ths]

    if not headers:
        return items

    # map a few common columns
    # we don't require all; we pick what we can find
    def col_index(name_options: List[str]) -> Optional[int]:
        for i, h in enumerate(headers):
            for opt in name_options:
                if opt in h:
                    return i
        return None

    idx_title     = col_index(["title", "subject", "feature"])
    idx_summary   = col_index(["summary", "description", "details"])
    idx_id        = col_index(["roadmap id", "id"])
    idx_status    = col_index(["status", "phase"])
    idx_products  = col_index(["product", "products"])
    idx_platforms = col_index(["platform", "platforms"])
    idx_audience  = col_index(["audience"])
    idx_date      = col_index(["date", "month", "published", "created", "modified"])

    # iterate rows
    for tr in _safe_find_all(table, "tr"):
        tds = _safe_find_all(tr, "td")
        if not tds:
            continue

        def cell(i: Optional[int]) -> str:
            if i is None or i < 0 or i >= len(tds):
                return ""
            return _txt(tds[i])  # <- not _tx, and make sure _txt(x: Any) exists

            # ---- example extraction (adjust column indexes to your header map) ----
            title     = cell(0)
            rid       = cell(1)
            desc      = cell(2)
            status    = cell(3)
            audience  = cell(4)
            month_str = cell(5)

            # prefer a link in an explicit column; else first <a> in the row
            link_host: Any = tds[6] if 6 < len(tds) else tr
            a = safe_find(link_host, "a")
            url = (a.get("href") if a and isinstance(a.get("href"), str) else "") if a else ""

            # build your Item here with whatever columns you actually have:
            # items.append(Item(
            #     title=title or "(untitled)",
            #     summary=desc,
            #     roadmap_id=rid,
            #     url=url,
            #     month=month_str,
            #     products=[],         # or split a product column if you have one
            #     platforms=[],
            #     status=status,
            #     audience=audience,
            # 
        #)
    #)
    return items

# --- card/list-style parser ---------------------------------------------------

def _parse_mc_cards(root: BsTag) -> List[Item]:
    items: List[Item] = []
    # Example: fall back to tables if no card containers found
    for tbl in safe_find_all(root, "table"):
        # reuse the loop above inside here
        for tr in safe_find_all(tbl, "tr"):
            tds = safe_find_all(tr, "td")
            if not tds:
                continue
            def cell(i: Optional[int], default: str = "") -> str:
                return _txt(tds[i]) if (i is not None and 0 <= i < len(tds)) else default
            title = cell(0); rid = cell(1); desc = cell(2); status = cell(3); audience = cell(4); month_str = cell(5)
            a = safe_find(tr, "a"); url = a.get("href") if a and isinstance(a.get("href"), str) else ""
            items.append(_safe_item(
                title=title or "(untitled)",
                summary=desc,
                roadmap_id=rid,
                url=url,
                month=month_str,
                products=[],
                platforms=[],
                status=status,
                audience=audience,
                description=desc
            ))

    return items


# --- public entry -------------------------------------------------------------


def parse_message_center_html(html_path: str, month: str | None = None) -> list[Item]:
    """
    Parse card-based Message Center export HTML into a list[Item].

    - Works with card UIs (divs with class containing 'card' or 'ms-').
    - Extracts: rid/roadmap_id, title, description/summary, url, status,
      products, platforms, audience, phases, clouds; plus created/modified/ga when present.
    - Adapts to your Item dataclass signature at runtime (no breaking changes).
    """
    # Local imports to avoid global churn
    from bs4 import BeautifulSoup, BsTag  # type: ignore[import]
    from bs4.element import NavigableString
    import re
    import inspect
    from pathlib import Path

    # ---------- small helpers ----------
    def _txt(x: BsTag | NavigableString | None) -> str:
        if x is None:
            return ""
        try:
            return x.get_text(" ", strip=True)
        except Exception:
            return str(x).strip()

    def _first(sel: BsTag, css: str) -> BsTag | None:
        # minimal CSS-ish: only tag names and [attr] and .class
        try:
            found = sel.select_one(css)  # bs4 supports select_one when soup is built with lxml
            return found  # type: ignore[return-value]
        except Exception:
            return None

    def _find_url(card: BsTag) -> str:
        # any anchor with href that looks like a roadmap feature link
        for a in card.find_all("a", href=True):
            href = a.get("href") if hasattr(a, "get") else None
            if isinstance(href, str) and re.search(r"(featureid=|\broadmap\b|\bmicrosoft-365-roadmap\b)", href, re.I):
                return href
            # fallback: first anchor
            a0 = card.find("a", href=True)
            href = a0.get("href") if hasattr(a0, "get") else None # type: ignore[index]
        return href if isinstance(href, str) else ""
    # ---------- main logic ----



    def _find_title(card: BsTag) -> str:
        # headings or role=heading
        for sel in ("h1, h2, h3, h4", "[role=heading]"):
            h = _first(card, sel)
            if h:
                t = _txt(h)
                if t:
                    return t
        # badge or strong text as fallback
        b = _first(card, "strong") or _first(card, ".ms-Text")
        return _txt(b)

    def _longest_para(card: BsTag) -> str:
        paras = [p for p in card.find_all(["p", "div", "span"]) if _txt(p)]
        if not paras:
            return _txt(card)
        paras.sort(key=lambda p: len(_txt(p)), reverse=True)
        return _txt(paras[0])

    def _find_rid(card: BsTag) -> str:
        # Look for numeric ID in common patterns
        text = _txt(card)
        m = re.search(r"\b(?:Feature\s*ID|Roadmap\s*ID|ID)\s*[:#]?\s*([0-9]{3,8})\b", text, re.I)
        if m:
            return m.group(1)
        # Sometimes in URL
        url = _find_url(card)
        m = re.search(r"(?:featureid|features?)/?[:=]?(\d{3,8})", url, re.I)
        return m.group(1) if m else ""

    _PRODUCT_WORDS = [
        "Microsoft Teams", "Teams", "SharePoint", "Exchange", "Outlook",
        "OneDrive", "Planner", "Loop", "Viva", "Entra", "Defender",
        "Purview", "Copilot", "Microsoft 365", "Office", "Whiteboard",
        "Yammer", "Viva Engage", "Stream", "Forms", "PowerPoint Live",
    ]

    def _guess_products(text: str) -> list[str]:
        hits = []
        for w in _PRODUCT_WORDS:
            if re.search(rf"\b{re.escape(w)}\b", text, re.I):
                hits.append(w)
        # de-dup but preserve order
        seen = set()
        out: list[str] = []
        for w in hits:
            k = w.lower()
            if k not in seen:
                seen.add(k)
                out.append(w)
        return out or ["Microsoft 365"]

    _PLATFORMS = ["Web", "Windows", "Mac", "iOS", "Android", "GCC", "GCC High", "DoD", "Worldwide", "Targeted Release"]

    def _guess_platforms(text: str) -> list[str]:
        hits = []
        for p in _PLATFORMS:
            if re.search(rf"\b{re.escape(p)}\b", text, re.I):
                hits.append(p)
        # squash to a sane set
        seen = set()
        out: list[str] = []
        for p in hits:
            k = p.lower()
            if k not in seen:
                seen.add(k)
                out.append(p)
        return out or ["Worldwide"]

    def _guess_status(text: str) -> str:
        if re.search(r"\b(rolling\s*out|rollout|launched|available)\b", text, re.I):
            return "Rolling out"
        if re.search(r"\b(in\s*development|working on)\b", text, re.I):
            return "In development"
        if re.search(r"\b(public|preview|private\s*preview)\b", text, re.I):
            return "Preview"
        if re.search(r"\b(deprecated|retired|remove)\b", text, re.I):
            return "Retired"
        return "Planned"

    def _guess_audience(text: str) -> str:
        if re.search(r"\b(Targeted Release)\b", text, re.I):
            return "Targeted Release"
        if re.search(r"\b(GCC High|DoD|GCC)\b", text, re.I):
            return "Government"
        return "Standard"

    def _guess_dates(text: str) -> tuple[str | None, str | None, str | None]:
        # created, modified, ga – loose; returns (created, modified, ga)
        m_created = re.search(r"\bCreated[:\s]+([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})", text)
        m_modified = re.search(r"\bModified[:\s]+([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})", text)
        m_ga = re.search(r"\bGA[:\s]+([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})", text)
        return (
            m_created.group(1) if m_created else None,
            m_modified.group(1) if m_modified else None,
            m_ga.group(1) if m_ga else None,
        )

    def _phases(text: str) -> list[str]:
        hits = []
        for w in ["Preview", "Targeted Release", "Rolling out", "General Availability", "GA", "Retired"]:
            if re.search(rf"\b{re.escape(w)}\b", text, re.I):
                hits.append(w)
        # dedup
        seen = set()
        out: list[str] = []
        for w in hits:
            k = w.lower()
            if k not in seen:
                seen.add(k)
                out.append(w)
        return out

    def _clouds(text: str) -> list[str]:
        hits = []
        for w in ["Worldwide", "Commercial", "GCC", "GCC High", "DoD", "Education", "Sovereign"]:
            if re.search(rf"\b{re.escape(w)}\b", text, re.I):
                hits.append(w)
        # dedup
        seen = set()
        out: list[str] = []
        for w in hits:
            k = w.lower()
            if k not in seen:
                seen.add(k)
                out.append(w)
        return out or ["Worldwide"]

    # ---------- read + soup ----------
    html = Path(html_path).read_text("utf-8", errors="ignore")
    soup = BeautifulSoup(html, "lxml")

    # find cards (what your probe showed you have)
    def _is_card(el: BsTag) -> bool:
        cls =  el.get("class") if hasattr(el, "get") else None
        if not cls:
            return False
        joined = " ".join(cls)
        return ("card" in joined) or joined.startswith("ms-") or "ms-" in joined

    cards = [c for c in soup.find_all(True) if isinstance(c, BsTag) and _is_card(c)]

    items: list[Item] = []

    # Prepare runtime mapping to your Item signature
    sig = inspect.signature(Item)  # type: ignore[name-defined]
    params = [p for p in sig.parameters.keys() if p != "self"]

    # Field name mapping (left = Item param, right = keys we’ll compute)
    field_map: dict[str, list[str]] = {
        "rid": ["rid", "roadmap_id", "id"],
        "roadmap_id": ["roadmap_id", "rid", "id"],
        "title": ["title"],
        "summary": ["summary", "description"],
        "description": ["description", "summary"],
        "url": ["url"],
        "month": ["month"],
        "products": ["products", "product"],
        "product": ["product"],
        "platforms": ["platforms"],
        "status": ["status"],
        "audience": ["audience"],
        "phases": ["phases"],
        "clouds": ["clouds"],
        "created": ["created"],
        "modified": ["modified"],
        "ga": ["ga"],
    }

    made = 0
    for card in cards:
        text = _txt(card)
        if not text.strip():
            continue

        rid = _find_rid(card)
        title = _find_title(card)
        description = _longest_para(card)
        url = _find_url(card)
        status = _guess_status(text)
        products = _guess_products(text if text else title)
        platforms = _guess_platforms(text)
        audience = _guess_audience(text)
        created, modified, ga_date = _guess_dates(text)
        phases = _phases(text)
        clouds = _clouds(text)

        # Build a common bag of values
        bag: dict[str, object] = {
            "rid": rid,
            "roadmap_id": rid,
            "title": title,
            "summary": description,
            "description": description,
            "url": url,
            "month": month or "",
            "products": products,
            "product": (products[0] if products else ""),
            "platforms": platforms,
            "status": status,
            "audience": audience,
            "phases": phases,
            "clouds": clouds,
            "created": created,
            "modified": modified,
            "ga": ga_date or None,
        }

        # Align with your Item signature
        kwargs: dict[str, object] = {}
        for p in params:
            # pick first available alias for this parameter
            choices = field_map.get(p, [p])
            val = None
            for k in choices:
                if k in bag:
                    val = bag[k]
                    break
            if val is None:
                # Provide harmless defaults for unknown extras
                val = "" if p not in ("products", "platforms", "phases", "clouds") else []
            kwargs[p] = val

        try:
            items.append(Item(**kwargs))  # type: ignore[name-defined]
            made += 1
        except Exception as e:
            # Don’t crash the build if a single card is odd; skip with minimal visibility
            print(f"[parser] skip card (rid={rid!r}): {e}")

    print(f"[parser] message-center: cards={len(cards)} -> items={made}")
    return items





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
    p.add_argument("--debug-parse", action="store_true", help="Print parse diagnostics and sample titles.")
    p.add_argument("--list-only", action="store_true", help="Parse inputs and print items without creating a PPTX.")
    

    args = p.parse_args()
    assets = {
        "cover": args.cover,
        "agenda_bg": args.agenda_bg,
        "separator": args.separator,
        "conclusion_bg": args.conclusion_bg,
        "thankyou": args.thankyou,
        "brand_bg": args.brand_bg,
        "logo": args.logo,
        "logo2": args.logo2,
        "rocket": args.rocket,
        "magnifier": args.magnifier
    }

    
    # Commented out to check in .
    #print(f"[ppt_builder] Total parsed items: {len(items)} from {len(inputs)} input file(s)")

    
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
