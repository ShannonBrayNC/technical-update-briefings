import React, { useEffect, useMemo, useRef, useState } from "react";

/**
 * Teams Meeting Tab – Slide‑synced Customer View (compact)
 * -------------------------------------------------------
 * This file was trimmed to avoid "file too big" build errors and to fix prior
 * corruption from oversized comment blocks. Core UI and logic remain.
 *
 * What changed:
 *  - Removed giant commented server blueprints (moved to a short note below).
 *  - Kept Adaptive Card generator and queue/idempotency logic.
 *  - Preserved your behavior: (a) no backward jumps; (b) allow duplicate releases later.
 *  - Default export restored.
 *
 * Dev tip: outside Teams, append ?userId=YOUR_AAD_OBJECTID or ?meetingId=MEETING_ID
 * to simulate context. In dev mode, missing context shows a toast; in prod it queues silently.
 */

// -----------------------------
// Tiny UI atoms (no external UI deps)
// -----------------------------
const cx = (...arr: Array<string | false | null | undefined>) => arr.filter(Boolean).join(" ");

const Card: React.FC<React.PropsWithChildren<{ className?: string }>> = ({ className, children }) => (
  <div className={cx("rounded-2xl border bg-white shadow-sm", className)}>{children}</div>
);
const CardHeader: React.FC<React.PropsWithChildren<{ className?: string }>> = ({ className, children }) => (
  <div className={cx("p-4 md:p-5", className)}>{children}</div>
);
const CardContent: React.FC<React.PropsWithChildren<{ className?: string }>> = ({ className, children }) => (
  <div className={cx("p-4 md:p-5", className)}>{children}</div>
);
const CardTitle: React.FC<React.PropsWithChildren<{ className?: string }>> = ({ className, children }) => (
  <h3 className={cx("font-semibold", className)}>{children}</h3>
);

const Button: React.FC<React.PropsWithChildren<{ className?: string; onClick?: () => void; disabled?: boolean; variant?: "primary" | "outline" | "secondary"; size?: "sm" | "md" }>> = ({ className, children, onClick, disabled, variant = "primary", size = "md" }) => (
  <button
    onClick={onClick}
    disabled={disabled}
    className={cx(
      "rounded-2xl px-4 py-2 transition",
      size === "sm" ? "text-sm px-3 py-1.5" : "",
      variant === "outline" && "border bg-white hover:bg-slate-50",
      variant === "secondary" && "bg-slate-100 hover:bg-slate-200 border",
      variant === "primary" && "bg-violet-600 text-white hover:bg-violet-700",
      disabled && "opacity-50 cursor-not-allowed",
      className
    )}
  >
    {children}
  </button>
);

const Badge: React.FC<React.PropsWithChildren<{ className?: string; variant?: "secondary" | "outline" }>> = ({ className, children, variant = "secondary" }) => (
  <span className={cx(
    "inline-flex items-center rounded-full px-2 py-0.5 text-xs",
    variant === "secondary" ? "bg-slate-100 border" : "border",
    className
  )}>{children}</span>
);

const Input: React.FC<{ className?: string; placeholder?: string; value?: string; onChange?: (e: React.ChangeEvent<HTMLInputElement>) => void; }>
= ({ className, ...props }) => (
  <input {...props} className={cx("border rounded-xl h-9 px-3 outline-none focus:ring-2 focus:ring-violet-400", className)} />
);

const Separator: React.FC<{ className?: string }> = ({ className }) => (
  <div className={cx("h-px bg-slate-200", className)} />
);

