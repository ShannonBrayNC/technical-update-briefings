import crypto from "node:crypto";

export function idempotencyKey(parts: Array<string | number | undefined>) {
  const s = parts.filter((p) => p !== undefined && p !== null).join(":");
  return crypto.createHash("sha256").update(s).digest("hex");
}
