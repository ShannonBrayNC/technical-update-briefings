import { ActivityHandler, CardFactory, MessageFactory, TurnContext } from "botbuilder";
import { Template } from "adaptivecards-templating";
import { explainChange } from "./summarizer";
import { buildSingleSlide } from "./pptx";
import type { SubmitPayload } from "../../types/payloads";
import type { UpdateItem } from "../../ingestion/src/domain";
import { fetchAllUpdates } from "../../ingestion/src";

async function findUpdate(topicId: string): Promise<UpdateItem | undefined> {
  // Try cache first
  try {
    const fs = await import("node:fs/promises");
    const data = await fs.readFile(".cache/updates.json", "utf8");
    const json = JSON.parse(data);
    const hit = (json.items as UpdateItem[]).find(u => u.id === topicId);
    if (hit) return hit;
  } catch {}
  // Fallback: fetch fresh
  const list = await fetchAllUpdates({ limit: 400 });
  return list.find(u => u.id === topicId);
}

export class TeamsBriefingsBot extends ActivityHandler {
  constructor() {
    super();

    this.onMessage(async (context, next) => {
      await context.sendActivity("Hi! Send an Adaptive Card submit with { action: 'explain', topicId } to get an explanation.");
      await next();
    });

    // Handle invoke activities from Action.Submit
    this.onInvokeActivity = async (context) => {
      const value = (context.activity as any)?.value as SubmitPayload | undefined;
      if (!value || value.action !== "explain" || !value.topicId) {
        return { status: 200 };
      }

      const item = await findUpdate(value.topicId);
      if (!item) {
        await context.sendActivity(`Sorry, I couldn't find an update with id ${value.topicId}.`);
        return { status: 200 };
      }

      const explanation = explainChange(item);
      // Reply text
      await context.sendActivity(MessageFactory.text(explanation));

      // Card reply
      const cardJson = require("fs").readFileSync("adaptiveCards/updateExplanation.json", "utf8");
      const tmpl = new Template(JSON.parse(cardJson));
      const card = tmpl.expand({
        $root: {
          ...item,
          explanation
        }
      });
      await context.sendActivity({ attachments: [CardFactory.adaptiveCard(card)] });

      // Optional: PPTX attachment
      try {
        const buf = await buildSingleSlide({
          title: item.title,
          explanation,
          product: item.product,
          status: item.status,
        });
        await context.sendActivity({
          text: "Slide attached.",
          attachments: [{
            name: `${item.title.replace(/[^a-z0-9\-]+/gi, "_").slice(0,80)}.pptx`,
            contentType: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            content: buf.toString("base64")
          }]
        });
      } catch (e) {
        await context.sendActivity("Couldn't generate slide (pptx).");
      }

      return { status: 200 };
    };
  }
}
