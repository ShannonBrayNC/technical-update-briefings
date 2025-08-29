import 'dotenv/config';
import express from 'express';
import bodyParser from 'body-parser';
import { CloudAdapter, ConfigurationBotFrameworkAuthentication, ConfigurationServiceClientCredentialFactory } from 'botbuilder';
import { BriefingBot, ConversationRegistry } from './bot';
import { Dispatcher } from './worker';
const app = express();
app.use(bodyParser.json({ limit: '1mb' }));
const credentialsFactory = new ConfigurationServiceClientCredentialFactory({
  MicrosoftAppType: process.env.MicrosoftAppType,
  MicrosoftAppId: process.env.MicrosoftAppId,
  MicrosoftAppTenantId: process.env.MicrosoftAppTenantId,
  CertificateThumbprint: process.env.CertificateThumbprint,
  CertificatePrivateKey: process.env.CertificatePrivateKey,
});
const botFrameworkAuth = new ConfigurationBotFrameworkAuthentication({}, credentialsFactory);
const adapter = new CloudAdapter(botFrameworkAuth);
const registry = new ConversationRegistry();
const bot = new BriefingBot(undefined as any, registry);
const dispatcher = new Dispatcher(adapter, registry);
app.post('/api/messages', async (req, res) => { await adapter.process(req, res, (context) => bot.run(context)); });
app.post('/api/ask', async (req, res) => {
  const { meetingId, userAadObjectId, topicId, card, idempotencyKey } = req.body || {};
  const headerKey = (req.header('Idempotency-Key') as string) || idempotencyKey;
  if (!topicId || !card) return res.status(400).json({ error: 'topicId and card required' });
  await dispatcher.enqueue({ meetingId, userAadObjectId, topicId, card, idempotencyKey: headerKey });
  res.status(202).json({ ok: true, queued: true });
});
app.get('/health', (_req, res) => res.json({ ok: true }));
const port = process.env.PORT || 3978;
app.listen(port, async () => { await dispatcher.start(); console.log([server] listening on :); });