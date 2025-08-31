# Explore structure: list common class names and sample elements to infer selectors
from bs4 import BeautifulSoup
from collections import Counter
from pathlib import Path

def analyze(path):
    html = Path(path).read_text(encoding="utf-8", errors="ignore")
    soup = BeautifulSoup(html, "html.parser")
    classes = Counter()
    for tag in soup.find_all(True):
        if tag.get("class"):
            for c in tag["class"]:
                classes[c] += 1
    print("Top classes:", classes.most_common(20))
    # look for items by a likely container
    for sel in ["div.item","div.roadmap-item","div.rm-item","div.card","article","li","section"]:
        els = soup.select(sel)
        if len(els)>5:
            print(f"Selector {sel} -> {len(els)} candidates")
            # print one sample outer HTML (truncated)
            s = str(els[0])[:800]
            print("Sample:\n", s.replace("\n"," ")[:800], "\n---")
    # try to find headings and labels
    for hsel in ["h1","h2","h3","h4",".title",".heading",".card-title"]:
        els = soup.select(hsel)
        if els:
            print(f"{hsel}: {len(els)}")
            print("sample text:", [e.get_text(strip=True) for e in els[:5]])
    # look for data attributes like data-id, data-status
    attrs = Counter()
    for tag in soup.find_all(True):
        for a in list(tag.attrs):
            if a.startswith("data-"):
                attrs[a]+=1
    print("data-* attrs:", attrs.most_common(20))

print("== Roadmap ==")
analyze("/mnt/data/RoadmapPrimarySource.html")
print("\n== Message Center ==")
analyze("/mnt/data/MessageCenterBriefingSuppliments.html")
