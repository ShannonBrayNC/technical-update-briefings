import { QueueServiceClient } from '@azure/storage-queue';
export type AskTask = { id: string; meetingId?: string; userAadObjectId?: string; topicId: string; card: any; attempts: number; enqueuedAt: number; _messageId?: string; _popReceipt?: string; };
export interface IQueue { enqueue(t: AskTask): Promise<void>; dequeue(max?: number): Promise<AskTask[]>; complete(t: AskTask): Promise<void>; deadletter?(t: AskTask): Promise<void>; }
export class MemoryQueue implements IQueue { private q: AskTask[] = []; async enqueue(t: AskTask){ this.q.push(t);} async dequeue(max=16){ return this.q.splice(0, Math.min(max, this.q.length)); } async complete(_t: AskTask){} }
export class StorageQueue implements IQueue {
  private client; private dlq;
  constructor(cs: string, q: string, dlq: string){ const svc = QueueServiceClient.fromConnectionString(cs); this.client = svc.getQueueClient(q); this.dlq = svc.getQueueClient(dlq); }
  async enqueue(t: AskTask){ await this.client.createIfNotExists(); await this.dlq.createIfNotExists(); await this.client.sendMessage(Buffer.from(JSON.stringify(t)).toString('base64')); }
  async dequeue(max=16){ await this.client.createIfNotExists(); const r = await this.client.receiveMessages({ numberOfMessages:max, visibilityTimeout:30 }); return (r.receivedMessageItems||[]).map((m:any)=>{ const b = JSON.parse(Buffer.from(m.messageText,'base64').toString('utf8')); b._messageId=m.messageId; b._popReceipt=m.popReceipt; return b; }); }
  async complete(t: AskTask){ if ((t as any)._messageId && (t as any)._popReceipt){ await this.client.deleteMessage((t as any)._messageId, (t as any)._popReceipt); } }
  async deadletter(t: AskTask){ await this.dlq.createIfNotExists(); await this.dlq.sendMessage(Buffer.from(JSON.stringify({ ...t, deadletteredAt: Date.now() })).toString('base64')); }
}
export function createQueueFromEnv(): IQueue { const kind = process.env.QUEUE_KIND || 'memory'; if (kind==='storage'){ return new StorageQueue(process.env.AZURE_STORAGE_CONNECTION_STRING!, process.env.AZURE_STORAGE_QUEUE_NAME || 'askcards', process.env.DLQ_NAME || 'askcards-dead'); } return new MemoryQueue(); }