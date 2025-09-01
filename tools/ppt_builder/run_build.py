# run_build.py — v7: MC-first merge + fuzzy blend, robust parser import, diagnostics
from pptx import Presentation
from style_manager import load_style
import os, json, re, difflib, importlib.util
from typing import Dict, List, Optional
import slides as S
from pptx.enum.shapes import MSO_SHAPE
from pptx.dml.color import RGBColor
from pptx.util import Inches
from typing import cast
from pptx.util import Inches, Pt
import textwrap


# --- force local parsers.py (avoid shadowing) ---
from pathlib import Path as _Path
HERE = _Path(__file__).resolve().parent
PARSERS_PATH = HERE / "parsers.py"
spec = importlib.util.spec_from_file_location("parsers_local", str(PARSERS_PATH))
if not spec or not spec.loader:
    raise ImportError(f"Cannot load parsers.py at {PARSERS_PATH}")
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)
parse_message_center_html = P.parse_message_center_html
parse_roadmap_html = P.parse_roadmap_html
# ------------------------------------------------

def _log(msg): print(f"[run_build] {msg}", flush=True)

def _safe_parse(path: str, month: str) -> List[dict]:
    low = path.lower()
    is_mc = ("messagecenter" in low) or ("message_center" in low) or ("briefing" in low)
    fn = parse_message_center_html if is_mc else parse_roadmap_html
    try:
        items = fn(path, month) or []
        for it in items:
            it.setdefault("source", "mc" if is_mc else "rm")
            it.setdefault("title", it.get("title") or "")
            it.setdefault("products", it.get("products") or [])
            it.setdefault("clouds", it.get("clouds") or [])
            it.setdefault("platforms", it.get("platforms") or [])
            it.setdefault("summary", it.get("summary") or "")
            it.setdefault("description", it.get("description") or "")
        _log(f"Parsed {len(items)} with month='{month}' from {path}")
        if len(items) == 0 and month:
            _log("No items after month filter — retrying with no month filter...")
            items = fn(path, "") or []
            for it in items:
                it.setdefault("source", "mc" if is_mc else "rm")
            _log(f"Parsed {len(items)} with month='' from {path}")
        return items
    except Exception as e:
        _log(f"ERROR parsing {path}: {e}")
        return []

def _norm_title(t: str) -> str:
    t = re.sub(r"\s+", " ", (t or "").strip()).lower()
    t = re.sub(r"[^a-z0-9 ]+", "", t)
    return t

def _sim(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, _norm_title(a), _norm_title(b)).ratio()

def _merge_record(base: dict, other: dict) -> dict:
    """
    Merge 'other' into 'base'. Message Center ('mc') wins on richer fields.
    Union list-like fields.
    """
    # pick richer text
    def pick_text(a, b):
        a = a or ""
        b = b or ""
        return b if len(b) > len(a) else a

    # prefer MC content
    src_base, src_other = base.get("source",""), other.get("source","")
    mc_first = (src_other == "mc") and (src_base != "mc")

    if mc_first:
        base["title"] = other.get("title") or base.get("title") or ""
        # favor longer/MC summaries
        base["summary"] = pick_text(base.get("summary"), other.get("summary"))
        base["description"] = pick_text(base.get("description"), other.get("description"))
        # status / ga if present
        base["status"] = other.get("status") or base.get("status") or ""
        base["ga"] = other.get("ga") or base.get("ga") or ""
        # url — keep MC if present
        if other.get("url"):
            base["url"] = other["url"]
    else:
        base["summary"] = pick_text(base.get("summary"), other.get("summary"))
        base["description"] = pick_text(base.get("description"), other.get("description"))
        if not base.get("status"):
            base["status"] = other.get("status","")
        if not base.get("ga"):
            base["ga"] = other.get("ga","")
        if not base.get("url"):
            base["url"] = other.get("url","")

    # union lists
    for k in ("products","clouds","platforms","audience"):
        a = base.get(k) or []
        b = other.get(k) or []
        base[k] = sorted({*(x for x in a if x), *(y for y in b if y)}, key=str.lower)

    # prefer explicit roadmap_id/url if base lacks
    if not base.get("roadmap_id"):
        base["roadmap_id"] = other.get("roadmap_id","")

    return base


