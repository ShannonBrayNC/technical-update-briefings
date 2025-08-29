## Summary

- Resolves: #
- Related ADR(s): #

## Checklist
- [ ] CI passes (npm run validate, npm run check)
- [ ] No runtime deps at repo root (dependencies {} is empty)
- [ ] PowerShell: no here-strings; avoid Measure-Object | Select -ExpandProperty Count
- [ ] Tab uses VITE_API_BASE (no hardcoded URLs)
- [ ] Secrets are not committed (no .env, .pfx, .pem, .key)
- [ ] If this introduces a design decision, opened or updated an ADR (docs/ADR)
- [ ] Screenshots or logs for key behavior (optional)

## Test Plan

## Notes for reviewers
