
# install-sanity.ps1 — replaces a broken module with the fixed build and runs a smoke test

$ErrorActionPreference = 'Stop'

$moduleTarget = 'C:\M365 Roadmap Components\Modules\M365.RoadmapStyled\M365.RoadmapStyled.psm1'

# Try to auto-locate the fixed file
$fixedName = 'M365.RoadmapStyled.fixed.psm1'
$candidates = @(
  (Join-Path $HOME "Downloads\$fixedName"),
  "C:\Users\Public\Downloads\$fixedName",
  "C:\M365 Roadmap Components\$fixedName",
  (Join-Path (Get-Location) $fixedName)
) | Where-Object { Test-Path $_ }

if (-not $candidates -or $candidates.Count -eq 0) {
  Write-Error "Couldn't find $fixedName. Please download it and place it in your Downloads folder, then re-run this script."
  return
}

$fixedSrc = $candidates[0]
Write-Host "Using fixed module from: $fixedSrc"

# Backup current module if present
if (Test-Path $moduleTarget) {
  $backup = "$moduleTarget.bak_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  Copy-Item $moduleTarget $backup -Force
  Write-Host "Backed up current module to: $backup"
}

# Replace the module
Remove-Module M365.RoadmapStyled -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Copy-Item $fixedSrc $moduleTarget -Force
Write-Host "Copied fixed module to: $moduleTarget"

# Import & test
Import-Module $moduleTarget -Force -Verbose

# Quick smoke test
$out = 'C:\M365 Roadmap Components\Roadmap_Latest.html'
$null = Get-M365Roadmap -NextMonth -GroupBy Cloud -Top 50 `
  -CloudInstances 'GCC','GCC High','DoD','Worldwide (Standard Multi-Tenant)' `
  -Status 'Launched' `
  -OutputPath $out -Verbose

if (Test-Path $out) {
  Write-Host "Smoke test OK. Opening report: $out"
  Start-Process $out
} else {
  Write-Warning "Import succeeded but no HTML produced. Re-run with -Verbose and share the console output."
}
