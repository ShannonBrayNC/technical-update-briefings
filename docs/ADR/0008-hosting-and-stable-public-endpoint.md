Status: Accepted
# 0008 - Host bot on Azure App Service for stable public URL

- **Date:** 2025-08-29
- **Status:** Accepted
- **Context:** Stakeholders require a stable URL (>= 1 year). Dev tunnels rotate.
- **Decision:**
  - Deploy the Bot to Azure App Service (Linux, Node 20) with HTTPS-only.
  - Use App Settings for environment; optionally Key Vault for private key.
  - Teams Messaging endpoint: https://<app>.azurewebsites.net/api/messages.
- **Consequences:**
  - Stable public endpoint; managed TLS; easy CI/CD.
- **Alternatives considered:** Long-lived tunnels (paid), container on AKS (overkill for current scope).
