# parsers.py — tolerant parser for Roadmap & Message Center exports
from __future__ import annotations
from bs4 import BeautifulSoup
from pathlib import Path
from typing import List, Dict, Optional
import re

_MONTHS = {
    "january":"01","february":"02","march":"03","april":"04","may":"05","june":"06",
    "july":"07","august":"08","september":"09","october":"10","november":"11","december":"12"
}

def _month_prefix(month_label: str) -> Optional[str]:
    if not month_label:
        return None
    s = month_label.strip().lower()
    m = re.match(r"([a-z]+)\s+(\d{4})", s)
    if not m:
        return None
    mon = _MONTHS.get(m.group(1))
    yr  = m.group(2)
    return f"{yr}-{mon}" if mon else None

def _split_csv(v: Optional[str]) -> List[str]:
    if not v:
        return []
    return [t.strip().title() for t in str(v).split(",") if t.strip()]

def _clean_title(t: str) -> str:
    return re.sub(r"\s+", " ", (t or "").strip())

def _find_title(node) -> str:
    # prefer data-title
    dt = (node.get("data-title") or "").strip()
    if dt:
        return _clean_title(dt)
    # else first heading h1..h4
    for tag in ("h1","h2","h3","h4"):
        h = node.find(tag)
        if h and h.get_text(strip=True):
            return _clean_title(h.get_text(strip=True))
    # fallback: text of the node trimmed
    txt = node.get_text(" ", strip=True)
    return _clean_title(txt[:140])  # keep short

def _first_href(node) -> str:
    a = node.find("a", href=True)
    return a["href"] if a else ""

def _normalize(card: Dict, month_label: str) -> Dict:
    products = card.get("products") or []
    return {
        "title": card.get("title") or "",
        "summary": card.get("summary") or "",
        "description": card.get("description") or "",
        "roadmap_id": card.get("roadmap_id") or "",
        "url": card.get("url") or "",
        "month": month_label or "",
        "product": products[0] if products else "",
        "products": products,
        "platforms": card.get("platforms") or [],
        "audience": [],
        "clouds": card.get("clouds") or [],
        "status": card.get("status") or "",
        "phases": ", ".join(card.get("phases") or []),
        "created": "",
        "modified": "",
        "ga": card.get("ga_end") or card.get("ga_start") or "",
    }

def _passes_month(card: Dict, month_label: str) -> bool:
    """Keep item if month not provided or cannot be parsed.
       If GA dates are missing, INCLUDE it."""
    if not month_label:
        return True
    pref = _month_prefix(month_label)
    if not pref:
        return True
    ga_start = (card.get('ga_start') or '')
    ga_end   = (card.get('ga_end') or '')
    if not ga_start and not ga_end:
        return True
    return ga_start.startswith(pref) or ga_end.startswith(pref)

def _extract_generic(path: str) -> List[Dict]:
    """Very tolerant extractor: look for any node with useful data-* attrs."""
    html = Path(path).read_text(encoding="utf-8", errors="ignore")
    soup = BeautifulSoup(html, "html.parser")

    # Prefer explicit IDs; else, consider nodes with other data-* hints
    candidates = soup.select("[data-id]") or soup.select("[data-title], [data-prod], [data-status], [data-phase], [data-plat], [data-cloud]")
    results: List[Dict] = []

    for node in candidates:
        attrs = node.attrs or {}
        res = {
            "roadmap_id": str(attrs.get("data-id") or "").strip(),
            "title": _find_title(node),
            "products": _split_csv(attrs.get("data-prod") or attrs.get("data-product")),
            "clouds": _split_csv(attrs.get("data-cloud")),
            "status": (attrs.get("data-status") or attrs.get("data-state") or "").strip().title(),
            "phases": _split_csv(attrs.get("data-phase")),
            "platforms": _split_csv(attrs.get("data-plat") or attrs.get("data-platform")),
            "ga_start": (attrs.get("data-ga-start") or attrs.get("data-ga") or "").strip(),
            "ga_end": (attrs.get("data-ga-end") or "").strip(),
            "summary": "",
            "description": "",
            "url": _first_href(node),
        }
        # Skip completely empty shells (no id, no title)
        if not (res["roadmap_id"] or res["title"]):
            continue
        results.append(res)

    return results

def parse_roadmap_html(path: str, month_label: str) -> List[Dict]:
    items = []
    for raw in _extract_generic(path):
        if _passes_month(raw, month_label):
            items.append(_normalize(raw, month_label))
    return items

def parse_message_center_html(path: str, month_label: str) -> List[Dict]:
    items = []
    for raw in _extract_generic(path):
        if _passes_month(raw, month_label):
            items.append(_normalize(raw, month_label))
    return items
