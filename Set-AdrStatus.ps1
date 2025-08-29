[CmdletBinding()]
param(
  [string]$RepoRoot = ".",
  [ValidateSet("Proposed","Accepted","Rejected","Superseded")]
  [string]$Status = "Accepted",
  [string[]]$Owners = @(),
  [switch]$UpdateDate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = (Resolve-Path $RepoRoot).Path
$adrDir = Join-Path $repo "docs\ADR"
if (-not (Test-Path $adrDir)) { throw "ADR folder not found: $adrDir" }

$files = Get-ChildItem $adrDir -File -Filter "000*.md" | Sort-Object Name
if (-not $files) { Write-Host "No ADRs found in $adrDir"; return }

$today = Get-Date -Format "yyyy-MM-dd"
$ownersLine = ($Owners -and $Owners.Count) ? ("Owners: " + ($Owners -join ", ")) : $null

foreach ($f in $files) {
  $lines = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8

  # ---- Status ----
  if ($lines -match '(?m)^Status:\s*') {
    $lines = [regex]::Replace($lines, '(?m)^(Status:\s*).+$', ('${1}' + $Status))
  } else {
    $lines = "Status: $Status`r`n$lines"
  }

  # ---- Date (optional refresh) ----
  if ($UpdateDate) {
    if ($lines -match '(?m)^Date:\s*') {
      $lines = [regex]::Replace($lines, '(?m)^(Date:\s*).+$', ('${1}' + $today))
    } else {
      # Insert Date after the H1 line
      $lines = [regex]::Replace($lines, '(?m)^(#\s+.+)$', ('${1}' + "`r`nDate: $today"), 1)
    }
  }

  # ---- Owners (if provided) ----
  if ($ownersLine) {
    if ($lines -match '(?m)^Owners:\s*') {
      $lines = [regex]::Replace($lines, '(?m)^(Owners:\s*).+$', ('${1}' + ($Owners -join ", ")))
    } else {
      if ($lines -match '(?m)^Date:\s*') {
        # Insert right after Date
        $lines = [regex]::Replace($lines, '(?m)^(Date:\s*.+)$', ('${1}' + "`r`n$ownersLine"), 1)
      } else {
        # Insert right after Status
        $lines = [regex]::Replace($lines, '(?m)^(Status:\s*.+)$', ('${1}' + "`r`n$ownersLine"), 1)
      }
    }
  }

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($f.FullName, $lines, $utf8NoBom)
  Write-Host "Updated: $($f.Name)"
}


<#
.\Set-AdrStatus.ps1 -RepoRoot "C:\technical_update_briefings" `
  -Status Accepted `
  -Owners "Shannon Bray","EchoMediaAI Team" `
  -UpdateDate
#>