Param(
  [string]$OutDir = "."
)

function Write-Lines {
  param([string]$Path,[string[]]$Lines)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Lines | Out-File -FilePath $Path -Encoding utf8 -Force
}

$root = Resolve-Path $OutDir
$files = @{}

# -------------------- ADRs (ASCII only, no apostrophes) --------------------
$files['docs/ADR/0005-tab-api-base-routing.md'] = @(
'# 0005 - Tab API base via VITE_API_BASE with local fallback',
'',
'- **Date:** 2025-08-29',
'- **Status:** Accepted',
'- **Context:** The Tab must call the Bot both locally and on a remote host (ngrok/App Service) without code changes.',
'- **Decision:**',
'  - Introduce VITE_API_BASE env. If set, prefix all API calls with it; otherwise default to same-origin (/api/...) using Vite proxy.',
'  - Show a small API status (host|local) badge in the header for operator visibility.',
'- **Consequences:**',
'  - Zero-code switch between local, tunnel, and Azure.',
'  - Clear demo status in UI.',
'- **Alternatives considered:** Hardcoded base URLs per build profile; manual proxy toggles. Rejected for fragility and higher maintenance.'
)

$files['docs/ADR/0006-bot-auth-and-proactive-messaging.md'] = @(
'# 0006 - Bot auth (certificate) and proactive 1:1 via conversation references',
'',
'- **Date:** 2025-08-29',
'- **Status:** Accepted',
'- **Context:** We need to proactively DM the current user an Adaptive Card when they click Ask more.',
'- **Decision:**',
'  - Use Bot Framework CloudAdapter with certificate credentials: MicrosoftAppId, MicrosoftAppTenantId, CertificateThumbprint, CertificatePrivateKey.',
'  - Capture and persist conversation references when the user messages the bot once. Use continueConversation for proactive sends.',
'- **Consequences:**',
'  - Reliable proactive 1:1 messaging consistent with Teams constraints.',
'  - Requires a one-time hello from users to seed references; needs persistence in production.',
'- **Alternatives considered:** Password/secret auth (less secure), attempting to open 1:1 without prior reference (unreliable or policy-sensitive).'
)

$files['docs/ADR/0007-cors-and-proxy-strategy.md'] = @(
'# 0007 - CORS and proxy strategy',
'',
'- **Date:** 2025-08-29',
'- **Status:** Accepted',
'- **Context:** Tab is served from localhost:5173 during dev; Bot might be remote (ngrok/Azure).',
'- **Decision:**',
'  - In dev, use Vite proxy for same-origin calls when VITE_API_BASE is empty.',
'  - When calling a remote bot, enable CORS on the bot with ALLOW_ORIGINS (for example, http://localhost:5173, https://teams.microsoft.com).',
'- **Consequences:**',
'  - No CORS issues locally; controlled origins remotely.',
'- **Alternatives considered:** Disabling CORS (rejected).'
)

$files['docs/ADR/0008-hosting-and-stable-public-endpoint.md'] = @(
'# 0008 - Host bot on Azure App Service for stable public URL',
'',
'- **Date:** 2025-08-29',
'- **Status:** Accepted',
'- **Context:** Stakeholders require a stable URL (>= 1 year). Dev tunnels rotate.',
'- **Decision:**',
'  - Deploy the Bot to Azure App Service (Linux, Node 20) with HTTPS-only.',
'  - Use App Settings for environment; optionally Key Vault for private key.',
'  - Teams Messaging endpoint: https://<app>.azurewebsites.net/api/messages.',
'- **Consequences:**',
'  - Stable public endpoint; managed TLS; easy CI/CD.',
'- **Alternatives considered:** Long-lived tunnels (paid), container on AKS (overkill for current scope).'
)

$files['docs/ADR/0009-ci-guardrails-and-style-checks.md'] = @(
'# 0009 - CI guardrails (validator, ESLint, Pester) and style rules',
'',
'- **Date:** 2025-08-29',
'- **Status:** Accepted',
'- **Context:** We keep hitting structural drift and PowerShell quirks (here-strings).',
'- **Decision:**',
'  - Root workspace validator: packages/* must exist, no runtime deps at root.',
'  - ESLint (TS/React) with repo and per-package configs.',
'  - Pester style tests (no here-strings; avoid Measure-Object | Select -ExpandProperty Count).',
'- **Consequences:** Early failure on PRs; consistent codebase.',
'- **Alternatives considered:** Manual review only (rejected).'
)

