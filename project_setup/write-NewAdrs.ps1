param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [switch]$UpdateIndex = $true
)

$ErrorActionPreference = 'Stop'
$adrDir = Join-Path $RepoRoot 'docs\ADR'
$new = @(
  @{ Num = 12; Title = 'Defensive HTML Parsing & BS4 Typing'; Status='Accepted'; Body = @'
## Context
Pylance flagged frequent BS4 typing mismatches (`PageElement` vs `Tag`, `NavigableString`) causing fragile parsing and empty result sets.

## Decision
Centralize helpers: `text_of`, `first_tag`, `tags`, and `attr`. Only call BS4 APIs on `Tag`. Normalize attributes and text via `clean`.

## Consequences
Parsing is resilient to small DOM changes; Pylance noise is minimized; fewer runtime drops -> more items in deck.
'@ },
  @{ Num = 13; Title = 'Path Resolution Strategy for Inputs/Assets'; Status='Accepted'; Body = @'
## Context
Relative Windows paths varied by invocation folder; some runs produced “no items”.

## Decision
In `run.ps1`, resolve config paths against the **config file directory** first, then fall back to repo root, then absolute. Log resolved paths up front.

## Consequences
Stable runs from any working directory; fewer “missing input” surprises.
'@ },
  @{ Num = 14; Title = 'Remove PresentationLike Protocol; Use Concrete Types'; Status='Accepted'; Body = @'
## Context
`PresentationLike` protocol confused Pylance because python-pptx exposes properties with runtime descriptors.

## Decision
Use concrete `pptx.Presentation` for variables/returns; accept file path/stream only at creation time.

## Consequences
Cleaner types, no “Expected class but received (pptx:...) -> Presentation” diagnostics.
'@ },
  @{ Num = 15; Title = 'Stable Cover/Agenda Function Signatures'; Status='Accepted'; Body = @'
## Context
Slide helpers accreted params over time and diverged, breaking callers.

## Decision
Freeze signatures:
- `add_cover_slide(prs, month_str, cover_title, cover_dates, assets)`
- `add_agenda_slide(prs, month_str, assets)`
Assets is a dict of optional paths.

## Consequences
Call sites are simple and consistent; no more “parameter already assigned / missing param” errors.
'@ },
  @{ Num = 16; Title = 'Eliminate CLI Flags for Static Icons'; Status='Accepted'; Body = @'
## Context
Flags like `--admin/--user/--check` drifted and weren’t part of config JSON.

## Decision
Icons live under `tools/ppt_builder/assets` and are loaded from `assets` dict; no CLI flags.

## Consequences
Fewer unrecognized-argument failures; one source of truth (deck.config.json).
'@ },
  @{ Num = 17; Title = 'ESLint v9 Flat Config Migration'; Status='Accepted'; Body = @'
## Context
`npm run lint` failed due to `.eslintrc.*` deprecation.

## Decision
Adopt `eslint.config.cjs` at repo root and per-package overrides; update scripts.

## Consequences
Lint passes on CI; consistent local/dev behavior.
'@ },
  @{ Num = 18; Title = 'Graceful Empty-Data Slides'; Status='Accepted'; Body = @'
## Context
When parsers return zero items, the deck built but appeared “empty,” confusing users.

## Decision
Emit an “No Items Found” slide with the list of input files and a short checklist (path resolution, parser shape change, permissions).

## Consequences
Faster diagnosis; fewer head-scratching runs.
'@ }
)

New-Item -ItemType Directory -Force -Path $adrDir | Out-Null

foreach ($a in $new) {
  $n = '{0:0000}' -f $a.Num
  $file = Join-Path $adrDir "$n-$($a.Title -replace '\s+','-').ToLower().md"
  if (Test-Path $file) { Write-Verbose "Skip existing $file"; continue }
  $date = (Get-Date).ToString('yyyy-MM-dd')
  $content = @"
# ADR $n : $($a.Title)
Date: $date
Status: $($a.Status)

$a.Body
"@
  $content | Set-Content -NoNewline -Encoding UTF8 $file
  Write-Host "Wrote $file"
}

if ($UpdateIndex) {
  $index = Join-Path $adrDir 'README.md'
  $lines = @("# Architecture Decision Records", "", "## Index", "")
  Get-ChildItem $adrDir -Filter "*.md" | Where-Object { $_.Name -notmatch '^README\.md$' } |
    Sort-Object Name | ForEach-Object {
      $name = $_.BaseName
      $title = (Get-Content $_.FullName -First 1) -replace '^#\s*',''
      $rel = "./$($_.Name)"
      $lines += "- [$title]($rel)"
    }
  $lines -join "`r`n" | Set-Content -Encoding UTF8 $index
  Write-Host "Updated $index"
}
