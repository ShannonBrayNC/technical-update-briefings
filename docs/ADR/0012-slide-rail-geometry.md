# ADR 0012: Slide Rail Geometry
Date: 2025-08-31
Status: Accepted
Owners: Team

## Context
Mixing inches and EMU constants in slide geometry caused off-by-factor bugs and made placement math hard to read.

## Decision
Slide geometry parameters are inches-first. All EMU conversions happen inside helpers; slide code never uses raw EMU constants.

## Consequences
- Positive: Eliminates conversion mistakes; layout math is predictable.
- Negative / Risks: Requires consistent use of helpers across the codebase.
- Migration/rollout plan: Refactor existing calls to use inch-based helpers.

## Options considered
- Option A (chosen): Inches-first with helper conversion.
- Option B: Continue mixing EMU constants directly in slide code.

## Appendix
- n/a