$files['docs/ADR/0010-conversation-reference-persistence.md'] = @(
'# 0010 - Conversation reference persistence (beyond in-memory)',
'',
'- **Date:** 2025-08-29',
'- **Status:** Proposed',
'- **Context:** In-memory references are lost on restart or scale-out.',
'- **Decision (proposed):**',
'  - Pluggable store interface (getRef/saveRef/countRefs).',
'  - Providers: Azure Table or Redis; include JSON-file store for single-instance demos.',
'- **Consequences:** Survives restarts; enables multi-instance.',
'- **Alternatives considered:** Memory/disk-only (rejected for production).'
)

$files['docs/ADR/0011-secrets-and-cert-management.md'] = @(
'# 0011 - Secrets and certificate management (Key Vault plus App Settings)',
'',
'- **Date:** 2025-08-29',
'- **Status:** Proposed',
'- **Context:** Certificate private keys and app IDs should not live in source control.',
'- **Decision (proposed):**',
'  - Use Azure Key Vault for CertificatePrivateKey via Key Vault references.',
'  - Keep non-secret toggles (for example, ALLOW_ORIGINS) in App Settings.',
'  - Maintain a .env.sample for local dev placeholders.',
'- **Consequences:** Reduced leak risk; centralized rotation.',
'- **Alternatives considered:** .env only (rejected for production).'
)

# -------------------- .github templates (escape $ with backtick) --------------------
$files['.github/CODEOWNERS'] = @(
'# Default owners',
'* @ShannonBrayNC @ShannonBrayPT',
'',
'# Packages',
'/packages/tab/    @ShannonBrayNC @ShannonBrayPT',
'/packages/bot/    @ShannonBrayNC @ShannonBrayPT',
'/packages/shared/ @ShannonBrayNC @ShannonBrayPT',
'',
'# Scripts & CI',
'/build/           @ShannonBrayNC @ShannonBrayPT',
'/tools/           @ShannonBrayNC @ShannonBrayPT',
'/.github/         @ShannonBrayNC @ShannonBrayPT',
'/docs/ADR/        @ShannonBrayNC @ShannonBrayPT'
)

$files['.github/release-drafter.yml'] = @(
'name-template: "v`$RESOLVED_VERSION"',
'tag-template: "`$RESOLVED_VERSION"',
'',
'categories:',
'  - title: "🚀 Features"',
'    labels: [enhancement, feature]',
'  - title: "🐛 Fixes"',
'    labels: [bug, fix]',
'  - title: "🧰 Maintenance"',
'    labels: [chore, refactor]',
'  - title: "📚 Docs"',
'    labels: [docs]',
'  - title: "🧪 CI"',
'    labels: [ci]',
'  - title: "🔐 Security"',
'    labels: [security]',
'',
'change-template: "- `$TITLE (#`$NUMBER) by @`$AUTHOR"',
'change-title-escapes: "<>&"',
'',
'version-resolver:',
'  major:',
'    labels: [major]',
'  minor:',
'    labels: [minor, enhancement, feature]',
'  patch:',
'    labels: [patch, bug, fix, chore, docs, ci, security]',
'  default: patch',
'',
'exclude-labels:',
'  - skip-changelog',
'',
'template: |',
'  ## Changes',
'  `$CHANGES',
'',
'  ---',
'  _This release was drafted automatically. Use labels to sort entries and add `skip-changelog` to exclude PRs._'
)

$files['.github/workflows/release-drafter.yml'] = @(
'name: Release Drafter',
'on:',
'  push:',
'    branches: [ main ]',
'  pull_request:',
'    types: [opened, edited, reopened, labeled, unlabeled, closed]',
'',
'permissions:',
'  contents: write',
'  pull-requests: read',
'',
'jobs:',
'  update_release_draft:',
'    runs-on: ubuntu-latest',
'    steps:',
'      - uses: release-drafter/release-drafter@v6',
'        with:',
'          config-name: release-drafter.yml',
'        env:',
'          GITHUB_TOKEN: `$`{{ secrets.GITHUB_TOKEN }}'
)

