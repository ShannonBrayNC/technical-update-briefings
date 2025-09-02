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


_LABELS = {
    "roadmap_id":   ["roadmap id"],
    "status":       ["status"],
    "phases":       ["release phases", "release phase"],
    "platforms":    ["platforms", "platform(s)"],
    "clouds":       ["cloud instances", "cloud instance", "clouds"],
    "rollout_start":["rollout start", "ga", "ga start", "ga date"],
}

_IMPACT_LBLS = [
    "what is the impact", "what’s the impact", "impact",
    "what is impact of this change", "how this will affect your organization"
]
_HOWTO_LBLS = [
    "how to implement", "what you need to do", "action required",
    "next steps", "what you need to do to prepare"
]
_LICENSE_LBLS = ["required license", "license required", "licensing"]



import re

def _rx(text: str, pat: str) -> str:
    m = re.search(pat, text, flags=re.I)
    return (m.group(1).strip() if m else "")

def _mc_meta_triplet(card) -> dict:
    """
    Extracts Created / Modified / GA (Rollout start) from the small 'meta' line
    at the top of Message Center cards. Stops at the next label or a bullet (·).
    """
    flat = re.sub(r"\s+", " ", card.get_text(" ", strip=True))
    # Lookahead stops at the next label or bullet separator
    created  = _rx(flat, r"Created\s*:?\s*(.+?)(?=\s*(?:·|Modified|Last updated|GA|Rollout|Description|$))")
    modified = _rx(flat, r"(?:Modified|Last updated)\s*:?\s*(.+?)(?=\s*(?:·|Created|GA|Rollout|Description|$))")
    ga       = _rx(flat, r"(?:GA|Rollout start)\s*:?\s*(.+?)(?=\s*(?:·|Created|Modified|Last updated|Description|$))")
    # Normalize short month strings like 'September 2025' by trimming any trailing junk
    for k, v in {"created": created, "modified": modified, "ga": ga}.items():
        if v:
            # strip any accidental label fragments if present
            v = re.sub(r"\s*(Created|Modified|GA|Rollout|Description)\s*:.*$", "", v, flags=re.I).strip()
            if k == "ga":
                v = v.replace("GA:", "").strip()
            if k == "modified":
                v = v.replace("Last updated:", "").strip()
            if k == "created":
                v = v.replace("Created:", "").strip()
            if k == "ga":
                ga = v
            elif k == "modified":
                modified = v
            else:
                created = v
    return {"created": created, "modified": modified, "ga": ga}






def _text(el):
    try:
        return re.sub(r"\s+", " ", el.get_text(" ", strip=True)).strip()
    except Exception:
        return ""

def _grab_section_after(card, labels):
    pat = re.compile("|".join([re.escape(x) for x in labels]), re.I)
    hdr = None
    for el in card.find_all(["h1","h2","h3","h4","strong","b","p","span"]):
        if pat.search(_text(el)):
            hdr = el; break
    if not hdr:
        return ""
    parts = []
    for sib in hdr.next_siblings:
        name = getattr(sib, "name", None)
        if name in ("h1","h2","h3","h4","strong","b"):  # stop at next section
            break
        t = _text(sib) if name else str(sib).strip()
        if t:
            parts.append(t)
    return " ".join(parts).strip()

def _mc_qna(card):
    return {
        "required_license": _grab_section_after(card, _LICENSE_LBLS),
        "impact":            _grab_section_after(card, _IMPACT_LBLS),
        "how_to_implement":  _grab_section_after(card, _HOWTO_LBLS),
    }



def _find_label_value(scope, variants):
    pat = re.compile("|".join(map(re.escape, variants)), re.I)
    for node in scope.find_all(text=pat):
        # common RM layout: label then sibling has the value
        sib = node.parent.find_next_sibling()
        if sib and _text(sib):
            return _text(sib)
        par_sib = node.parent.parent.find_next_sibling() if node.parent else None
        if par_sib and _text(par_sib):
            return _text(par_sib)
    return ""

