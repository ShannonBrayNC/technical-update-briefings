import type { FetchOptions, UpdateItem } from "./domain";
import { fetchGraphMessages } from "./sources/graphServiceComms";
import { fetchM365Roadmap } from "./sources/m365Roadmap";

export async function fetchAllUpdates(opts: FetchOptions = {}): Promise<UpdateItem[]> {
  const [mc, rm] = await Promise.all([
    fetchGraphMessages(opts).catch((e) => {
      console.warn("Graph fetch failed", e?.message);
      return [] as UpdateItem[];
    }),
    fetchM365Roadmap(opts).catch((e) => {
      console.warn("Roadmap fetch failed", e?.message);
      return [] as UpdateItem[];
    }),
  ]);

  const key = (u: UpdateItem) => `${(u.product ?? "").toLowerCase()}::${u.title.toLowerCase()}`;
  const map = new Map<string, UpdateItem>();
  [...mc, ...rm].forEach((u) => {
    const k = key(u);
    const existing = map.get(k);
    if (!existing) map.set(k, u);
    else {
      const merged: UpdateItem =
        existing.source === "graph-message-center"
          ? { ...existing, links: [...(existing.links ?? []), ...(u.links ?? [])] }
          : { ...u,        links: [...(u.links ?? []),        ...(existing.links ?? [])] };
      map.set(k, merged);
    }
  });

  return [...map.values()].sort(
    (a, b) =>
      new Date(b.lastUpdatedAt ?? b.publishedAt ?? 0).getTime() -
      new Date(a.lastUpdatedAt ?? a.publishedAt ?? 0).getTime()
  );
}
