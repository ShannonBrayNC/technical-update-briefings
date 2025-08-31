import os
from pptx import Presentation
from layout import Layout
from parsers import parse_message_center_html, parse_roadmap_html

def _to_item(d):
    from dataclasses import dataclass, field
    from typing import List
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

    return Item(
        title=d.get("title", ""),
        summary=d.get("summary", ""),
        description=d.get("description", ""),
        roadmap_id=d.get("roadmap_id", ""),
        url=d.get("url", ""),
        month=d.get("month", ""),
        product=d.get("product", ""),
        products=d.get("products", []),
        platforms=d.get("platforms", []),
        audience=d.get("audience", []),
        clouds=d.get("clouds", []),
        status=d.get("status", ""),
        phases=d.get("phases", ""),
        created=d.get("created", ""),
        modified=d.get("modified", ""),
        ga=d.get("ga", "")
    )

def build(inputs, output_path, month, assets, template=None, rail_width=3.5, conclusion_links=None):
    if template and os.path.exists(template):
        prs = Presentation(template)
    else:
        prs = Presentation()

    # Initialize layout
    layout = Layout(assets)

    # Add cover slide
    content = {'title': assets.get("cover_title", "Title"), 'dates': assets.get("cover_dates", "")}
    layout.add_cover_slide(prs, content=content,assets=assets)

    # Parse inputs
    all_items = []
    for path in inputs:
        try:
            if "messagecenter" in path.lower() or "briefing" in path.lower():
                dicts = parse_message_center_html(path, month)
            else:
                dicts = parse_roadmap_html(path, month)
            for d in dicts:
                all_items.append(_to_item(d))
        except Exception as e:
            print(f"Error processing {path}: {e}")

    # Deduplicate
    seen = set()
    unique_items = []
    for item in all_items:
        key = (item.roadmap_id or item.title or item.url).lower()
        if key and key not in seen:
            seen.add(key)
            unique_items.append(item)

    # Sort
    unique_items.sort(key=lambda i: (i.products or [], i.title))

    # Group
    grouped = {}
    order = []
    for item in unique_items:
        prod = (item.products[0] if item.products else "General").strip()
        if prod not in grouped:
            grouped[prod] = []
            order.append(prod)
        grouped[prod].append(item)

    # Slides
    for prod in order:
        layout.add_separator_slide(prs, assets, f"{prod} updates")
        for item in grouped[prod]:
            try:
                layout.add_item_slide(
                    prs, item, month_str=month, assets=assets,
                    rail_left_in=int(rail_width), rail_width_in=int(rail_width)
                )
            except Exception as e:
                print(f"Error adding slide for {item.title}: {e}")

    # Conclusion slide
    if not conclusion_links:
        conclusion_links = [
            ("Microsoft Security", "https://www.microsoft.com/en-us/security"),
            ("Azure Updates", "https://azure.microsoft.com/en-us/updates/"),
            ("Dynamics 365 & Power Platform", "https://www.microsoft.com/en-us/dynamics-365"),
            ("Documentation", "https://learn.microsoft.com/")
        ]
    layout.add_conclusion_slide(prs, assets, conclusion_links)

    # Thank you slide
    layout.add_thankyou_slide(prs, assets)

    # Save
    prs.save(output_path)
    print(f"Saved: {output_path}")