def _merge_items(items: List[dict]) -> List[dict]:
    # 1) group by roadmap id
    by_id: Dict[str, dict] = {}
    no_id: List[dict] = []
    for it in items:
        rid = (it.get("roadmap_id") or "").strip()
        if rid:
            if rid in by_id:
                by_id[rid] = _merge_record(by_id[rid], it)
            else:
                by_id[rid] = dict(it)
        else:
            no_id.append(it)

    merged: List[dict] = list(by_id.values())

    # 2) fuzzy-merge no-id items into merged when product overlaps
    def overlap(a: Optional[List[str]], b: Optional[List[str]]) -> bool:
        return bool(set(a or []).intersection(set(b or [])))

    for it in no_id:
        best_idx, best_score = -1, 0.0
        for idx, rec in enumerate(merged):
            if not overlap(it.get("products"), rec.get("products")):
                continue
            s = _sim(it.get("title",""), rec.get("title",""))
            if s > best_score:
                best_idx, best_score = idx, s
        if best_idx >= 0 and best_score >= 0.82:
            merged[best_idx] = _merge_record(merged[best_idx], it)
        else:
            merged.append(dict(it))

    # 3) resolve any remaining dupes among 'merged' using fuzzy
    out: List[dict] = []
    for it in merged:
        if not out:
            out.append(it); continue
        best_idx, best_score = -1, 0.0
        for idx, rec in enumerate(out):
            if overlap(it.get("products"), rec.get("products")):
                s = _sim(it.get("title",""), rec.get("title",""))
                if s > best_score:
                    best_idx, best_score = idx, s
        if best_idx >= 0 and best_score >= 0.85:
            out[best_idx] = _merge_record(out[best_idx], it)
        else:
            out.append(it)

    return out

def _rail_color_for(products: Optional[List[str]]) -> str:
    p = (products or [""])[0].lower()
    palette = {
        "teams":      "5B21B6",  # purple
        "sharepoint": "065F46",  # teal
        "onedrive":   "1D4ED8",  # blue
        "exchange":   "0F172A",  # navy
        "security":   "14532D",  # green
        "outlook":    "1F2937",  # slate
        "defender":   "14532D",
        "purview":    "065F46",
        "entra":      "1D4ED8",
    }
    return palette.get(p, "0F172A")

def _add_rail(slide, rail_width_in: float = 3.5, hex_color: str = "0F172A") -> None:
    EMU = 914400
    rail_w = int(rail_width_in * EMU)
    full_w = int(10 * EMU)
    full_h = int(7.5 * EMU)
    left = full_w - rail_w
    shp = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, left, 0, rail_w, full_h)
    shp.fill.solid()
    shp.fill.fore_color.rgb = RGBColor.from_string(hex_color)
    shp.line.fill.background()

def _titlecase(s: str) -> str:
    if not s: return ""
    small = {"and","or","for","nor","a","an","the","as","at","by","in","of","on","per","to","vs","via"}
    words = s.strip().split()
    out: List[str] = []
    for i, w in enumerate(words):
        if w.isupper() or any(ch.isdigit() for ch in w):
            out.append(w); continue
        lw = w.lower()
        if i not in (0, len(words)-1) and lw in small:
            out.append(lw)
        else:
            out.append(w[:1].upper() + w[1:].lower())
    return " ".join(out)

def _add_footer(slide, month_label: str, page: Optional[int], total: Optional[int]) -> None:
    # left: month/date
    left = slide.shapes.add_textbox(Inches(0.6), Inches(7.05), Inches(4.0), Inches(0.35))
    tf = left.text_frame; tf.clear()
    p = tf.paragraphs[0]; r = p.add_run()
    r.text = month_label or ""
    r.font.size = Pt(10); r.font.color.rgb = RGBColor.from_string("94A3B8")

    # right: page number for item slides
    if page is not None and total is not None:
        right = slide.shapes.add_textbox(Inches(9.2), Inches(7.05), Inches(0.9), Inches(0.35))
        tf2 = right.text_frame; tf2.clear()
        p2 = tf2.paragraphs[0]; r2 = p2.add_run()
        r2.text = f"{page}/{total}"
        r2.font.size = Pt(10); r2.font.color.rgb = RGBColor.from_string("94A3B8")

