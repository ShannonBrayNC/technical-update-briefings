# ADR 0013 : Path Resolution Strategy for Inputs/Assets
Date: 2025-08-29
Status: Accepted

## Context
Summarize the problem and constraints briefly.

## Decision
State the decision in one or two sentences.

## Consequences
Note positive/negative tradeoffs and follow-ups.

## Notes
- Resolve relative to config file first, then repo root, then current dir.
- Normalize with [IO.Path]::GetFullPath; reject unreadable paths with actionable errors.
