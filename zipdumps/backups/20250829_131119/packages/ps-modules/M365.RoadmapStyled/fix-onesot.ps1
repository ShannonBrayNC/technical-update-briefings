Param(
  [switch]$Force
)

function Write-Lines {
  param([string]$Path,[string[]]$Lines)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Lines | Out-File -FilePath $Path -Encoding utf8 -Force
}

$testsDir = Join-Path (Get-Location) 'tests'
if (-not (Test-Path $testsDir)) { New-Item -ItemType Directory -Force -Path $testsDir | Out-Null }
$testPath = Join-Path $testsDir 'Style.Tests.ps1'

# Backup existing test
if (Test-Path $testPath) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  Copy-Item -LiteralPath $testPath -Destination "$testPath.bak_$stamp" -Force
  if (-not $Force) { Write-Host "Backed up existing tests to $testPath.bak_$stamp" }
}

# Build new ASCII-only Style.Tests.ps1 (single-quoted to avoid $var interpolation)
$lines = @(
  'Describe ''Style'' {',
  '  BeforeAll {',
  '    # collect .ps1/.psm1 under repo, excluding common noisy dirs',
  '    $script:Files = Get-ChildItem -Path . -Recurse -File |',
  '      Where-Object { $_.Extension -in ''.ps1'',''.psm1'' } |',
  '      Where-Object { $_.FullName -notmatch ''\\node_modules\\|\\\\.venv\\|\\\\.git\\|\\dist\\|\\build\\''',
  '  }',
  '',
  '  It ''Has no here-strings (@'''' or @")'' {',
  '    $hits = foreach ($f in $script:Files) {',
  '      Select-String -Path $f.FullName -SimpleMatch ''@''''',''@"'' -AllMatches -ErrorAction SilentlyContinue',
  '    } | Where-Object { $_ }',
  '    ($hits | Measure-Object).Count | Should -Be 0',
  '  }',
  '',
  '  It ''Does not use Measure-Object | Select-Object -ExpandProperty Count'' {',
  '    $pattern = ''(?i)Measure-Object.*\|\s*Select-Object\s*-ExpandProperty\s*Count''',
  '    $hits = foreach ($f in $script:Files) {',
  '      Select-String -Path $f.FullName -Pattern $pattern -AllMatches -ErrorAction SilentlyContinue',
  '    } | Where-Object { $_ }',
  '    ($hits | Measure-Object).Count | Should -Be 0',
  '  }',
  '',
  '  It ''Does not assign to $host'' {',
  '    $pattern = ''^[\t ]*\$host\s*=''',
  '    $hits = foreach ($f in $script:Files) {',
  '      Select-String -Path $f.FullName -Pattern $pattern -AllMatches -ErrorAction SilentlyContinue',
  '    } | Where-Object { $_ }',
  '    ($hits | Measure-Object).Count | Should -Be 0',
  '  }',
  '',
  '  It ''Does not use a trailing-dollar variable like $host$'' {',
  '    $pattern = ''\$host\$''',
  '    $hits = foreach ($f in $script:Files) {',
  '      Select-String -Path $f.FullName -Pattern $pattern -AllMatches -ErrorAction SilentlyContinue',
  '    } | Where-Object { $_ }',
  '    ($hits | Measure-Object).Count | Should -Be 0',
  '  }',
  '',
  '  Context ''Secret material placement'' {',
  '    It ''Has no secrets outside the security/ folder'' {',
  '      # Suspicious extensions and filenames commonly used for secrets or keys',
  '      $secretExts = ''.pfx'',''.p12'',''.pem'',''.key'',''.p8'',''.p7b'',''.gpg'',''.asc'',''.kdbx'',''.crt'',''.cer''',
  '      $secretNames = ''.env'',''.env.local'',''.env.production'',''.env.development''',
  '      $allFiles = Get-ChildItem -Path . -Recurse -File |',
  '        Where-Object { $_.FullName -notmatch ''\\node_modules\\|\\\\.venv\\|\\\\.git\\|\\dist\\|\\build\\'' }',
  '      $suspects = foreach ($f in $allFiles) {',
  '        $name = $f.Name.ToLowerInvariant()',
  '        $ext  = $f.Extension.ToLowerInvariant()',
  '        $isSecretExt = $secretExts -contains $ext',
  '        $isSecretName = $secretNames -contains $name',
  '        if ($isSecretExt -or $isSecretName) { $f }',
  '      }',
  '      # Allow exceptions: env samples are OK, and anything under security/ is allowed',
  '      $violations = @()',
  '      foreach ($f in $suspects) {',
  '        $full = [IO.Path]::GetFullPath($f.FullName)',
  '        $rel  = $full.Substring((Get-Location).Path.Length).TrimStart(''\'',''/'')',
  '        $underSecurity = $rel -match ''^(?i)security[\\/]''',
  '        $isSample = $f.Name -match ''^(?i).*\.env\.sample$''',
  '        if (-not $underSecurity -and -not $isSample) { $violations += $rel }',
  '      }',
  '      if ($violations.Count -gt 0) {',
  '        Write-Host ''Found potential secret files outside security/:'' -ForegroundColor Yellow',
  '        $violations | ForEach-Object { Write-Host ''  - '' $_ }',
  '      }',
  '      $violations.Count | Should -Be 0 -Because ''Secrets must live only under security/ (env samples allowed anywhere).''',
  '    }',
  '',
  '    It ''Ensures security/.gitignore exists'' {',
  '      $secDir = Join-Path (Get-Location) ''security''',
  '      $gi = Join-Path $secDir ''.gitignore''',
  '      Test-Path $gi | Should -BeTrue -Because ''security/.gitignore should exist to prevent accidental commits.''',
  '    }',
  '  }',
  '}'
)

Write-Lines -Path $testPath -Lines $lines
Write-Host "Wrote $testPath"
