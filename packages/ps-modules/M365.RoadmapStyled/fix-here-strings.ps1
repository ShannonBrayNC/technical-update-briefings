# --- fix-here-strings.ps1 ---
$root = 'C:\M365 Roadmap Components'
$mod  = Join-Path $root 'Modules\M365.RoadmapStyled\M365.RoadmapStyled.psm1'
$bak  = "$mod.bak_{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')

if (-not (Test-Path $mod)) { throw "Module not found: $mod" }

Copy-Item $mod $bak -Force
Write-Host "Backup saved to: $bak"

# Read all lines to preserve formatting
$lines = [System.Collections.Generic.List[string]]::new()
$lines.AddRange([IO.File]::ReadAllLines($mod))

$changed = $false
$inHere  = $false
$hereStartIdx = -1
$hereType = ""   # @" or @'

# Helper: regexes for headers/footers
$rxHdrDouble = '^[\s]*@"[\s]*$'
$rxFtrDouble = '^[\s]*"@[\s]*$'

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    if (-not $inHere) {
        if ($line -match $rxHdrDouble) {
            # Start of a double-quoted here-string
            $inHere = $true
            $hereType = '@"'
            $hereStartIdx = $i
        }
        continue
    }

    # We are inside a @" ... "@ block
    if ($hereType -eq '@"' -and $line -match $rxFtrDouble) {
        # Inspect the body between start and this footer for `${`
        $bodyHasTemplate = $false
        for ($j = $hereStartIdx + 1; $j -lt $i; $j++) {
            if ($lines[$j] -like '*`${*') { $bodyHasTemplate = $true; break }
        }

        if ($bodyHasTemplate) {
            # Flip delimiters to single-quoted: @' ... '@
            $lines[$hereStartIdx] = $lines[$hereStartIdx] -replace '@"', "@'"
            $lines[$i]            = $lines[$i]            -replace '"@', "'@"
            $changed = $true
            Write-Host ("Converted here-string at lines {0}-{1} to single-quoted due to `${{..}} usage." -f ($hereStartIdx+1),($i+1))
        }

        # Leave here-string context
        $inHere = $false
        $hereType = ""
        $hereStartIdx = -1
    }
}

if ($inHere) {
    throw "Unterminated here-string starting at line {0}. Aborting patch." -f ($hereStartIdx+1)
}

if ($changed) {
    # Write back preserving newline style
    [IO.File]::WriteAllLines($mod, $lines)
    Write-Host "Patched: $mod"
} else {
    Write-Host "No `${...} found inside double-quoted here-strings. No changes made."
}

# Sanity parse before import
$tokens=$null;$errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($mod,[ref]$tokens,[ref]$errors) | Out-Null
if ($errors) {
    $errors | Format-List Message,@{n='Line';e={$_.Extent.StartLineNumber}},@{n='Col';e={$_.Extent.StartColumnNumber}}
    throw "Parse error – fix module before import. (See messages above.)"
}

# Clean import (avoid remove/import race)
Remove-Module M365.RoadmapStyled -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Import-Module $mod -Force -Verbose

# Smoke test: generate HTML
$out = Join-Path $root 'Roadmap_Latest.html'
$null = Get-M365Roadmap -GroupBy Cloud -Top 50 `
  -CloudInstances 'GCC','GCC High','DoD','Worldwide (Standard Multi-Tenant)' `
  -Status 'Launched','Rolling out','In development' `
  -NextMonth `
  -OutputPath $out -Verbose

Start-Process $out
