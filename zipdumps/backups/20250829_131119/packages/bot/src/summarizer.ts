export interface UpdateLike {
  id: string;
  title: string;
  summary?: string;
  product?: string;
  impact?: string;
  actionRequired?: string;
  rolloutPhase?: string;
  status?: string;
}

export function explainChange(u: UpdateLike): string {
  const bits: string[] = [];
  bits.push(`What changed: ${u.title}`);
  if (u.summary) bits.push(`Summary: ${u.summary}`);
  if (u.product) bits.push(`Product: ${u.product}`);
  if (u.rolloutPhase) bits.push(`Phase: ${u.rolloutPhase}`);
  if (u.status) bits.push(`Status: ${u.status}`);
  if (u.impact) bits.push(`Impact: ${u.impact}`);
  if (u.actionRequired) bits.push(`Admin action: ${u.actionRequired}`);
  // Keep to a few lines; caller can trim/format
  return bits.join("\n");
}
