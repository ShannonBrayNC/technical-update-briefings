import type { UpdateItem, FetchOptions } from "../domain";

/**
 * Microsoft 365 Public Roadmap JSON API
 * Provide base via ENV: M365_ROADMAP_BASE (e.g., https://www.microsoft.com/releasecommunications/api/v1/m365)
 * Endpoint example used here: `${M365_ROADMAP_BASE}/roadmap` returning an array of items.
 */
export async function fetchM365Roadmap(opts: FetchOptions = {}): Promise<UpdateItem[]> {
  const base = process.env.M365_ROADMAP_BASE;
  if (!base) throw new Error("M365_ROADMAP_BASE is required");

  const url = new URL("roadmap", base).toString();
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Roadmap fetch failed: ${res.status}`);
  const raw = await res.json();

  const items: any[] = Array.isArray(raw?.items) ? raw.items : Array.isArray(raw) ? raw : [];
  const since = opts.since ? new Date(opts.since) : undefined;

  const mapped = items.map((r) => {
    const links = [] as { label: string; url: string }[];
    if (r.externalLink) links.push({ label: "Roadmap", url: r.externalLink });
    if (r.learnMoreLink) links.push({ label: "Learn more", url: r.learnMoreLink });

    const it: UpdateItem = {
      id: String(r.id ?? r.featureId ?? r.rowKey ?? crypto.randomUUID()),
      source: "m365-roadmap",
      title: r.title ?? r.featureName ?? "(no title)",
      summary: r.description ?? r.summary ?? undefined,
      product: r.product ?? r.productName ?? r.workload,
      category: r.category ?? r.categoryName,
      impact: r.impact ?? "medium",
      actionRequired: undefined,
      audience: r.audience ?? "admins",
      rolloutPhase: r.releasePhase ?? r.releasePhaseName ?? r.ring,
      status: r.status ?? r.state,
      tags: (r.tags ?? r.featureTags ?? "").toString().split(",").map((s: string) => s.trim()).filter(Boolean),
      links,
      publishedAt: r.createdDateTime ?? r.startDate,
      lastUpdatedAt: r.lastModifiedDateTime ?? r.lastUpdated ?? r.publicationDate,
    };
    return it;
  });

  const filtered = since ? mapped.filter((m) => new Date(m.lastUpdatedAt ?? m.publishedAt ?? 0) >= since) : mapped;
  return (opts.limit ? filtered.slice(0, opts.limit) : filtered);
}
