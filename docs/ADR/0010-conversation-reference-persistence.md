# 0010 - Conversation reference persistence (beyond in-memory)

- **Date:** 2025-08-29
- **Status:** Proposed
- **Context:** In-memory references are lost on restart or scale-out.
- **Decision (proposed):**
  - Pluggable store interface (getRef/saveRef/countRefs).
  - Providers: Azure Table or Redis; include JSON-file store for single-instance demos.
- **Consequences:** Survives restarts; enables multi-instance.
- **Alternatives considered:** Memory/disk-only (rejected for production).
