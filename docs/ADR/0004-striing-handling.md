Architecture Decision Records”

# ADR: No here-strings in PS
Date: 2025-08-28
Owners: Shannon Bray, EchoMediaAI Team
Context: Here-strings made quoting/escaping fragile and broke CSV parsers.
Decision: Use single quotes or @"..."@ only when templating requires it.
Status: Accepted
Consequences: Add linter/test to fail on here-strings.
