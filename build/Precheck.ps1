#requires -Version 7.0
# Precheck.ps1 — fast sanity for repo layout & tooling (no here-strings)
$ErrorActionPreference = 'Stop'

# --- tiny helpers ---
function Fail([string]$msg){ Write-Host ("❌ " + $msg) -ForegroundColor Red;   $script:failed = $true }
function Warn([string]$msg){ Write-Host ("⚠  " + $msg) -ForegroundColor Yellow }
function Ok  ([string]$msg){ Write-Host ("• " + $msg)  -ForegroundColor DarkGray }
function Read-Json([string]$Path){
  if (-not (Test-Path $Path)) { Fail("Missing file: " + $Path); return $null }
  try { (Get-Content -Raw -Encoding UTF8 $Path) | ConvertFrom-Json }
  catch { Fail("Invalid JSON: " + $Path + " (" + $_.Exception.Message + ")"); $null }
}

# --- environment checks ---
try {
  $psver = $PSVersionTable.PSVersion
  if ($psver.Major -lt 7) { Fail("PowerShell 7+ required. Found: " + $psver.ToString()); }
  else { Ok("PowerShell " + $psver.ToString()) }
} catch { Warn("Unable to read PowerShell version") }

try {
  $nodeVer = (& node -v) 2>$null
  if (-not $nodeVer) { Fail("Node.js not found on PATH"); }
  else {
    # remove the leading 'v'
    $nodeSem = $nodeVer.Trim().TrimStart('v')
    $major = [int]($nodeSem.Split('.')[0])
    if ($major -lt 18) { Fail("Node 18+ required. Found: " + $nodeVer) } else { Ok("Node " + $nodeVer) }
  }
} catch { Fail("Failed to run 'node -v'") }

try {
  $npmVer = (& npm -v) 2>$null
  if (-not $npmVer) { Fail("npm not found on PATH"); }
  else {
    $maj = [int]($npmVer.Split('.')[0])
    if ($maj -lt 7) { Fail("npm 7+ (workspaces) required. Found: " + $npmVer) } else { Ok("npm " + $npmVer) }
  }
} catch { Fail("Failed to run 'npm -v'") }

# --- repo root checks ---
$rootPkgPath = Join-Path (Get-Location) "package.json"
$rootPkg = Read-Json $rootPkgPath
if ($null -ne $rootPkg) {
  if (-not $rootPkg.workspaces -or -not ($rootPkg.workspaces | Where-Object { $_ -eq "packages/*" })) {
    Fail("Root package.json must declare workspaces: [""packages/*""]")
  } else { Ok("Root workspaces configured") }

  if ($rootPkg.PSObject.Properties['dependencies'] -and $rootPkg.dependencies -and $rootPkg.dependencies.PSObject.Properties.Count -gt 0) {
    Fail('Root "dependencies" must be empty (runtime deps belong in packages/*)')
  } else { Ok('Root has no runtime dependencies') }

  if ($rootPkg.scripts) {
    foreach($k in @("precheck","ps:test","lint","validate","check")){
      if (-not $rootPkg.scripts.PSObject.Properties[$k]) { Fail('Root "scripts" missing: ' + $k) }
    }
  } else {
    Fail("Root package.json missing ""scripts""")
  }
}

# --- packages: tab ---
$tabDir = "packages/tab"
$tabPkg = Read-Json (Join-Path $tabDir "package.json")
if ($null -ne $tabPkg) {
  if ($tabPkg.name -ne "@suite/tab") { Fail('packages/tab/package.json "name" should be "@suite/tab"') } else { Ok("@suite/tab present") }
  foreach($need in @("react","react-dom")) {
    if (-not $tabPkg.dependencies -or -not $tabPkg.dependencies.PSObject.Properties[$need]) { Fail("tab missing dependency: " + $need) }
  }
  $tabFiles = @(
    "tab/index.html",
    "tab/index.tsx",
    "tab/MeetingTab.tsx",
    "tab/vite.config.ts"
  )
  foreach($rel in $tabFiles){
    $p = Join-Path $tabDir $rel
    if (-not (Test-Path $p)) { Fail("tab missing file: " + $p) }
  }
  if ($tabPkg.scripts -and $tabPkg.scripts.PSObject.Properties['client:dev']) {
    Ok("tab has client:dev script")
  } else { Fail('tab "scripts.client:dev" missing') }
}

# --- packages: bot ---
$botDir = "packages/bot"
$botPkg = Read-Json (Join-Path $botDir "package.json")
if ($null -ne $botPkg) {
  if ($botPkg.name -ne "@suite/bot") { Fail('packages/bot/package.json "name" should be "@suite/bot"') } else { Ok("@suite/bot present") }
  foreach($need in @("express","botbuilder")){
    if (-not $botPkg.dependencies -or -not $botPkg.dependencies.PSObject.Properties[$need]) { Fail("bot missing dependency: " + $need) }
  }
  if ($botPkg.scripts -and $botPkg.scripts.PSObject.Properties['server:dev']) {
    Ok("bot has server:dev script")
  } else { Fail('bot "scripts.server:dev" missing') }
}

# --- summary & exit ---
if ($script:failed) {
  Write-Host ""
  Write-Host "Precheck FAILED. See messages above." -ForegroundColor Red
  exit 1
} else {
  Write-Host ""
  Write-Host "Precheck PASSED." -ForegroundColor Green
  exit 0
}
