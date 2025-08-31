# ADR 0013: Parsers as Modules
Date: 2025-08-31
Status: Accepted
Owners: Team

## Context
Parser logic embedded in `generate_deck.py` created churn and complicated testing.

## Decision
Parsers live in dedicated modules: `parsers/roadmap_html.py` and `parsers/message_center.py`.

## Consequences
- Positive: Reduces churn in `generate_deck.py` and isolates BeautifulSoup logic.
- Negative / Risks: Requires maintaining clear module boundaries.
- Migration/rollout plan: Move parsing functions into their own modules and import them in the builder.

## Options considered
- Option A (chosen): Separate parser modules.
- Option B: Keep parsers embedded in `generate_deck.py`.

## Appendix
- n/a
