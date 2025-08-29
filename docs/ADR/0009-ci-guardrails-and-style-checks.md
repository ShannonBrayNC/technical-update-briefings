Status: Accepted
# 0009 - CI guardrails (validator, ESLint, Pester) and style rules

- **Date:** 2025-08-29
- **Status:** Accepted
- **Context:** We keep hitting structural drift and PowerShell quirks (here-strings).
- **Decision:**
  - Root workspace validator: packages/* must exist, no runtime deps at root.
  - ESLint (TS/React) with repo and per-package configs.
  - Pester style tests (no here-strings; avoid Measure-Object | Select -ExpandProperty Count).
- **Consequences:** Early failure on PRs; consistent codebase.
- **Alternatives considered:** Manual review only (rejected).
