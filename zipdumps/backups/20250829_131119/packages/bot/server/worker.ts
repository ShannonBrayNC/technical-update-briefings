import { CloudAdapter, CardFactory } from 'botbuilder';
import { IQueue, AskTask, createQueueFromEnv } from './queue';
import { ConversationRegistry } from './bot';
import { v4 as uuidv4 } from 'uuid';
const MAX_RETRIES = Number(process.env.MAX_RETRIES || 6);
const INITIAL_BACKOFF_MS = Number(process.env.INITIAL_BACKOFF_MS || 1000);
export class Dispatcher {
  private adapter: CloudAdapter; private registry: ConversationRegistry; private queue: IQueue; private started=false;
  constructor(adapter: CloudAdapter, registry: ConversationRegistry, queue?: IQueue){ this.adapter=adapter; this.registry=registry; this.queue = queue || createQueueFromEnv(); }
  async start(){ if(this.started) return; this.started=true; setInterval(()=>{ this.drain().catch(err=>console.error('[worker] drain error', err)); },2000); }
  async enqueue(task:{meetingId?:string; userAadObjectId?:string; topicId:string; card:any; idempotencyKey?:string}){ const id=task.idempotencyKey || uuidv4(); const ask:AskTask={ id, topicId:task.topicId, card:task.card, meetingId:task.meetingId, userAadObjectId:task.userAadObjectId, attempts:0, enqueuedAt:Date.now() }; await this.queue.enqueue(ask);} 
  private async deliver(t:AskTask){ const ref = t.meetingId ? this.registry.getByMeeting(t.meetingId) : (t.userAadObjectId ? this.registry.getByUser(t.userAadObjectId) : null); if(!ref) throw new Error('No conversation reference available'); await this.adapter.continueConversationAsync(process.env.MicrosoftAppId!, ref as any, async (ctx)=>{ await ctx.sendActivity({ attachments: [CardFactory.adaptiveCard(t.card)] }); }); }
  private async drain(){ const batch = await this.queue.dequeue(16); for(const t of batch){ try{ await this.deliver(t); await this.queue.complete(t); } catch { t.attempts += 1; if (t.attempts >= MAX_RETRIES){ try{ await (this.queue as any).deadletter?.(t);}catch{}; console.error('[worker] DLQ after max retries',{id:t.id, topicId:t.topicId}); continue; } const delay = INITIAL_BACKOFF_MS * Math.pow(2, t.attempts - 1); setTimeout(async ()=>{ await this.queue.enqueue(t); }, delay); } } }
}