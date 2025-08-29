# Working Agreement

**Project**: Briefing bot + PowerShell modules
**Languages**: PowerShell 7.x, TypeScript/React (Vite). No C++/C# syntax.

## PowerShell
- Target PowerShell 7+; include `#requires -Version 7.0`.
- Avoid here-strings unless explicitly required; prefer arrays + `-join`.
- Normalize with `.ToLowerInvariant()`; coerce with `@(...)` then use `.Count -gt 0`.
- Avoid `Measure-Object | Select -ExpandProperty Count` for truthiness.
- Add Pester tests for recurring bug patterns.

## TypeScript/React
- Vite + React 18 + strict TS; Adaptive Cards 1.5; { action, topicId } payloads.
- Idempotency on queue enqueue; no secrets in client.

## Guardrails
- `npm run check` runs: Precheck (PS), Pester, ESLint.