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


def _to_text(x: Any) -> str:
    if x is None:
        return ""
    get_text = getattr(x, "get_text", None)
    if callable(get_text):
        try:
            return get_text(" ", strip=True)
        except Exception:
            pass
    return _clean(x)


def _safe_find(node: Any, *args: Any, **kwargs: Any) -> Optional[Any]:
    fn = getattr(node, "find", None)
    if not callable(fn):
        return None
    try:
        return fn(*args, **kwargs)
    except Exception:
        return None


def _safe_find_all(node: Any, *args: Any, **kwargs: Any) -> List[Any]:
    fn = getattr(node, "find_all", None)
    if not callable(fn):
        return []
    try:
        out = fn(*args, **kwargs) or []
        return list(out)
    except Exception:
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