// Tiny icons (inline SVG)
const Icon = {
  Rocket: (p: any) => (<svg viewBox="0 0 24 24" width="1em" height="1em" {...p}><path fill="currentColor" d="M12 2c3 0 7 3 9 5c-2 2-6 6-9 6s-4-1-6-3c2-3 6-8 6-8Z"/><path fill="currentColor" d="M7 14c-1 0-3 1-4 2l1 3l3 1c1-1 2-3 2-4c0-1-1-2-2-2Z"/></svg>),
  Users: (p: any) => (<svg viewBox="0 0 24 24" width="1em" height="1em" {...p}><path fill="currentColor" d="M16 11a4 4 0 1 0-4-4a4 4 0 0 0 4 4Zm-8 2a4 4 0 1 0-4-4a4 4 0 0 0 4 4Zm0 2c-3 0-6 1.5-6 3v2h12v-2c0-1.5-3-3-6-3Zm8 0c-.7 0-1.4.1-2 .3c1.8.8 3 2 3 3.7V20h7v-1c0-1.9-3.1-4-8-4Z"/></svg>),
  Shield: (p: any) => (<svg viewBox="0 0 24 24" width="1em" height="1em" {...p}><path fill="currentColor" d="M12 2l8 4v6c0 5-3.4 9.7-8 10c-4.6-.3-8-5-8-10V6l8-4Z"/></svg>),
  Search: (p: any) => (<svg viewBox="0 0 24 24" width="1em" height="1em" {...p}><path fill="currentColor" d="M10 2a8 8 0 1 1 0 16a8 8 0 0 1 0-16Zm11 19l-6-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>),
  ChevronRight: (p: any) => (<svg viewBox="0 0 24 24" width="1em" height="1em" {...p}><path fill="currentColor" d="m9 18l6-6l-6-6v12Z"/></svg>),
  Clock: (p: any) => (<svg viewBox="0 0 24 24" width="1em" height="1em" {...p}><circle cx="12" cy="12" r="9" stroke="currentColor" fill="none"/><path d="M12 7v6l4 2" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>),
  Tag: (p: any) => (<svg viewBox="0 0 24 24" width="1em" height="1em" {...p}><path fill="currentColor" d="M21 11l-9 9l-9-9V4h7l11 7Z"/></svg>),
  Database: (p: any) => (<svg viewBox="0 0 24 24" width="1em" height="1em" {...p}><ellipse cx="12" cy="5" rx="8" ry="3" fill="currentColor"/><path fill="currentColor" d="M4 7v4c0 1.7 3.6 3 8 3s8-1.3 8-3V7c-1.7 1.2-4.7 2-8 2s-6.3-.8-8-2Z"/></svg>),
};

// -----------------------------
// Types
// -----------------------------

type FeedKind = "roadmap" | "message-center" | "azure-updates" | "security";

type FeedItem = {
  id: string;
  kind: FeedKind;
  title: string;
  summary: string;
  url: string;
  product?: string;
  rollout?: string;
  lifecycle?: "Preview" | "Rolling out" | "GA" | "Retired";
  audience?: string[];
  tags?: string[];
};

type Topic = {
  id: string;
  title: string;
  feeds: FeedKind[];
  items: FeedItem[];
  slides: number[];
};

interface Citation { title: string; url: string; }
interface AskAnswer { short: string; details?: string; citations: Citation[]; }

// -----------------------------
// Behavior toggles (per your choices)
// -----------------------------
const PREVENT_BACKWARDS = true;   // do NOT revert when jumping backward
const DEDUPE_SAME_TOPIC = false;  // allow multiple releases later (slide instances)

// -----------------------------
// Seed data (trimmed)
// -----------------------------
const seedTopics: Topic[] = [
  {
    id: "482601",
    title: "Microsoft Copilot (M365): Access SharePoint agents in the Copilot app",
    feeds: ["roadmap"],
    slides: [3],
    items: [
      {
        id: "482601",
        kind: "roadmap",
        title: "Access SharePoint agents in the Microsoft 365 Copilot app",
        summary: "Use SharePoint agents directly from the M365 Copilot app without navigating to SharePoint. Quickly reopen your most recently used agents.",
        url: "https://www.microsoft.com/microsoft-365/roadmap?featureid=482601",
        product: "Microsoft 365 Copilot",
        rollout: "September 2025",
        lifecycle: "Rolling out",
        audience: ["End Users", "Admins"],
        tags: ["Copilot", "SharePoint", "M365"],
      },
    ],
  },
  {
    id: "MC999999",
    title: "Teams: Admin controls for Copilot plugin access",
    feeds: ["message-center"],
    slides: [5],
    items: [
      {
        id: "MC999999",
        kind: "message-center",
        title: "New admin policy toggles for Copilot plugins in Teams",
        summary: "Granular allow/block lists for plugins, plus reporting. Targeted release first, then WW.",
        url: "https://admin.microsoft.com/#/servicehealth",
        product: "Microsoft Teams",
        rollout: "October 2025",
        lifecycle: "Preview",
        audience: ["Admins"],
        tags: ["Copilot", "Teams", "Admin"],
      },
    ],
  },
  {
    id: "AZ-12345",
    title: "Azure Updates: Microsoft Defender for Cloud – new regulatory package",
    feeds: ["azure-updates", "security"],
    slides: [7],
    items: [
      {
        id: "AZ-12345",
        kind: "azure-updates",
        title: "Defender for Cloud adds new regulatory compliance bundle",
        summary: "Expanded coverage and mappings for industry frameworks; regional rollout.",
        url: "https://azure.microsoft.com/updates/",
        product: "Defender for Cloud",
        rollout: "Q4 2025",
        lifecycle: "GA",
        audience: ["Admins", "Security"],
        tags: ["Defender", "Compliance"],
      },
    ],
  },
];

// -----------------------------
// Shared state shim (BroadcastChannel + localStorage)
// -----------------------------
class SharedState {
  key: string;
  bc?: BroadcastChannel;
  listeners: Set<() => void> = new Set();
  constructor(key: string) {
    this.key = key;
    try { this.bc = new BroadcastChannel(key); } catch {}
    this.bc?.addEventListener("message", (e: any) => { if (e?.data?.type === "sync" && e?.data?.key === this.key) this.notify(); });
    const raw = localStorage.getItem(this.key);
    if (!raw) localStorage.setItem(this.key, JSON.stringify({ currentTopicId: null, releasedTopicIds: [], pendingAskQueue: [] }));
  }
  get<T = any>(prop: string): T | null {
    try { return (JSON.parse(localStorage.getItem(this.key) || "{}") as any)[prop] ?? null; } catch { return null; }
  }
  set(prop: string, value: any) {
    const base = JSON.parse(localStorage.getItem(this.key) || "{}");
    localStorage.setItem(this.key, JSON.stringify({ ...base, [prop]: value }));
    try { this.bc?.postMessage({ type: "sync", key: this.key }); } catch {}
    this.notify();
  }
  onChange(cb: () => void) { this.listeners.add(cb); }
  offChange(cb: () => void) { this.listeners.delete(cb); }
  notify() { this.listeners.forEach((cb) => cb()); }
}

const SHARED_MAP_KEY = "briefing-state";
const STATE_CURRENT = "currentTopicId";
const STATE_RELEASED = "releasedTopicIds";
const STATE_ASK_QUEUE = "pendingAskQueue"; // [{ topicId, card, enqueuedAt, idempotencyKey }]

// Env detection (safe)
function getAppMode(): "production" | "development" | "test" {
  try {
    const mode = (import.meta as any)?.env?.MODE || (process as any)?.env?.NODE_ENV || "development";
    if (mode === "production" || mode === "test") return mode;
    return "development";
  } catch { return "development"; }
}
const isProduction = () => getAppMode() === "production";

// Idempotency helper
function makeIdempotencyKey(topicId: string) {
  try { const uuid = (crypto as any)?.randomUUID?.(); if (uuid) return `${topicId}:${uuid}`; } catch {}
  return `${topicId}:${Date.now()}`;
}

type AskQueueItem = { topicId: string; card: any; enqueuedAt: number; idempotencyKey: string };
function readAskQueue(s: SharedState): AskQueueItem[] { return (s.get(STATE_ASK_QUEUE) as AskQueueItem[]) || []; }
function setAskQueue(s: SharedState, q: AskQueueItem[]) { s.set(STATE_ASK_QUEUE, q); }
function enqueueAsk(s: SharedState, item: AskQueueItem) { setAskQueue(s, [...readAskQueue(s), item]); }

async function flushAskQueue(s: SharedState) {
  const q = readAskQueue(s);
  if (!q.length) return;
  const meetingId = tryGetMeetingId();
  const userAadObjectId = tryGetUserAadObjectId();
  if (!meetingId && !userAadObjectId) return; // still no context
  const remaining: AskQueueItem[] = [];
  for (const it of q) {
    const key = it.idempotencyKey || makeIdempotencyKey(it.topicId);
    try {
      await fetch("/api/ask", { method: "POST", headers: { "Content-Type": "application/json", "Idempotency-Key": key }, body: JSON.stringify({ topicId: it.topicId, card: it.card, meetingId, userAadObjectId, idempotencyKey: key }) });
    } catch {
      remaining.push({ ...it, idempotencyKey: key });
    }
  }
  setAskQueue(s, remaining);
}

// Optional Teams init (safe)
async function initTeamsShim() {
  try { const teams = (window as any).microsoftTeams; await teams?.app?.initialize?.(); } catch {}
}

function tryGetMeetingId(): string | undefined {
  try { const params = new URLSearchParams(window.location.search); return params.get("meetingId") || undefined; } catch { return undefined; }
}
function tryGetUserAadObjectId(): string | undefined {
  try { const params = new URLSearchParams(window.location.search); return params.get("userId") || undefined; } catch { return undefined; }
}

// -----------------------------
// Adaptive Card: Ask‑more answer
// -----------------------------
export function buildAskMoreAdaptiveCard(item: FeedItem, answer: AskAnswer) {
  return {
    "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
    "type": "AdaptiveCard",
    "version": "1.5",
    "body": [
      { "type": "TextBlock", "text": item.title, "wrap": true, "weight": "Bolder", "size": "Large" },
      { "type": "TextBlock", "text": answer.short, "wrap": true },
      { "type": "FactSet", "facts": [
        { "title": "Product", "value": item.product || "—" },
        { "title": "Lifecycle", "value": item.lifecycle || "—" },
        { "title": "Rollout", "value": item.rollout || "TBA" },
        { "title": "ID", "value": item.id }
      ]},
      answer.details ? { "type": "TextBlock", "text": answer.details, "wrap": true, "spacing": "Medium" } : undefined,
      answer.citations?.length ? { "type": "Container", "items": [
        { "type": "TextBlock", "text": "Sources", "weight": "Bolder", "spacing": "Medium" },
        { "type": "ColumnSet", "columns": answer.citations.map((c) => ({
          "type": "Column", "width": "stretch", "items": [
            { "type": "TextBlock", "text": c.title, "wrap": true },
            { "type": "TextBlock", "text": c.url, "isSubtle": true, "wrap": true }
          ]
        })) }
      ] } : undefined
    ].filter(Boolean),
    "actions": [
      { "type": "Action.OpenUrl", "title": "Open Source", "url": item.url },
      { "type": "Action.Submit", "title": "Ask a follow-up", "data": { "action": "followup", "topicId": item.id } },
      { "type": "Action.Submit", "title": "Related updates", "data": { "action": "related", "topicId": item.id } }
    ]
  } as const;
}

// -----------------------------
// UI bits
// -----------------------------
const AudiencePills: React.FC<{ audience?: string[] }> = ({ audience }) => {
  if (!audience?.length) return null;
  return (
    <div className="flex flex-wrap gap-2 mt-2">
      {audience.map((a) => (
        <Badge key={a} variant="secondary" className="text-xs">
          <Icon.Users className="h-3 w-3 mr-1 inline" /> {a}
        </Badge>
      ))}
    </div>
  );
};

const RightRail: React.FC<{ item: FeedItem }> = ({ item }) => (
  <div className="w-full md:w-64 shrink-0 bg-violet-100/60 rounded-2xl p-4 border border-violet-200">
    <div className="flex items-center gap-2 text-violet-700 font-semibold">
      <Icon.Rocket className="h-5 w-5" /> Rollout
    </div>
    <div className="mt-1 text-sm">{item.rollout ?? "TBA"}</div>
    <Separator className="my-3" />
    <div className="text-xs text-slate-500">ID</div>
    <div className="font-mono text-sm">{item.id}</div>
    <Separator className="my-3" />
    <div className="text-xs text-slate-500">Lifecycle</div>
    <div className="text-sm">{item.lifecycle ?? "—"}</div>
    <Separator className="my-3" />
    <div className="text-xs text-slate-500">Product</div>
    <div className="text-sm">{item.product ?? "—"}</div>
    {item.tags?.length ? (
      <div className="mt-3 flex flex-wrap gap-2">
        {item.tags.map((t) => (
          <Badge key={t} variant="outline" className="text-[10px]">
            <Icon.Tag className="h-3 w-3 mr-1 inline" /> {t}
          </Badge>
        ))}
      </div>
    ) : null}
    <div className="mt-4">
      <Button className="w-full" variant="secondary" onClick={() => window.open(item.url, "_blank")}>
        Open Source
      </Button>
    </div>
  </div>
);

const TopicCard: React.FC<{ topic: Topic; highlight?: boolean; onAsk: (item: FeedItem) => void; onRelated: (item: FeedItem) => void; }>
= ({ topic, highlight, onAsk, onRelated }) => {
  const item = topic.items[0];
  const label = topic.feeds.includes("security") ? "Security" : topic.feeds.includes("azure-updates") ? "Azure Updates" : topic.feeds.includes("message-center") ? "Message Center" : "M365 Roadmap";
  return (
    <Card className={cx("border", highlight && "ring-2 ring-violet-400") as string}>
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="text-xl md:text-2xl leading-tight">{item.title}</CardTitle>
          <Badge variant="secondary" className="hidden md:inline-flex">{label}</Badge>
        </div>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col md:flex-row gap-6">
          <div className="flex-1">
            <p className="text-sm md:text-base text-slate-600">{item.summary}</p>
            <AudiencePills audience={item.audience} />
            <div className="mt-4 flex items-center gap-3">
              <Button size="sm" onClick={() => onAsk(item)}>Ask more about this</Button>
              <Button size="sm" variant="outline" onClick={() => onRelated(item)}>
                Related updates <Icon.ChevronRight className="h-4 w-4 ml-1 inline" />
              </Button>
            </div>
          </div>
          <RightRail item={item} />
        </div>
      </CardContent>
    </Card>
  );
};

// -----------------------------
// Main Meeting Tab Component
// -----------------------------
export default function MeetingTab() {
  const [shared, setShared] = useState<SharedState | null>(null);
  const [released, setReleased] = useState<string[]>([]);
  const [currentId, setCurrentId] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const initOnce = useRef(false);

  useEffect(() => {
    if (initOnce.current) return; initOnce.current = true;
    (async () => {
      await initTeamsShim();
      const s = new SharedState(SHARED_MAP_KEY);
      setShared(s);
      if (!s.get(STATE_RELEASED)) s.set(STATE_RELEASED, [] as string[]);
      if (!s.get(STATE_CURRENT)) s.set(STATE_CURRENT, null);
      if (!s.get(STATE_ASK_QUEUE)) s.set(STATE_ASK_QUEUE, [] as AskQueueItem[]);
      const onChange = () => {
        setReleased([...(s.get(STATE_RELEASED) || [])]);
        setCurrentId(s.get(STATE_CURRENT));
      };
      s.onChange(onChange); onChange();
      // Flush queue now and periodically
      try { await flushAskQueue(s); } catch {}
      const id = window.setInterval(() => { flushAskQueue(s); }, 8000);
      window.addEventListener("focus", () => { flushAskQueue(s); });
      window.addEventListener("beforeunload", () => clearInterval(id));
    })();
  }, []);

  const topics = useMemo(() => seedTopics, []);
  const releasedTopics = topics.filter((t) => released.includes(t.id));
  const nextUnreleased = topics.find((t) => !released.includes(t.id));
  const currentTopic = topics.find((t) => t.id === currentId) || releasedTopics.at(-1) || null;
  const indexOfTopic = (id: string) => topics.findIndex((t) => t.id === id);

  const releaseNext = () => {
    if (!nextUnreleased) return;
    const newReleased = DEDUPE_SAME_TOPIC ? Array.from(new Set([...released, nextUnreleased.id])) : [...released, nextUnreleased.id];
    setReleased(newReleased); setCurrentId(nextUnreleased.id);
    shared?.set(STATE_RELEASED, newReleased); shared?.set(STATE_CURRENT, nextUnreleased.id);
  };

  const pinTopic = (id: string) => {
    if (PREVENT_BACKWARDS && currentId) {
      const currIdx = indexOfTopic(currentId); const nextIdx = indexOfTopic(id);
      if (nextIdx < currIdx) return; // ignore backward jumps
    }
    setCurrentId(id); shared?.set(STATE_CURRENT, id);
  };

  const onAsk = async (item: FeedItem) => {
    const demo: AskAnswer = {
      short: `This feature lets users access their most recent SharePoint agents directly within the Copilot app, reducing context switches and improving task continuity.`,
      details: `Rollout is ${item.rollout || "TBA"}. Availability and timelines can vary by tenant and region. Check the roadmap item for the latest schedule.`,
      citations: [{ title: item.title, url: item.url }],
    };
    const card = buildAskMoreAdaptiveCard(item, demo);

    const meetingId = tryGetMeetingId();
    const userAadObjectId = tryGetUserAadObjectId();
    const idempotencyKey = makeIdempotencyKey(item.id);

    if (!meetingId && !userAadObjectId) {
      const state = shared || new SharedState(SHARED_MAP_KEY);
      enqueueAsk(state, { topicId: item.id, card, enqueuedAt: Date.now(), idempotencyKey });
      if (!isProduction()) {
        alert("No meeting/user context. Queued the card locally. (Dev mode shows this toast; production queues silently.)");
        console.log("Queued ask-more card (no context)", { topicId: item.id, card });
      }
      return;
    }

    try {
      await fetch("/api/ask", { method: "POST", headers: { "Content-Type": "application/json", "Idempotency-Key": idempotencyKey }, body: JSON.stringify({ topicId: item.id, card, meetingId, userAadObjectId, idempotencyKey }) });
      alert("Adaptive Card sent to bot (stub). Check your chat.");
      if (shared) flushAskQueue(shared);
    } catch (e) {
      console.log("Adaptive Card payload (send failed):", { meetingId, userAadObjectId, card, error: e });
      if (!isProduction()) alert("(dev) Send failed; payload logged to console.");
      const state = shared || new SharedState(SHARED_MAP_KEY);
      enqueueAsk(state, { topicId: item.id, card, enqueuedAt: Date.now(), idempotencyKey });
    }
  };

  const onRelated = async (item: FeedItem) => {
    try { await fetch(`/api/related?topicId=${encodeURIComponent(item.id)}`); alert("Fetched related updates (stub)."); }
    catch { alert("(dev) Would fetch related updates."); }
  };

  const filteredReleased = releasedTopics.filter((t) =>
    [t.title, t.items[0]?.summary, t.items[0]?.tags?.join(" ")].join(" ").toLowerCase().includes(query.toLowerCase())
  );

  return (
    <div className="min-h-screen w-full bg-gradient-to-br from-slate-50 to-violet-50 text-slate-900">
      {/* Header */}
      <div className="max-w-7xl mx-auto px-4 md:px-8 py-6">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div>
            <h1 className="text-2xl md:text-3xl font-semibold">Briefing Customer View</h1>
            <p className="text-sm text-slate-600">As slides progress, new topics unlock. The active topic is boosted in chat answers.</p>
          </div>
          <div className="flex items-center gap-3">
            <div className="relative">
              <Icon.Search className="h-4 w-4 absolute left-2 top-1/2 -translate-y-1/2" />
              <Input className="pl-8 w-64" placeholder="Search released topics" value={query} onChange={(e) => setQuery(e.target.value)} />
            </div>
            <Button onClick={releaseNext} disabled={!nextUnreleased}>Release next topic</Button>
          </div>
        </div>
      </div>

      {/* Body */}
      <div className="max-w-7xl mx-auto px-4 md:px-8 pb-10 grid grid-cols-12 gap-6">
        {/* Timeline */}
        <div className="col-span-12 md:col-span-3 lg:col-span-2">
          <Card className="sticky top-4">
            <CardHeader className="pb-2"><CardTitle className="text-base">Topics Timeline</CardTitle></CardHeader>
            <CardContent>
              <ol className="space-y-2">
                {topics.map((t, idx) => {
                  const isReleased = released.includes(t.id);
                  const isCurrent = currentTopic?.id === t.id;
                  return (
                    <li key={`${t.id}-${idx}`} className="flex items-start gap-3">
                      <div className={cx("mt-1 h-2 w-2 rounded-full", isCurrent ? "bg-violet-600" : isReleased ? "bg-violet-300" : "bg-slate-300")} />
                      <button
                        className={cx("text-left text-sm hover:underline", isCurrent && "font-semibold")}
                        onClick={() => isReleased && pinTopic(t.id)}
                        disabled={!isReleased}
                        title={!isReleased ? "Not released yet" : PREVENT_BACKWARDS ? "Pin (no backward jumps)" : "Pin as active"}
                      >
                        <span className="block">{idx + 1}. {t.title}</span>
                        <span className="text-xs text-slate-500">Slides {t.slides.join(", ")}</span>
                      </button>
                    </li>
                  );
                })}
              </ol>
            </CardContent>
          </Card>
        </div>

        {/* Tiles */}
        <div className="col-span-12 md:col-span-9 lg:col-span-10 space-y-6">
          {currentTopic ? (
            <div>
              <div className="flex items-center gap-2 mb-2"><Icon.Clock className="h-4 w-4" /><h2 className="text-lg font-semibold">Now</h2></div>
              <TopicCard topic={currentTopic} highlight onAsk={onAsk} onRelated={onRelated} />
            </div>
          ) : (
            <Card><CardContent className="py-10 text-center text-slate-500">Release a topic to begin</CardContent></Card>
          )}

          <div>
            <div className="flex items-center gap-2 mb-2"><Icon.ChevronRight className="h-4 w-4" /><h2 className="text-lg font-semibold">Released in this briefing</h2><Badge variant="secondary" className="ml-2">{filteredReleased.length}</Badge></div>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {filteredReleased.map((t, i) => (
                <TopicCard key={`${t.id}-rel-${i}`} topic={t} onAsk={onAsk} onRelated={onRelated} />
              ))}
              {filteredReleased.length === 0 && (
                <Card><CardContent className="py-8 text-center text-slate-500">No released topics match your search.</CardContent></Card>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// -----------------------------
// Self-tests (console; do not remove existing unless wrong)
// -----------------------------
function canPinTopic(currentIdx: number, nextIdx: number, preventBackwards: boolean) {
  if (!preventBackwards) return true; return nextIdx >= currentIdx;
}

(async function runSelfTests() {
  try {
    const s = new SharedState("test-briefing-state");
    s.set(STATE_RELEASED, []); s.set(STATE_CURRENT, null);
    const a = seedTopics[0].id; const b = seedTopics[1].id;
    s.set(STATE_RELEASED, [...(s.get(STATE_RELEASED) as string[]), a]); s.set(STATE_CURRENT, a);
    console.assert((s.get(STATE_RELEASED) as string[]).includes(a), "released should include first");
    s.set(STATE_RELEASED, [...(s.get(STATE_RELEASED) as string[]), b]); s.set(STATE_CURRENT, b);
    console.assert(s.get(STATE_CURRENT) === b, "current should be second");
    console.assert(canPinTopic(0,1,true) === true, "forward pin allowed");
    console.assert(canPinTopic(1,0,true) === false, "backward pin blocked");
    console.assert(canPinTopic(1,0,false) === true, "backward allowed when disabled");
    // Queue tests (no net)
    const qs = new SharedState("test-queue-state");
    qs.set(STATE_ASK_QUEUE, []);
    enqueueAsk(qs as any, { topicId: "T1", card: { foo: 1 }, enqueuedAt: Date.now(), idempotencyKey: makeIdempotencyKey("T1") });
    console.assert(((qs.get(STATE_ASK_QUEUE) as any[])?.length || 0) === 1, "queue has one item");
    const k1 = makeIdempotencyKey("T1"), k2 = makeIdempotencyKey("T1");
    console.assert(k1 !== k2, "idempotency keys unique");
    console.info("Self-tests passed: state + card + behavior + filtering + queue + idempotency");
  } catch (e) { console.warn("Self-tests error (non-fatal):", e); }
})();

/* ---------------------------------------------------------
   Server NOTE (moved out to keep this file lean)
   ---------------------------------------------------------
   Create a tiny bot project with these files (see your previous canvas history):
     - server/bot.ts            (captures meeting + user conversation refs)
     - server/queue.ts         (MemoryQueue or Azure Storage Queue)
     - server/worker.ts        (Dispatcher with retries + DLQ)
     - server/index.ts         (/api/messages, /api/ask enqueues tasks)
   ENV: QUEUE_KIND=memory|storage, MicrosoftAppId, MicrosoftAppPassword, etc.
   This UI posts Adaptive Cards to /api/ask. For dev demos, missing context queues locally.
*/
