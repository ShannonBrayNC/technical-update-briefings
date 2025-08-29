Status: Accepted
# 0005 - Tab API base via VITE_API_BASE with local fallback

- **Date:** 2025-08-29
- **Status:** Accepted
- **Context:** The Tab must call the Bot both locally and on a remote host (ngrok/App Service) without code changes.
- **Decision:**
  - Introduce VITE_API_BASE env. If set, prefix all API calls with it; otherwise default to same-origin (/api/...) using Vite proxy.
  - Show a small API status (host|local) badge in the header for operator visibility.
- **Consequences:**
  - Zero-code switch between local, tunnel, and Azure.
  - Clear demo status in UI.
- **Alternatives considered:** Hardcoded base URLs per build profile; manual proxy toggles. Rejected for fragility and higher maintenance.
