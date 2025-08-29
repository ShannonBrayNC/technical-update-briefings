import type { UpdateItem, FetchOptions } from "../domain";

export async function fetchM365Roadmap(_opts: FetchOptions = {}): Promise<UpdateItem[]> {
  const base = process.env.M365_ROADMAP_BASE || "https://www.microsoft.com/releasecommunications/api/v1/m365";
  const url = new URL("roadmap", base).toString();
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Roadmap fetch failed: ${res.status}`);
  const raw = await res.json();

  const arr: any[] = Array.isArray(raw) ? raw : Array.isArray(raw?.items) ? raw.items : [];
  return arr.map((r: any) => {
    const links: { label: string; url: string }[] = [];
    if (r.externalLink) links.push({ label: "Roadmap", url: r.externalLink });
    if (r.learnMoreLink) links.push({ label: "Learn more", url: r.learnMoreLink });
    return {
      id: String(r.id ?? r.featureId ?? r.rowKey ?? crypto.randomUUID()),
      source: "m365-roadmap" as const,
      title: r.title ?? r.featureName ?? "(no title)",
      summary: r.description ?? r.summary ?? "",
      product: r.product ?? r.productName ?? r.workload ?? "",
      category: r.category ?? r.categoryName ?? "",
      impact: (r.impact ?? "medium")?.toString().toLowerCase(),
      actionRequired: undefined,
      audience: r.audience ?? "admins",
      rolloutPhase: r.releasePhase ?? r.releasePhaseName ?? r.ring ?? "",
      status: r.status ?? r.state ?? "",
      tags: (r.tags ?? r.featureTags ?? "").toString().split(",").map((s: string) => s.trim()).filter(Boolean),
      links,
      publishedAt: r.createdDateTime ?? r.startDate ?? null,
      lastUpdatedAt: r.lastModifiedDateTime ?? r.lastUpdated ?? r.publicationDate ?? null,
    } as UpdateItem;
  });
}
