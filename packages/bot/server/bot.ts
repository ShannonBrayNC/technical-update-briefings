import { ActivityHandler, TurnContext, TeamsActivityHandler } from "botbuilder";
import { saveRef } from "./store";

export class BriefingBot extends TeamsActivityHandler {
  constructor() {
    super();

    // Capture conversation reference whenever we hear from a user
    this.onMessage(async (context, next) => {
      await this.saveRefForUser(context);
      await context.sendActivity("Hi! I can send briefing cards. Ask me anything or click 'Ask more' in the tab.");
      await next();
    });

    this.onMembersAdded(async (context, next) => {
      await this.saveRefForUser(context);
      await next();
    });
  }

  private async saveRefForUser(context: TurnContext) {
    const ref = TurnContext.getConversationReference(context.activity);
    // Teams exposes AAD object id here:
    const aad = (context.activity.from as any)?.aadObjectId as string | undefined;
    if (aad) {
      saveRef(aad, ref);
      console.log("[bot] saved conversation reference for AAD:", aad);
    } else {
      console.log("[bot] no aadObjectId on incoming activity; cannot map user.");
    }
  }
}
