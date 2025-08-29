# ADR 0018 : Graceful Handling When No Items Are Parsed
Date: 2025-08-29
Status: Accepted

## Context
Summarize the problem and constraints briefly.

## Decision
State the decision in one or two sentences.

## Consequences
Note positive/negative tradeoffs and follow-ups.

## Notes
- If parsing yields zero items, still emit a deck with a friendly 'No Updates' slide.
- Exit 0; treat as non-fatal data condition.
