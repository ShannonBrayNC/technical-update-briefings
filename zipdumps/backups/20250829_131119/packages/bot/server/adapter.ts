import { CloudAdapter, ConfigurationBotFrameworkAuthentication, ConfigurationServiceClientCredentialFactory, TurnContext } from "botbuilder";
import "dotenv/config";

const settings = {
  MicrosoftAppType: process.env.MicrosoftAppType,
  MicrosoftAppId: process.env.MicrosoftAppId,
  MicrosoftAppTenantId: process.env.MicrosoftAppTenantId,
  CertificateThumbprint: process.env.CertificateThumbprint,
  CertificatePrivateKey: process.env.CertificatePrivateKey,
};

const auth = new ConfigurationBotFrameworkAuthentication(settings as any);
export const adapter = new CloudAdapter(auth);

// Basic onTurn error handler
adapter.onTurnError = async (context: TurnContext, error: any) => {
  console.error("[onTurnError]", error);
  await context.sendActivity("Oops, something went wrong.");
};
