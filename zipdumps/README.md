# Bot Explain Flow (Teams + Adaptive Cards v1.5)

This starter wires an **Action.Submit** payload `{ action: "explain", topicId }` to a real handler that:
1. Locates the update (from cache or by refetching sources)
2. Generates a concise explanation (rules-based summary)
3. Replies with text AND an Adaptive Card summary
4. Optionally generates a PPTX with one slide and returns it as an attachment

## Environment
Copy `.env.sample` from the starter pack and also set bot creds:

```
MICROSOFT_APP_ID=
MICROSOFT_APP_PASSWORD=        # or use certificate vars below
MICROSOFT_APP_TENANT_ID=
MICROSOFT_APP_TYPE=MultiTenant
MICROSOFT_APP_CERTIFICATE_PATH=
MICROSOFT_APP_CERTIFICATE_PASSWORD=
```

## Run (dev)
```
npm i
npm run dev:bot
```

Bot endpoint: `/api/messages`
