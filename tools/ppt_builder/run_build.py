# run_build.py — v7: MC-first merge + fuzzy blend, robust parser import, diagnostics
from pptx import Presentation
from style_manager import load_style
import os, json, re, difflib, importlib.util
from typing import Dict, List
import slides as S

# --- force local parsers.py (avoid shadowing) ---
from pathlib import Path as _Path
HERE = _Path(__file__).resolve().parent
PARSERS_PATH = HERE / "parsers.py"
_pspec = importlib.util.spec_from_file_location("parsers_local", str(PARSERS_PATH))
P = importlib.util.module_from_spec(_pspec)
_pspec.loader.exec_module(P)
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

def _build_item_slide(prs, item, month: str, assets: Dict):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    S.add_full_slide_picture(slide, prs, assets.get("brand_bg") or assets.get("cover"))
    title = item.get("title", "") or item.get("headline","")
    S.add_title_box(slide, title, left_in=0.6, top_in=0.6, width_in=8.8, height_in=1.2, font_size_pt=36, bold=True, color="FFFFFF")
    body = item.get("summary") or item.get("description") or item.get("body") or ""
    S.add_text_box(slide, body, left_in=0.6, top_in=2.0, width_in=8.8, height_in=3.6, font_size_pt=20, bold=False, color="FFFFFF")
    meta_lines = []
    for k in ("roadmap_id","status","ga"):
        v = item.get(k)
        if v: meta_lines.append(f"{k.upper()}: {v}")
    if item.get("products"): meta_lines.append("Product: " + ", ".join(item["products"]))
    if item.get("clouds"): meta_lines.append("Clouds: " + ", ".join(item["clouds"]))
    if month: meta_lines.append(month)
    if item.get("url"): meta_lines.append(item["url"])
    S.add_text_box(slide, "  •  ".join(meta_lines), left_in=0.6, top_in=6.1, width_in=8.8, height_in=0.8, font_size_pt=14, bold=False, color="E6E8EF")

def build(inputs: List[str], output_path: str, month: str, assets: Dict, template: str=None, rail_width=None, conclusion_links=None, debug_dump: str|None=None):
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

    # group by product
    grouped, order = {}, []
    for it in merged_items:
        p = (it.get("products") or ["General"])[0]
        if p not in grouped:
            grouped[p] = []; order.append(p)
        grouped[p].append(it)

    if not order:
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        S.add_title_box(slide, "No updates parsed", left_in=0.6, top_in=2.0, width_in=8.8, height_in=1.2, font_size_pt=40, color="FFFFFF")
    else:
        for prod in order:
            S.add_separator_slide(prs, assets, f"{prod} updates")
            for it in grouped[prod]:
                _build_item_slide(prs, it, month, assets)

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
