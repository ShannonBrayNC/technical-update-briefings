[CmdletBinding()]
param([string]$RepoRoot = ".")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = (Resolve-Path $RepoRoot).Path
$adrDir = Join-Path $repo "docs\ADR"
$indexPath = Join-Path $adrDir "README.md"
if (-not (Test-Path $adrDir)) { throw "ADR folder not found: $adrDir" }

$items = Get-ChildItem $adrDir -File -Filter "000*.md" | Sort-Object Name
$rows = foreach ($f in $items) {
  $firstLine = (Get-Content -LiteralPath $f.FullName -First 1 -Encoding UTF8) -as [string]
  # Expect "# ADR 0001: Title..."
  if ($firstLine -match '^#\s*(.+)$') { $title = $Matches[1] } else { $title = $f.BaseName }
  "- [$title]($($f.Name))"
}

$body = @"
# Architecture Decision Records (ADRs)

This folder tracks design decisions for the Briefings project.

## Index
$($rows -join "`r`n")
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath, $body, $utf8NoBom)
Write-Host "Wrote: $indexPath"
