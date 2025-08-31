# ADR 0019: ESLint Flat Config
Date: 2025-08-31
Status: Accepted
Owners: Team

## Context
ESLint 9+ dropped support for legacy configuration files, causing lint errors without a flat config.

## Decision
Adopt `eslint.config.js` and migrate from `.eslintrc.*` files.

## Consequences
- Positive: Linting works with modern ESLint; workspace globs and ignores are centralized.
- Negative / Risks: Requires updating tooling and editor integrations.
- Migration/rollout plan: Replace old config files and update npm scripts to use the flat config.

## Options considered
- Option A (chosen): Use `eslint.config.js` flat configuration.
- Option B: Maintain legacy `.eslintrc` files.

## Appendix
- n/a
