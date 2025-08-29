export type FeedKind = "roadmap" | "message-center" | "azure-updates" | "security";
export type Citation = { title: string; url: string };
export type AskAnswer = { short: string; details?: string; citations: Citation[] };