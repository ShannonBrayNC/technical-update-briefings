# ADR 0020: Ruff Config and Usage
Date: 2025-08-31
Status: Accepted
Owners: Team

## Context
An invalid `fix = true` key in `.ruff.toml` caused errors when running lint tasks.

## Decision
Adopt a compliant `.ruff.toml` and run formatting and fixes via the venv Python executable.

## Consequences
- Positive: Keeps configuration valid and avoids runtime errors.
- Negative / Risks: Requires developers to use the venv-managed ruff commands.
- Migration/rollout plan: Update `.ruff.toml` and document the correct CLI usage.

## Options considered
- Option A (chosen): Compliant config with CLI-based fixes.
- Option B: Keep invalid keys and rely on default settings.

## Appendix
- n/a
