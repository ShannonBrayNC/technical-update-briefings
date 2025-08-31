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
