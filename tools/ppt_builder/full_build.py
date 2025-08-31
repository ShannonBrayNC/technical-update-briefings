import os
from pptx import Presentation
from style_manager import load_style
from layout import Layout
from parsers import parse_message_center_html, parse_roadmap_html
from dataclasses import dataclass, field
from typing import List

# Define your Item dataclass
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

def parse_html_files(file_paths, month):
    """Parse your HTML files and convert to Item objects."""
    items = []
    for path in file_paths:
        if "messagecenter" in path.lower() or "briefing" in path.lower():
            dicts = parse_message_center_html(path, month)
        else:
            dicts = parse_roadmap_html(path, month)

        for d in dicts:
            # convert dict to Item
            item = Item(
                title=d.get("title", ""),
                summary=d.get("summary", ""),
                description=d.get("description", ""),
                roadmap_id=d.get("roadmap_id", ""),
                url=d.get("url", ""),
                month=month,
                product=d.get("product", ""),
                products=d.get("products", []),
                platforms=d.get("platforms", []),
                audience=d.get("audience", []),
                clouds=d.get("clouds", []),
                status=d.get("status", ""),
                phases=d.get("phases", ""),
                created=d.get("created", ""),
                modified=d.get("modified", ""),
                ga=d.get("ga", ""),
            )
            items.append(item)
    return items

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Full deck generator")
    parser.add_argument("-i", "--inputs", nargs="+", required=True, help="HTML input files")
    parser.add_argument("-o", "--output", required=True, help="Output PPTX filename")
    parser.add_argument("--style", default="style_template.yaml", help="Path to style YAML")
    parser.add_argument("--month", default="", help="Month string")
    args = parser.parse_args()

    # Load style config
    style_cfg = load_style(args.style)

    # Parse items
    items = parse_html_files(args.inputs, args.month)

    # Deduplicate and sort
    seen_keys = set()
    unique_items = []
    for it in items:
        key = (it.roadmap_id or it.title or it.url).lower()
        if key and key not in seen_keys:
            seen_keys.add(key)
            unique_items.append(it)
    unique_items.sort(key=lambda i: (i.products or [], i.title))

    # Prepare Assets dict (simulate fixing paths)
    assets = {
        "cover": None,
        "agenda": None,
        "separator": None,
        "conclusion": None,
        "thankyou": None,
        "cover_title": "My Quarterly Update",
        "cover_dates": args.month,
    }

    # Initialize presentation
    prs = Presentation()

    # Initialize layout with style
    layout = Layout(style_cfg)

    # Add cover slide
    content = {"title": assets["cover_title"], "dates": assets["cover_dates"]}
    layout.add_cover_slide(prs, assets, content)

    # Group items by product for sections
    grouped = {}
    order = []
    for item in unique_items:
        p = item.products[0] if item.products else "General"
        if p not in grouped:
            grouped[p] = []
            order.append(p)
        grouped[p].append(item)

    # Generate slides: separator + item per group
    for prod in order:
        layout.add_separator_slide(prs, assets, f"{prod} updates")
        for item in grouped[prod]:
            layout.add_item_slide(prs, item, args.month, assets=assets)

    # Add conclusion slide
    links = [
        ("Security", "https://www.microsoft.com/security"),
        ("Azure", "https://azure.microsoft.com/"),
        ("Docs", "https://learn.microsoft.com/")
    ]
    layout.add_conclusion_slide(prs, assets, links)

    # Add thank you slide
    layout.add_thankyou_slide(prs, assets)

    # Save the presentation
    prs.save(args.output)
    print(f"Deck created: {args.output}")

# Entry point
if __name__ == "__main__":
    main()