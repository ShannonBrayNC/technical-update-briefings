import express from "express";
import bodyParser from "body-parser";
import "dotenv/config";
import { ActivityTypes, CardFactory, TurnContext } from "botbuilder";
import { adapter } from "./adapter";
import { BriefingBot } from "./bot";
import { getRef } from "./store";

const app = express();
app.use(bodyParser.json());

const bot = new BriefingBot();

// 1) Bot Framework endpoint for Teams
app.post("/api/messages", (req, res) => {
  adapter.process(req, res, (context) => bot.run(context));
});

// 2) Health
app.get("/healthz", (_req, res) => res.status(200).send("ok"));

// 3) Proactive send from the tab ("Ask more")
app.post("/api/ask", async (req, res) => {
  const { topicId, card, userAadObjectId } = req.body ?? {};
  console.log("[api/ask]", { topicId, hasCard: !!card, userAadObjectId });

  if (!card || !userAadObjectId) {
    // We can also accept meetingId later; for now require user id for 1:1
    return res.status(400).json({ ok: false, error: "card and userAadObjectId required" });
  }

  const ref = getRef(String(userAadObjectId));
  if (!ref) {
    // The user hasn’t messaged the bot yet; we can’t proactively open a 1:1 reliably without a saved ref.
    console.log("[api/ask] no conversation ref yet for user; ask them to send 'hi' to the bot once.");
    return res.status(202).json({
      ok: true,
      queued: true,
      message: "No conversation reference for this user yet. Ask the user to send a message to the bot once."
    });
  }

  try {
    await adapter.continueConversationAsync(process.env.MicrosoftAppId!, ref, async (turn) => {
      // Attach Adaptive Card
      const attachment = CardFactory.adaptiveCard(card);
      await turn.sendActivity({ type: ActivityTypes.Message, attachments: [attachment] });
    });
    return res.status(202).json({ ok: true, queued: false });
  } catch (err) {
    console.error("[api/ask] proactive send failed:", err);
    return res.status(500).json({ ok: false, error: "send_failed" });
  }
});

const PORT = Number(process.env.PORT || 3978);
app.listen(PORT, () => {
  console.log(`server listening on http://localhost:${PORT}`);
  console.log("→ POST /api/messages (Teams)");
  console.log("→ POST /api/ask       (proactive 1:1 send)");
});