$files['.github/PULL_REQUEST_TEMPLATE.md'] = @(
'## Summary',
'',
'- Resolves: #',
'- Related ADR(s): #',
'',
'## Checklist',
'- [ ] CI passes (npm run validate, npm run check)',
'- [ ] No runtime deps at repo root (dependencies {} is empty)',
'- [ ] PowerShell: no here-strings; avoid Measure-Object | Select -ExpandProperty Count',
'- [ ] Tab uses VITE_API_BASE (no hardcoded URLs)',
'- [ ] Secrets are not committed (no .env, .pfx, .pem, .key)',
'- [ ] If this introduces a design decision, opened or updated an ADR (docs/ADR)',
'- [ ] Screenshots or logs for key behavior (optional)',
'',
'## Test Plan',
'',
'## Notes for reviewers'
)

$files['.github/ISSUE_TEMPLATE/bug_report.yml'] = @(
'name: Bug report',
'description: Something broke; help me reproduce and fix it',
'labels: [bug]',
'body:',
'  - type: textarea',
'    id: what-happened',
'    attributes:',
'      label: What happened?',
'      description: Describe the bug and expected behavior.',
'      placeholder: Expected X, but got Y…',
'    validations: { required: true }',
'  - type: input',
'    id: repro',
'    attributes:',
'      label: Minimal repro steps',
'      placeholder: 1) npm -w @suite/tab run client:dev …',
'  - type: textarea',
'    id: logs',
'    attributes:',
'      label: Logs / console output',
'      render: shell',
'  - type: input',
'    id: env',
"    attributes:",
'      label: Environment',
'      placeholder: Windows/PS7, Node v20.x, Pester 5.x, Vite 5.x'
)

$files['.github/ISSUE_TEMPLATE/feature_request.yml'] = @(
'name: Feature request',
'description: Propose an enhancement or capability',
'labels: [enhancement]',
'body:',
'  - type: textarea',
'    id: problem',
'    attributes:',
'      label: Problem / Motivation',
'      placeholder: What user need are we solving?',
'    validations: { required: true }',
'  - type: textarea',
'    id: proposal',
'    attributes:',
'      label: Proposed solution',
'      placeholder: What would you like the bot or tab to do?',
'  - type: checkboxes',
'    id: impact',
'    attributes:',
'      label: Areas impacted',
'      options:',
'        - label: Teams Bot (server)',
'        - label: Tab (client)',
'        - label: Shared types or utilities',
'        - label: Docs or ADRs'
)

$files['.github/ISSUE_TEMPLATE/adr_proposal.yml'] = @(
'name: ADR proposal',
'description: Record a design decision (Architecture Decision Record)',
'labels: [ADR]',
'body:',
'  - type: input',
'    id: id',
'    attributes:',
'      label: Proposed ADR number',
'      placeholder: 0012',
'    validations: { required: true }',
'  - type: input',
'    id: title',
'    attributes:',
'      label: Title',
'      placeholder: For example, Conversation reference persistence via Azure Table',
'    validations: { required: true }',
'  - type: textarea',
'    id: context',
'    attributes:',
'      label: Context',
'      placeholder: Why is this decision needed now?',
'    validations: { required: true }',
'  - type: textarea',
'    id: decision',
'    attributes:',
'      label: Decision',
'      placeholder: The choice we are making and how we will implement it.',
'    validations: { required: true }',
'  - type: textarea',
'    id: consequences',
'    attributes:',
'      label: Consequences',
'      placeholder: Trade-offs, risks, operational considerations.',
'  - type: markdown',
'    attributes:',
'      value: |',
'        Next steps',
'        - Open a PR that adds docs/ADR/<number>-<kebab-title>.md',
'        - Reference this issue in the PR description'
)

$files['.github/ISSUE_TEMPLATE/config.yml'] = @(
'blank_issues_enabled: false',
'contact_links:',
'  - name: Propose an ADR',
'    url: https://github.com/ShannonBrayNC/technical-update-briefings/issues/new?template=adr_proposal.yml',
'    about: Use the ADR template to capture design decisions'
)

# -------------------- Write and zip --------------------
$written = @()
foreach ($rel in $files.Keys) {
  $path = Join-Path $root $rel
  Write-Lines -Path $path -Lines $files[$rel]
  $written += $path
}

$zip = Join-Path $root 'technical-update-briefings-adr-and-github.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $written -DestinationPath $zip -Force

Write-Host "Wrote $($written.Count) files and zipped to: $zip"