def _status_icon_for(status: Optional[str], assets: Dict) -> Optional[str]:
    s = (status or "").lower()
    if "ga" in s or "rolling out" in s:
        return cast(Optional[str], assets.get("icon_rocket") or "")
    if "preview" in s or "in development" in s:
        return cast(Optional[str], assets.get("icon_preview") or "")
    return None

# --------------------------------------------------------------------------------------
# Slide builder for each item
# --------------------------------------------------------------------------------------

def _build_item_slide(
    prs,
    item: Dict,
    month: str,
    assets: Dict,
    rail_width: Optional[float] = None,
    page: Optional[int] = None,
    total: Optional[int] = None,
) -> None:
    slide = prs.slides.add_slide(prs.slide_layouts[6])


    # rail (auto color by product)
    rail_w = float(rail_width or 0.0)
    if rail_w > 0:
        rail_hex = _rail_color_for(item.get("products"))
        _add_rail(slide, rail_width_in=rail_w, hex_color=rail_hex)

    # rail geometry for centering chip/icon
    rail_left = 10.0 - rail_w  # slide is 10" wide



    # Title
    raw_title = item.get("title", "") or item.get("headline","")
    title = _titlecase(raw_title)

    # keep content clear of rail: 0.6" left margin + 0.3" gutter
    w_body = 10.0 - rail_w - 0.9

    TITLE_TOP = 0.6
    TITLE_FONT_PT = 34
    LINE_HEIGHT_IN = 0.55     # ≈ 34pt with ~1.1 line spacing
    MIN_TITLE_H = 1.10
    MAX_TITLE_H = 2.30

    # rough wrap: more inches -> more chars per line (empirically ~18–22 per 5.5")
    wrap_cols = max(20, int(w_body * 4.0))
    est_lines = max(1, len(textwrap.wrap(title, width=wrap_cols)))
    title_h = min(MAX_TITLE_H, max(MIN_TITLE_H, est_lines * LINE_HEIGHT_IN))

    S.add_title_box(
        slide, title,
        left_in=0.6, top_in=TITLE_TOP, width_in=w_body, height_in=title_h,
        font_size_pt=TITLE_FONT_PT, bold=True, color="FFFFFF",
        # if you want it centered inside the purple area, uncomment:
        # align=PP_ALIGN.CENTER
    )

    # Body starts below title with a small gutter
    body_top = TITLE_TOP + title_h + 0.30
    body = item.get("summary") or item.get("description") or item.get("body") or ""
    if not body:
        bullets = []
        if item.get("status"):    bullets.append(f"• Status: {item['status']}")
        if item.get("ga"):        bullets.append(f"• GA: {item['ga']}")
        if item.get("platforms"): bullets.append("• Platforms: " + ", ".join(item["platforms"]))
        if item.get("clouds"):    bullets.append("• Clouds: " + ", ".join(item["clouds"]))
        body = "\n".join(bullets)

    S.add_text_box(
        slide, body,
        left_in=0.6, top_in=body_top, width_in=w_body, height_in=3.9,
        font_size_pt=20, bold=False, color="FFFFFF"
    )


    # Clickable link (small callout)
    url = item.get("url")
    if url:
        link = slide.shapes.add_textbox(Inches(0.6), Inches(6.9), Inches(2.2), Inches(0.35))
        tf = link.text_frame; tf.clear(); tf.word_wrap = False
        p = tf.paragraphs[0]; r = p.add_run()
        r.text = "Open item ↗"
        r.font.size = Pt(12); 
        r.font.bold = True
        r.font.color.rgb = RGBColor(59, 130, 246)
        r.hyperlink.address = url

    # Footer month + page/total
    _add_footer(slide, month, page, total)

# --------------------------------------------------------------------------------------
# Build deck
# --------------------------------------------------------------------------------------

