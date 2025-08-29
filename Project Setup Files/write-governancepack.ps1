[CmdletBinding()]
param(
  [string]$RepoRoot,
  [switch]$Force,
  [switch]$DryRun  # explicit; no alias magic
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$VerbosePreference = 'Continue'

function Write-Step([string]$msg) { Write-Host "[*] $msg" }

# --- Resolve repo root ---
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
try {
  $RepoRoot = (Resolve-Path $RepoRoot).Path
} catch {
  throw "RepoRoot not found: $RepoRoot"
}
Write-Verbose "PS $($PSVersionTable.PSVersion)"
Write-Verbose "Resolved RepoRoot => $RepoRoot"

# --- helper that ALWAYS prints what it’s doing ---
function New-TextFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Content,
    [switch]$Force,
    [switch]$DryRun
  )
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path $dir)) {
    if ($DryRun) { Write-Host "[DRYRUN] mkdir $dir" }
    else { New-Item -ItemType Directory -Path $dir -Force | Out-Null; Write-Step "mkdir $dir" }
  }
  if ((Test-Path $Path) -and -not $Force) {
    Write-Step "skip (exists) $Path"
    return
  }
  if ($DryRun) {
    Write-Host "[DRYRUN] write $Path"
    return
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
  Write-Step "write $Path"
}

$today = Get-Date -Format "yyyy-MM-dd"

# ---------- minimal contents (trimmed to keep this focused) ----------
$ADR1 = @"
# ADR 0001: Python 3.12 Runtime & Pinned Dependencies
Date: $today
Status: Proposed
"@
$ADR2 = @"
# ADR 0002: Title Fit & Overflow Policy
Date: $today
Status: Proposed
"@
$ADR3 = @"
# ADR 0003: Slide Geometry & Right Rail
Date: $today
Status: Proposed
"@
$WorkingAgreement = @"
# WorkingAgreement
(see ADRs 0001–0003)
"@
$Contrib = @"
# Contributing
Use tools/ppt_builder/.venv; lint & import smoke test before PRs.
"@
$PRTmpl = @"
# Pull Request
- ADRs referenced?
- Lint + import test passed?
"@
$PyCI = @"
name: python-ppt-builder
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: tools/ppt_builder } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: python -m pip install --upgrade pip
      - run: pip install -r requirements.txt
      - run: python scripts/import_smoketest.py
"@
$Req = @"
python-pptx==1.0.2
beautifulsoup4>=4.12
lxml>=4.9
Pillow>=10.0
XlsxWriter>=3.1
ruff>=0.5
"@
$Smoke = @"
import sys
import pptx, bs4, lxml
from PIL import Image
import xlsxwriter
print('IMPORT_OK')
"@
$Readme = @"
# Governance Pack
This repo includes ADRs, WorkingAgreement, CONTRIBUTING, PR template, and Python CI.
"@

# ---------- Targets ----------
$targets = @(
  @{ Path = Join-Path $RepoRoot "docs\ADR\0001-python-runtime-and-deps.md";        Content = $ADR1  },
  @{ Path = Join-Path $RepoRoot "docs\ADR\0002-title-fit-policy.md";               Content = $ADR2  },
  @{ Path = Join-Path $RepoRoot "docs\ADR\0003-slide-rail-geometry.md";            Content = $ADR3  },
  @{ Path = Join-Path $RepoRoot "docs\WorkingAgreement.md";                         Content = $WorkingAgreement },
  @{ Path = Join-Path $RepoRoot "CONTRIBUTING.md";                                  Content = $Contrib },
  @{ Path = Join-Path $RepoRoot ".github\PULL_REQUEST_TEMPLATE.md";                 Content = $PRTmpl },
  @{ Path = Join-Path $RepoRoot ".github\workflows\python-ci.yml";                  Content = $PyCI },
  @{ Path = Join-Path $RepoRoot "tools\ppt_builder\requirements.txt";               Content = $Req },
  @{ Path = Join-Path $RepoRoot "tools\ppt_builder\scripts\import_smoketest.py";    Content = $Smoke },
  @{ Path = Join-Path $RepoRoot "README-Governance-Pack.md";                        Content = $Readme }
)

Write-Step "Targets count: $($targets.Count)"
$targets | ForEach-Object { Write-Verbose ("PLAN -> " + $_.Path) }

foreach ($t in $targets) {
  New-TextFile -Path $t.Path -Content $t.Content -Force:$Force -DryRun:$DryRun
}

# Zip pack unless dry run
$buildDir = Join-Path $RepoRoot "build"
if ($DryRun) {
  Write-Host "[DRYRUN] zip -> $buildDir\governance_pack_<timestamp>.zip"
} else {
  if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir -Force | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $zip   = Join-Path $buildDir ("governance_pack_{0}.zip" -f $stamp)
  $toZip = @(
    "docs\ADR\0001-python-runtime-and-deps.md",
    "docs\ADR\0002-title-fit-policy.md",
    "docs\ADR\0003-slide-rail-geometry.md",
    "docs\WorkingAgreement.md",
    "CONTRIBUTING.md",
    ".github\PULL_REQUEST_TEMPLATE.md",
    ".github\workflows\python-ci.yml",
    "tools\ppt_builder\requirements.txt",
    "tools\ppt_builder\scripts\import_smoketest.py",
    "README-Governance-Pack.md"
  ) | ForEach-Object { Join-Path $RepoRoot $_ }
  if (Test-Path $zip) { Remove-Item $zip -Force }
  Compress-Archive -Path $toZip -DestinationPath $zip -Force
  Write-Step "Created zip: $zip"
}
