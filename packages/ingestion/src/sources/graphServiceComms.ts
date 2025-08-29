import { Client } from "@microsoft/microsoft-graph-client";
import { ClientCertificateCredential } from "@azure/identity";
import "isomorphic-fetch";
import type { UpdateItem, FetchOptions } from "../domain";
import fs from "node:fs";

function getGraphClient() {
  const tenantId = process.env.TENANT_ID!;
  const clientId = process.env.AZURE_CLIENT_ID!;
  const pemPath = process.env.AZURE_CERT_PEM_PATH;
  const pfxPath = process.env.AZURE_CERT_PFX_PATH;
  const pfxPassword = process.env.AZURE_CERT_PFX_PASSWORD;

  if (!tenantId || !clientId) throw new Error("TENANT_ID and AZURE_CLIENT_ID are required");
  if (!pemPath && !pfxPath) throw new Error("Provide AZURE_CERT_PEM_PATH or AZURE_CERT_PFX_PATH");

  const credential = new ClientCertificateCredential(
    tenantId,
    clientId,
    pemPath
      ? { certificatePath: pemPath }
      : { certificatePath: pfxPath!, certificatePassword: pfxPassword }
  );

  return Client.init({
    authProvider: async (done) => {
      try {
        const token = await credential.getToken("https://graph.microsoft.com/.default");
        done(null, token?.token ?? undefined);
      } catch (err) {
        done(err as any, undefined);
      }
    },
  });
}

export async function fetchGraphMessages(opts: FetchOptions = {}): Promise<UpdateItem[]> {
  const client = getGraphClient();
  const filter = opts.since ? `&$filter=lastModifiedDateTime ge ${opts.since}` : "";
  const url =
    `/admin/serviceAnnouncement/messages?$top=${opts.limit ?? 50}` +
    "&$select=id,title,category,services,publishDateTime,lastModifiedDateTime,severity,actionType,viewPoint" +
    filter;
  const res = await client.api(url).get();
  const items: any[] = res.value ?? [];

  return items.map((m) => {
    const product = Array.isArray(m.services) && m.services.length ? m.services[0] : undefined;
    const links = [] as { label: string; url: string }[];
    if (m.viewPoint?.link) links.push({ label: "Message center", url: m.viewPoint.link });

    const impact = String(m.severity || m.impact || "").toLowerCase();

    const it: UpdateItem = {
      id: m.id,
      source: "graph-message-center",
      title: m.title,
      summary: m.summary || m.description || undefined,
      product,
      category: m.category,
      impact,
      actionRequired: m.actionType,
      audience: m.audience || "admins",
      rolloutPhase: m.classification || undefined,
      status: undefined,
      tags: m.tags || [],
      links,
      publishedAt: m.publishDateTime,
      lastUpdatedAt: m.lastModifiedDateTime,
    };
    return it;
  });
}
