# ADR 0014: BeautifulSoup Tag Typing
Date: 2025-08-31
Status: Accepted
Owners: Team

## Context
Using private `BsTag` types and ambiguous `PageElement` annotations caused Pylance and Pyright warnings.

## Decision
Use `from bs4.element import Tag, NavigableString`; avoid private types like `BsTag`.

## Consequences
- Positive: Stable typing with fewer editor false positives.
- Negative / Risks: Requires updating imports across helpers.
- Migration/rollout plan: Replace existing private type usages with public types.

## Options considered
- Option A (chosen): Tag/NavigableString types.
- Option B: Continue using private BeautifulSoup types.

## Appendix
- n/a
