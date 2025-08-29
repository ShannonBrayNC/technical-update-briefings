// Domain model shared across sources
export type UpdateSource = "graph-message-center" | "m365-roadmap";

export interface UpdateItem {
  id: string;                // stable external id
  source: UpdateSource;
  title: string;
  summary?: string;
  product?: string;
  category?: string;         // e.g., Admin impact / New feature / Updated feature
  impact?: string;           // high/medium/low (derived)
  actionRequired?: string;   // admin action text
  audience?: string;         // admins / end users / developers
  rolloutPhase?: string;     // targeted / GA / preview
  status?: string;           // roadmap states (Launched / In development / Rolling out)
  tags?: string[];
  links?: { label: string; url: string }[];
  publishedAt?: string;      // ISO string
  lastUpdatedAt?: string;    // ISO string
}

export interface FetchOptions {
  since?: string;            // ISO date to fetch deltas
  limit?: number;
}
