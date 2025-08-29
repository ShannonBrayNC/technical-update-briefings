# ADR 0012 : Defensive HTML Parsing & BeautifulSoup Typing
Date: 2025-08-29
Status: Accepted

## Context
Summarize the problem and constraints briefly.

## Decision
State the decision in one or two sentences.

## Consequences
Note positive/negative tradeoffs and follow-ups.

## Notes
- Treat unknown nodes defensively; never assume Tag vs. NavigableString.
- Use safe helpers (e.g., safe_find, safe_text) to avoid None/AttributeValueList issues.
- Keep types simple: accept Tag|None, return str for text helpers.
