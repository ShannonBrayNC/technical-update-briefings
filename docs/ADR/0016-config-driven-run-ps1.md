# ADR 0016: Config-Driven run.ps1
Date: 2025-08-31
Status: Accepted
Owners: Team

## Context
Multiple CLI flags for `run.ps1` led to brittle automation and inconsistent invocation.

## Decision
`run.ps1` reads a JSON config for all inputs and paths instead of numerous flags.

## Consequences
- Positive: Simpler CLI and versionable configuration.
- Negative / Risks: Requires updating config file for new parameters.
- Migration/rollout plan: Add new parameters to JSON and keep PowerShell deserializing into a single object.

## Options considered
- Option A (chosen): JSON config-driven invocation.
- Option B: Maintain many individual CLI flags.

## Appendix
- n/a
