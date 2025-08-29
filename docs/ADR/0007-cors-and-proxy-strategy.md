Status: Accepted
# 0007 - CORS and proxy strategy

- **Date:** 2025-08-29
- **Status:** Accepted
- **Context:** Tab is served from localhost:5173 during dev; Bot might be remote (ngrok/Azure).
- **Decision:**
  - In dev, use Vite proxy for same-origin calls when VITE_API_BASE is empty.
  - When calling a remote bot, enable CORS on the bot with ALLOW_ORIGINS (for example, http://localhost:5173, https://teams.microsoft.com).
- **Consequences:**
  - No CORS issues locally; controlled origins remotely.
- **Alternatives considered:** Disabling CORS (rejected).
