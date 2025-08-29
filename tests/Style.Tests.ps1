#requires -Version 7.0
# Style.Tests.ps1 — light repo hygiene tests (no here-strings in tests)
$ErrorActionPreference = 'Stop'

# Collect PowerShell source files (exclude build output & deps)
$psFiles = Get-ChildItem -Recurse -File -Include *.ps1,*.psm1 -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\node_modules\\|\\\.venv\\|\\dist\\|\\out\\|\\coverage\\|\\\.git\\' }

Describe 'Style' {

  It 'Has no here-strings in PowerShell scripts' {
    # Look for @", @' literally (simple match, not regex)
    $hits = $psFiles | Select-String -SimpleMatch -Pattern '@"', "@'"
    $hits | Should -BeNullOrEmpty
  }

  It 'Avoids Measure-Object | Select-Object -ExpandProperty Count anti-pattern' {
    # Use double-quoted regex so single quotes inside don’t terminate the string
    $rx = "Measure-Object\s*\|\s*Select-Object\s*-ExpandProperty\s*Count"
    $hits = $psFiles | Select-String -Pattern $rx
    $hits | Should -BeNullOrEmpty
  }

  It 'Root package.json exists and is valid JSON' {
    $rootPkgPath = Join-Path (Get-Location) 'package.json'
    Test-Path $rootPkgPath | Should -BeTrue
    { (Get-Content -Raw -Encoding UTF8 $rootPkgPath) | ConvertFrom-Json } | Should -Not -Throw
  }
}