def _rm_fallbacks(card):
    # only used if data-* attributes are missing/empty
    phases = _find_label_value(card, _LABELS["phases"])
    plats  = _find_label_value(card, _LABELS["platforms"])
    clouds = _find_label_value(card, _LABELS["clouds"])
    return {
        "roadmap_id":   _find_label_value(card, _LABELS["roadmap_id"]),
        "status":       _find_label_value(card, _LABELS["status"]),
        "phases":       [s.strip() for s in re.split(r",|;|\u2022|\|", phases) if s.strip()],
        "platforms":    [s.strip() for s in re.split(r",|;|\u2022|\|", plats) if s.strip()],
        "clouds":       [s.strip() for s in re.split(r",|;|\u2022|\|", clouds) if s.strip()],
        "rollout_start":_find_label_value(card, _LABELS["rollout_start"]),
    }




def _split_list(val: str):
    if not val: return []
    return [s.strip() for s in re.split(r",|•|;|\|", val) if s.strip()]

def _extract_from_labels(card):
    """Fallback when data-* attributes aren’t present."""
    get = lambda k: _find_label_value(card, _LABELS[k])
    d = {}
    d["roadmap_id"]   = get("roadmap_id")
    d["status"]       = get("status")
    d["phases"]       = _split_list(get("phases"))
    d["platforms"]    = _split_list(get("platforms"))
    d["clouds"]       = _split_list(get("clouds"))
    # prefer YYYY-MM-DD if present; otherwise keep month text
    roll = get("rollout_start")
    d["rollout_start"] = roll
    return d

def parse_message_center_html(path: str, month_label: str = "") -> list[dict]:
    html = Path(path).read_text(encoding="utf-8", errors="ignore")
    soup = BeautifulSoup(html, "html.parser")
    cards = soup.select("div.card, article, section") or soup.select("div")
    items = []
    for c in cards:
        title_el = c.find(["h1","h2","h3","h4"])
        title = (title_el.get_text(strip=True) if title_el else "").strip()

        # pick up a concise summary paragraph if you already have that logic;
        # otherwise keep whatever you had (leaving it untouched here):
        summary = ""  # or your prior summary logic

        it = {
            "source": "message_center",
            "title": title,
            "summary": summary,
            "description": "",
            "url": "",
        }
        # ← add Created / Modified / GA without dragging in Description
        it.update(_mc_meta_triplet(c))

        # keep any other MC fields you already set (impact/how_to_implement/etc.)
        # it["impact"] = ...
        # it["how_to_implement"] = ...
        # it["required_license"] = ...

        # keep only meaningful cards
        if it["title"] or it.get("summary") or it.get("ga") or it.get("created"):
            items.append(it)
    return items

def parse_roadmap_html(path: str, month_label: str = "") -> list[dict]:
    html = Path(path).read_text(encoding="utf-8", errors="ignore")
    soup = BeautifulSoup(html, "html.parser")
    cards = soup.select("div.card, article, section") or soup.select("div")
    items = []
    for c in cards:
        a = getattr(c, "attrs", {}) or {}
        h = c.find(["h2","h3","h4"])
        it = {
            "source": "roadmap",
            "title": (h.get_text(strip=True) if h else (a.get("data-title") or "")).strip(),
            "roadmap_id": str(a.get("data-id") or "").strip(),
            "status":     (a.get("data-status") or "").strip(),
            "phases":     [s.strip() for s in (a.get("data-phase") or "").split(",") if s.strip()],
            "platforms":  [s.strip() for s in (a.get("data-plat")  or "").split(",") if s.strip()],
            "clouds":     [s.strip() for s in (a.get("data-cloud") or "").split(",") if s.strip()],
            "ga_start":   (a.get("data-ga-start") or "").strip(),
            "ga_end":     (a.get("data-ga-end")   or "").strip(),
            "url":        (a.get("data-url") or ""),
            "summary": "", "description": ""
        }
        # Fallbacks from visible labels when data-* are missing
        if not it["status"] or not it["phases"] or not it["roadmap_id"]:
            it |= _rm_fallbacks(c)
        if not it.get("rollout_start"):
            it["rollout_start"] = it.get("ga_start") or it.get("ga_end")
        if it["title"] and (it["roadmap_id"] or it["status"] or it["phases"]):
            items.append(it)
    return items

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

