# ADR 0015: Inches Wrapper for Layout
Date: 2025-08-31
Status: Accepted
Owners: Team

## Context
Geometry helpers occasionally received `None` or mixed unit types, leading to runtime errors and confusing math.

## Decision
Provide an `_inches(x: float | None) -> float` wrapper and `emu_to_in()` utility. Slide functions never accept `None` for width/height; defaults handled before calls.

## Consequences
- Positive: Centralizes unit coercion and guards against invalid values.
- Negative / Risks: Helper misuse could reintroduce `None` values.
- Migration/rollout plan: Route all geometry values through `_inches` and related helpers.

## Options considered
- Option A (chosen): Wrapper and EMU conversion utilities.
- Option B: Allow direct `None` handling in slide functions.

## Appendix
- n/a
