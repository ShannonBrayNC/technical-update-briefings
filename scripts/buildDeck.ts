import PptxGenJS from "pptxgenjs";
import fs from "node:fs/promises";
import path from "node:path";
import { fetchM365Roadmap, UpdateItem } from "../packages/ingestion/src";

function cleanText(s?: string) { return (s ?? "").toString().replace(/\r?\n+/g, " ").trim(); }

async function buildDeck(items: UpdateItem[]) {
  const pptx = new PptxGenJS();
  pptx.author = "Briefings";
  pptx.company = "Technical Update Briefings";
  pptx.title = "Microsoft 365 Roadmap – Full Export";

  const slide0 = pptx.addSlide();
  const now = new Date();
  slide0.addText("Microsoft 365 Roadmap – Full Export", { x: 0.5, y: 1.5, w: 9, h: 1, fontSize: 32, bold: true });
  slide0.addText(`${items.length} items · ${now.toLocaleDateString()}`, { x: 0.5, y: 2.4, w: 9, h: 0.6, fontSize: 16 });

  for (const it of items) {
    const s = pptx.addSlide();
    const header = cleanText(it.title);
    const sub = [it.product, it.status || it.category, it.rolloutPhase].filter(Boolean).join(" · ");
    const summary = cleanText(it.summary);
    const facts: string[] = [];
    if (it.impact) facts.push(`Impact: ${it.impact}`);
    if (it.actionRequired) facts.push(`Action: ${cleanText(it.actionRequired)}`);
    if (it.lastUpdatedAt) facts.push(`Updated: ${new Date(it.lastUpdatedAt).toLocaleDateString()}`);
    s.addText(header || "(no title)", { x: 0.5, y: 0.5, w: 9, h: 0.8, fontSize: 24, bold: true });
    if (sub) s.addText(sub, { x: 0.5, y: 1.2, w: 9, h: 0.5, fontSize: 14 });
    if (summary) s.addText(summary.slice(0, 2000), { x: 0.5, y: 1.8, w: 9, h: 3.5, fontSize: 14, valign: "top" });
    if (facts.length) s.addText(facts.join("\n"), { x: 0.5, y: 5.5, w: 9, h: 1.5, fontSize: 12 });
    const link = it.links && it.links.length ? it.links[0].url : "";
    if (link) s.addText("Roadmap link", { x: 0.5, y: 7.1, w: 3.5, h: 0.4, fontSize: 12, hyperlink: { url: link } });
  }

  const outPath = path.resolve("RoadmapDeck_AutoGen.pptx");
  const buf = await pptx.write("nodebuffer");
  await fs.writeFile(outPath, Buffer.from(buf));
  console.log(`Wrote deck with ${items.length} slide(s) -> ${outPath}`);
}

async function main() {
  console.log("Fetching ALL roadmap items (no filters)…");
  let items: UpdateItem[] = await fetchM365Roadmap({});
  if (!Array.isArray(items) || items.length === 0) {
    console.error("ERROR: Parser returned 0 items. Check M365_ROADMAP_BASE and network access.");
    process.exit(2);
  }
  await buildDeck(items);
}
main().catch((e) => { console.error(e); process.exit(1); });
