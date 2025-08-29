import "dotenv-safe/config";
import express from "express";
import { BotFrameworkAdapter, ConfigurationServiceClientCredentialFactory, createBotFrameworkAuthenticationFromConfiguration } from "botbuilder";
import { TeamsBriefingsBot } from "./teamsBot";

const credentialsFactory = new ConfigurationServiceClientCredentialFactory({
  MicrosoftAppId: process.env.MICROSOFT_APP_ID,
  MicrosoftAppPassword: process.env.MICROSOFT_APP_PASSWORD,
  MicrosoftAppType: process.env.MICROSOFT_APP_TYPE,
  MicrosoftAppTenantId: process.env.MICROSOFT_APP_TENANT_ID,
  MicrosoftAppCertificatePath: process.env.MICROSOFT_APP_CERTIFICATE_PATH,
  MicrosoftAppCertificatePassword: process.env.MICROSOFT_APP_CERTIFICATE_PASSWORD
});

const auth = createBotFrameworkAuthenticationFromConfiguration(null as any, credentialsFactory);
const adapter = new BotFrameworkAdapter({ authentication: auth });

const bot = new TeamsBriefingsBot();
const app = express();
app.post("/api/messages", (req, res) => {
  adapter.processActivity(req, res, async (context) => {
    await bot.run(context);
  });
});

const port = process.env.PORT || 3978;
app.listen(port, () => console.log(`Bot listening on http://localhost:${port}/api/messages`));
