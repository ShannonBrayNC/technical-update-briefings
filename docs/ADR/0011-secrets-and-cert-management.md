# 0011 - Secrets and certificate management (Key Vault plus App Settings)

- **Date:** 2025-08-29
- **Status:** Proposed
- **Context:** Certificate private keys and app IDs should not live in source control.
- **Decision (proposed):**
  - Use Azure Key Vault for CertificatePrivateKey via Key Vault references.
  - Keep non-secret toggles (for example, ALLOW_ORIGINS) in App Settings.
  - Maintain a .env.sample for local dev placeholders.
- **Consequences:** Reduced leak risk; centralized rotation.
- **Alternatives considered:** .env only (rejected for production).
