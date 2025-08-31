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



def overlap(a: Optional[List[str]], b: Optional[List[str]]) -> bool:
    return bool(set(a or []).intersection(set(b or [])))



def _status_icon_for(status: str, assets: dict) -> str | None:
    s = (status or "").lower()
    if "ga" in s or "rolling out" in s:
        return assets.get("icon_rocket") or ""
    if "preview" in s or "in development" in s:
        return assets.get("icon_preview") or ""
    return ""




# Pick a rail color from the first product (fallback to navy)
def _rail_color_for(products) -> str:
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


def _add_rail(slide, rail_width_in: float = 3.5, hex_color: str = "0F172A"):
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
    out = []
    for i, w in enumerate(words):
        base = w
        # keep ALL-CAPS (e.g., M365, GA) and words with digits
        if base.isupper() or any(ch.isdigit() for ch in base):
            out.append(base)
            continue
        lw = base.lower()
        if i not in (0, len(words)-1) and lw in small:
            out.append(lw)
        else:
            out.append(base[:1].upper() + base[1:].lower())
    return " ".join(out)



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
    # 1) Index by Roadmap ID when available
    by_id: Dict[str, dict] = {}
    no_id: List[dict] = []

    for it in items:
        rid = (it.get("roadmap_id") or "").strip()
        if rid:
            if rid in by_id:
                by_id[rid] = _merge_record(by_id[rid], it)
            else:
                by_id[rid] = dict(it)  # copy
        else:
            no_id.append(it)

    merged: List[dict] = list(by_id.values())

    # 2) Fuzzy-merge no-ID items into existing merged records (by title + product overlap)
    def overlap(a: List[str], b: List[str]) -> bool:
        return bool(set((a or [])).intersection(set(b or [])))

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

    # 3) Fuzzy-merge remaining no-ID pairs among themselves
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


    def _build_item_slide(prs, item, month: str, assets: dict,
                      rail_width: float | None = None,
                      page: int | None = None, total: int | None = None):
        slide = prs.slides.add_slide(prs.slide_layouts[6])

    from os.path import basename
    bg = assets.get("brand_bg") or assets.get("cover") or ""
    _log(f"Item background: {basename(bg) if bg else 'none'}")


    # background (note: underscore, not space)
    bg_path: str = cast(str, assets.get("brand_bg") or assets.get("cover") or "")
    S.add_full_slide_picture(slide, prs, bg_path)


    # optional right rail
    rail_hex = _rail_color_for(item.get("products"))
    if rail_width:
        _add_rail(slide, rail_width_in=float(rail_width), hex_color=rail_hex)

    icon_path = _status_icon_for(item.get("status"), assets)
    if icon_path:
        # put icon near the top-center of the rail
        icon_w = 1.1
        icon_h = 1.1
        icon_left = rail_left + max(0.1, (rail_w - icon_w) / 2.0)
        slide.shapes.add_picture(icon_path, Inches(icon_left), Inches(0.35), width=Inches(icon_w), height=Inches(icon_h))

    # content width respects rail
    w_body = (10.0 - float(rail_width or 0) - 0.9)  # left margin 0.6 + extra 0.3

    raw_title = item.get("title", "") or item.get("headline","")
    title = _titlecase(raw_title)
    from pptx.enum.text import PP_ALIGN

    S.add_title_box(
        slide, title,
        left_in=0.6, top_in=0.6, width_in=w_body, height_in=1.1,
        font_size_pt=34, bold=True, color="FFFFFF", align=PP_ALIGN.CENTER
    )
        
    url = item.get("url")
    if url:
        link = slide.shapes.add_textbox(Inches(0.6), Inches(6.9), Inches(2.2), Inches(0.35))
        tf = link.text_frame; tf.clear(); tf.word_wrap = False
        p = tf.paragraphs[0]; r = p.add_run()
        r.text = "Open item ↗"
        r.font.size = Pt(12); r.font.bold = True
        r.font.color.rgb = RGBColor(59, 130, 246)  # blue
        r.hyperlink.address = url


    status = (item.get("status") or "").lower()
    color_map = {
        "ga": ("16A34A","FFFFFF"),
        "general": ("16A34A","FFFFFF"),
        "rolling out": ("3B82F6","FFFFFF"),
        "preview": ("F59E0B","111827"),
        "in development": ("6B7280","FFFFFF"),
    }


    # rail geometry (inches)
    rail_w = float(rail_width or 0)
    rail_left = 10.0 - rail_w  # slide width is 10"

    # estimate chip width so we can center it; tweak if your chip gets wider
    chip_w = 1.8
    chip_left = rail_left + max(0.1, (rail_w - chip_w) / 2.0)


    S.add_chip(
        slide, status.title(),
        left=chip_left, top=0.60,
        fill=fill, text_color=fg
    )


    body = item.get("summary") or item.get("description") or item.get("body") or ""
    S.add_text_box(slide, body,
        left_in=0.6, top_in=1.8, width_in=w_body, height_in=3.9,
        font_size_pt=20, bold=False, color="FFFFFF"
    )

    meta_lines = []
    for k in ("roadmap_id","status","ga"):
        v = item.get(k)
        if v: meta_lines.append(f"{k.upper()}: {v}")
    if item.get("products"): meta_lines.append("Product: " + ", ".join(item["products"]))
    if item.get("clouds"): meta_lines.append("Clouds: " + ", ".join(item["clouds"]))
    if month: meta_lines.append(month)
    if item.get("url"): meta_lines.append(item["url"])

    S.add_text_box(slide, "  •  ".join(meta_lines),
        left_in=0.6, top_in=6.2, width_in=w_body, height_in=0.7,
        font_size_pt=14, bold=False, color="E6E8EF"
    )




from pptx.util import Inches, Pt

