export type UpdateSource = "graph-message-center" | "m365-roadmap";
export interface UpdateItem {
  id: string;
  source: UpdateSource;
  title: string;
  summary?: string;
  product?: string;
  category?: string;
  impact?: string;
  actionRequired?: string;
  audience?: string;
  rolloutPhase?: string;
  status?: string;
  tags?: string[];
  links?: { label: string; url: string }[];
  publishedAt?: string;
  lastUpdatedAt?: string;
}
export interface FetchOptions { since?: string; limit?: number }
