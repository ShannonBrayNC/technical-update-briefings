import { ActivityHandler, TurnContext } from 'botbuilder';
export class ConversationRegistry {
  private byMeeting = new Map<string, Partial<TurnContext['activity']>>();
  private byUser = new Map<string, Partial<TurnContext['activity']>>();
  setByMeeting(meetingId: string, reference: Partial<TurnContext['activity']>) { this.byMeeting.set(meetingId, reference); }
  getByMeeting(meetingId: string) { return this.byMeeting.get(meetingId); }
  setByUser(userAadObjectId: string, reference: Partial<TurnContext['activity']>) { this.byUser.set(userAadObjectId, reference); }
  getByUser(userAadObjectId: string) { return this.byUser.get(userAadObjectId); }
}
export class BriefingBot extends ActivityHandler {
  private registry: ConversationRegistry;
  constructor(_conversationState: any, registry: ConversationRegistry) {
    super(); this.registry = registry;
    this.onTurn(async (context, next) => {
      const reference = TurnContext.getConversationReference(context.activity);
      const meetingId = (context.activity.channelData as any)?.meeting?.id || '';
      const userAadObjectId = (context.activity?.from as any)?.aadObjectId || (context.activity?.from?.id as string) || '';
      if (meetingId) this.registry.setByMeeting(meetingId, reference as any);
      if (userAadObjectId) this.registry.setByUser(userAadObjectId, reference as any);
      await next();
    });
    this.onMessage(async (context, next) => {
      const text = (context.activity.text || '').trim();
      if (/help/i.test(text)) {
        await context.sendActivity('I can post slide-synced update cards. Your tab can call /api/ask with a card payload to show in chat.');
      } else {
        await context.sendActivity('Ready to post Adaptive Cards when the tab requests.');
      }
      await next();
    });
    this.onInvokeActivity = async (context) => {
      const name = (context.activity.name || '').toLowerCase();
      if (name === 'adaptiveCard/action') {
        const data = (context.activity.value as any)?.action?.data || (context.activity.value as any)?.data || {};
        const action = (data.action || '').toLowerCase();
        if (action === 'followup') { await context.sendActivity(Ask a follow-up about topic ****…); return { status: 200 } as any; }
        if (action === 'related')  { await context.sendActivity(Fetching related updates for ****…); return { status: 200 } as any; }
      }
      return { status: 200 } as any;
    };
  }
}