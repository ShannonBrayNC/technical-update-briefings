export type SubmitAction = "explain" | "open" | "watch";
export interface SubmitPayload { action: SubmitAction; topicId: string }