def build(
    inputs: List[str],
    output_path: str,
    month: str,
    assets: Dict,
    template: str | None = None,
    rail_width=None,
    conclusion_links=None,
    debug_dump: Optional[str] = None,
) -> None:
    _log("Starting deck build...")

    # Parse all inputs
    all_items: List[dict] = []
    for fp in inputs:
        all_items.extend(_safe_parse(fp, month))

    _log(f"Raw items before merge: {len(all_items)}")
    merged_items = _merge_items(all_items)
    _log(f"After MC-first merge + fuzzy: {len(merged_items)} unique items")

    # Optional debug JSON dump
    if debug_dump:
        try:
            os.makedirs(os.path.dirname(os.path.abspath(debug_dump)) or ".", exist_ok=True)
            with open(debug_dump, "w", encoding="utf-8") as f:
                json.dump(merged_items, f, indent=2, ensure_ascii=False)
            _log(f"Debug dump wrote {len(merged_items)} items to {os.path.abspath(debug_dump)}")
        except Exception as e:
            _log(f"Failed to write debug dump: {e}")

    # Sort by first product then title
    def first_prod(it): return (it.get("products") or ["General"])[0].lower()
    merged_items.sort(key=lambda i: (first_prod(i), (i.get("title") or '').lower()))

    prs = Presentation(template) if (template and os.path.exists(template)) else Presentation()

    # Cover + agenda
    cover_title: str = cast(str, assets.get("cover_title") or "M365 Technical Update Briefing")
    cover_dates: str = cast(str, assets.get("cover_dates") or (month or ""))
    logo1: str = cast(str, assets.get("logo") or "")
    logo2: str = cast(str, assets.get("logo2") or "")
    
    S.add_cover_slide(prs, assets, cover_title, cover_dates, logo1, logo2)
    S.add_agenda_slide(prs, assets)

    # Group items by product
    grouped: Dict[str, List[dict]] = {}
    order: List[str] = []
    for it in merged_items:
        p = (it.get("products") or ["General"])[0]
        if p not in grouped:
            grouped[p] = []; order.append(p)
        grouped[p].append(it)

    # Page/total for item slides only
    item_total = sum(len(v) for v in grouped.values())
    page_counter = 0

    if not order:
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        S.add_title_box(slide, "No updates parsed",
                        left_in=0.6, top_in=2.0, width_in=8.8, height_in=1.2,
                        font_size_pt=40, color="FFFFFF")
    else:
        for prod in order:
            S.add_separator_slide(prs, assets, f"{prod} updates")
            for it in grouped[prod]:
                page_counter += 1
                _build_item_slide(
                    prs, it, month, assets,
                    rail_width=float(rail_width) if rail_width else None,
                    page=page_counter, total=item_total
                )
        

    links = conclusion_links or [("Security","https://www.microsoft.com/security"),
                                 ("Azure","https://azure.microsoft.com/"),
                                 ("Docs","https://learn.microsoft.com/")]
    S.add_conclusion_slide(prs, assets, links)
    thank = cast(str, assets.get("thankyou") or "")
    if thank:
        S.add_full_slide_picture(prs.slides.add_slide(prs.slide_layouts[6]), prs, thank)

    out_abs = os.path.abspath(output_path)
    os.makedirs(os.path.dirname(out_abs) or ".", exist_ok=True)
    prs.save(out_abs)
    _log(f"Deck saved: {out_abs}")

# --------------------------------------------------------------------------------------
# CLI for ad-hoc runs (kept similar to earlier versions)
# --------------------------------------------------------------------------------------

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("-i","--inputs", nargs="+", required=True)
    ap.add_argument("-o","--output", required=True)
    ap.add_argument("--month", default="")
    ap.add_argument("--template", default="")
    ap.add_argument("--cover", default="")
    ap.add_argument("--agenda", default="")
    ap.add_argument("--separator", default="")
    ap.add_argument("--conclusion", default="")
    ap.add_argument("--thankyou", default="")
    ap.add_argument("--brand_bg", dest="brand_bg", default="")
    ap.add_argument("--cover_title", default="M365 Technical Update Briefing")
    ap.add_argument("--cover_dates", default="")
    ap.add_argument("--logo", default="")
    ap.add_argument("--logo2", default="")
    ap.add_argument("--rail_width", type=float, default=None)
    ap.add_argument("--debug_dump", default="")
    args = ap.parse_args()

    assets = {
        "cover": args.cover,
        "agenda": args.agenda,
        "separator": args.separator,
        "conclusion": args.conclusion,
        "thankyou": args.thankyou,
        "brand_bg": args.brand_bg,
        "cover_title": args.cover_title,
        "cover_dates": args.cover_dates,
        "logo": args.logo,
        "logo2": args.logo2

    }
    dbg = args.debug_dump or None

    build(
        args.inputs, args.output, args.month, assets,
        template=args.template, rail_width=args.rail_width,
        conclusion_links=None, debug_dump=dbg
    )
