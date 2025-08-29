Status: Accepted
# 0006 - Bot auth (certificate) and proactive 1:1 via conversation references

- **Date:** 2025-08-29
- **Status:** Accepted
- **Context:** We need to proactively DM the current user an Adaptive Card when they click Ask more.
- **Decision:**
  - Use Bot Framework CloudAdapter with certificate credentials: MicrosoftAppId, MicrosoftAppTenantId, CertificateThumbprint, CertificatePrivateKey.
  - Capture and persist conversation references when the user messages the bot once. Use continueConversation for proactive sends.
- **Consequences:**
  - Reliable proactive 1:1 messaging consistent with Teams constraints.
  - Requires a one-time hello from users to seed references; needs persistence in production.
- **Alternatives considered:** Password/secret auth (less secure), attempting to open 1:1 without prior reference (unreliable or policy-sensitive).
