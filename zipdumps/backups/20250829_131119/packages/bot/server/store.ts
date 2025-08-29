// Simple in-memory conversation ref store keyed by AAD object id.
// For dev/demo. Swap to Redis/Storage in prod if needed.
import { ConversationReference } from "botbuilder";

type Key = string; // userAadObjectId
const mem = new Map<Key, ConversationReference>();

export function saveRef(userAadObjectId: string, ref: ConversationReference) {
  mem.set(userAadObjectId, ref);
}
export function getRef(userAadObjectId: string) {
  return mem.get(userAadObjectId);
}
export function countRefs() { return mem.size; }
