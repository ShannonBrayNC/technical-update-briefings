# ADR 0018: PowerShell Host Reserved
Date: 2025-08-31
Status: Accepted
Owners: Team

## Context
Using `$host` for storage or logic can crash scripts because it is a special shell object.

## Decision
Do not use `$host` for storage or logic. Use `$pshost` or differently named variables when needed.

## Consequences
- Positive: Avoids unexpected crashes tied to reserved variables.
- Negative / Risks: Requires refactoring code that previously relied on `$host`.
- Migration/rollout plan: Rename variables and update references away from `$host`.

## Options considered
- Option A (chosen): Avoid `$host` in scripts.
- Option B: Continue using `$host` for custom data.

## Appendix
- n/a
