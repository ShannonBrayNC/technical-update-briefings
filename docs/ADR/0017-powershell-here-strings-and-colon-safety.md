# ADR 0017: PowerShell Here-Strings and Colon Safety
Date: 2025-08-31
Status: Accepted
Owners: Team

## Context
Here-strings and variable names with trailing colons (`$var:`) caused parsing bugs in automation scripts.

## Decision
Avoid here-strings; write files line-by-line and avoid `:$` after variable names.

## Consequences
- Positive: Prevents brittle parsing and quoting bugs.
- Negative / Risks: Slightly more verbose file-writing code.
- Migration/rollout plan: Replace existing here-strings with `[IO.File]::WriteAllLines()` and explicit arrays.

## Options considered
- Option A (chosen): Avoid here-strings and colon-suffix variables.
- Option B: Continue using here-strings and `$var:` patterns.

## Appendix
- n/a