def _add_footer(slide, month_label: str, page: int | None, total: int | None):
    # left: month/date
    left = slide.shapes.add_textbox(Inches(0.6), Inches(7.05), Inches(4.0), Inches(0.35))
    tf = left.text_frame; tf.clear()
    p = tf.paragraphs[0]; r = p.add_run()
    r.text = month_label or ""
    r.font.size = Pt(10); r.font.color.rgb = RGBColor.from_string("94A3B8")
    # right: page number
    if page and total:
        right = slide.shapes.add_textbox(Inches(9.2), Inches(7.05), Inches(0.9), Inches(0.35))
        tf2 = right.text_frame; tf2.clear()
        p2 = tf2.paragraphs[0]; r2 = p2.add_run()
        r2.text = f"{page}/{total}"
        r2.font.size = Pt(10); r2.font.color.rgb = RGBColor.from_string("94A3B8")








def build(inputs: List[str], output_path: str, month: str, assets: Dict, template: str="", rail_width=None, conclusion_links=None, icon_rocket=None, icon_preview = "", debug_dump: str|None=None):
    _log(f"Starting deck build...")

    # Parse all inputs
    all_items: List[dict] = []
    for fp in inputs:
        all_items.extend(_safe_parse(fp, month))

    _log(f"Raw items before merge: {len(all_items)}")
    merged_items = _merge_items(all_items)
    _log(f"After MC-first merge + fuzzy: {len(merged_items)} unique items")

    # optional debug dump
    if debug_dump:
        try:
            os.makedirs(os.path.dirname(os.path.abspath(debug_dump)) or ".", exist_ok=True)
            with open(debug_dump, "w", encoding="utf-8") as f:
                json.dump(merged_items, f, indent=2, ensure_ascii=False)
            _log(f"Debug dump wrote {len(merged_items)} items to {os.path.abspath(debug_dump)}")
        except Exception as e:
            _log(f"Failed to write debug dump: {e}")

    # sort by first product then title
    def first_prod(it): return (it.get("products") or ["General"])[0].lower()
    merged_items.sort(key=lambda i: (first_prod(i), (i.get("title") or '').lower()))

    prs = Presentation(template) if (template and os.path.exists(template)) else Presentation()
    if os.path.exists("style_template.yaml"): _ = load_style("style_template.yaml")

    # cover + agenda
    S.add_cover_slide(prs, assets, assets.get("cover_title","M365 Technical Update Briefing"), assets.get("cover_dates", month or ""), assets.get("logo"), assets.get("logo2"))
    S.add_agenda_slide(prs, assets)



    # group items
    grouped, order = {}, []
    for it in merged_items:
        p = (it.get("products") or ["General"])[0]
        grouped.setdefault(p, []).append(it)
        if p not in order: order.append(p)

    # compute total item slides
    item_total = sum(len(v) for v in grouped.values())
    page_counter = 0


    # After you’ve created cover + agenda and before item slides:
    # total slides = cover + agenda + separators + items + conclusion + thankyou
    # Easiest: compute page on the fly using len(prs.slides)
    for prod in order:
        S.add_separator_slide(prs, assets, f"{prod} updates")
        for it in grouped[prod]:
            _build_item_slide(prs, it, month, assets, rail_width,
                            page=len(prs.slides)+1, total=None)  # fill total later
    # After all slides are added (just before save), fill totals for pages we set:
    # (If you want exact totals printed, you can re-walk slides and overwrite the last textbox,
    # or simpler: compute total early if you prefer. If “N/M” isn’t required, keep just “N”.)


    # compute total item slides
    item_total = sum(len(v) for v in grouped.values())
    # we’ll show page counts only on item slides as 1..item_total
    page_counter = 0
    for prod in order:
        S.add_separator_slide(prs, assets, f"{prod} updates")
        for it in grouped[prod]:
            page_counter += 1
            _build_item_slide(prs, it, month, assets, rail_width,
                            page=page_counter, total=item_total)


    if not order:
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        S.add_title_box(slide, "No updates parsed", left_in=0.6, top_in=2.0, width_in=8.8, height_in=1.2, font_size_pt=40, color="FFFFFF")
    else:
        for prod in order:
            S.add_separator_slide(prs, assets, f"{prod} updates")
            for it in grouped[prod]:
                page_counter += 1
                _build_item_slide(prs, it, month, assets, rail_width,
                          page=page_counter, total=item_total)


    links = conclusion_links or [("Security","https://www.microsoft.com/security"),
                                 ("Azure","https://azure.microsoft.com/"),
                                 ("Docs","https://learn.microsoft.com/")]
    S.add_conclusion_slide(prs, assets, links)
    S.add_full_slide_picture(prs.slides.add_slide(prs.slide_layouts[6]), prs, assets.get("thankyou"))

    out_abs = os.path.abspath(output_path); os.makedirs(os.path.dirname(out_abs) or ".", exist_ok=True)
    prs.save(out_abs); _log(f"Deck saved: {out_abs}")

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
    ap.add_argument("--brand_bg", default="")
    ap.add_argument("--cover_title", default="M365 Technical Update Briefing")
    ap.add_argument("--cover_dates", default="")
    ap.add_argument("--logo", default="")
    ap.add_argument("--logo2", default="")
    ap.add_argument("--rail_width", type=float, default=None)
    ap.add_argument("--debug_dump", default="")
    args = ap.parse_args()
    assets = {k: getattr(args,k) for k in ["cover","agenda","separator","conclusion","thankyou","brand_bg","cover_title","cover_dates","logo","logo2"]}
    dbg = args.debug_dump or None
    build(args.inputs, args.output, args.month, assets, template=args.template, rail_width=args.rail_width, conclusion_links=None, debug_dump=dbg)
