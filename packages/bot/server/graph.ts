import 'isomorphic-fetch';
import { Client } from '@microsoft/microsoft-graph-client';
import { ClientCertificateCredential } from '@azure/identity';
const tenantId = process.env.MicrosoftAppTenantId!;
const clientId = process.env.MicrosoftAppId!;
const certificate = process.env.CertificatePrivateKey!; // PEM
const credential = new ClientCertificateCredential(tenantId, clientId, { certificate, sendCertificateChain: true });
export function createGraphClient(){
  return Client.init({
    authProvider: {
      getAccessToken: async () => {
        const token = await credential.getToken('https://graph.microsoft.com/.default');
        return token?.token || '';
      }
    }
  });
}