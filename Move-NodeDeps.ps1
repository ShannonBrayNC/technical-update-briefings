#requires -Version 7.0
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = Get-Location
function ReadJson($p){ (Get-Content $p -Raw) | ConvertFrom-Json }
function WriteJson($p,$o){ ($o | ConvertTo-Json -Depth 20) | Set-Content -Path $p -Encoding UTF8 -NoNewline }

function Step($m){ Write-Host "==> $m" -ForegroundColor Green }
function Info($m){ Write-Host "   - $m" -ForegroundColor DarkGray }

$rootPkgPath = Join-Path $root "package.json"
if (-not (Test-Path $rootPkgPath)) { throw "No package.json at root: $root" }
$rootPkg = ReadJson $rootPkgPath

# 1) Ensure workspaces
if (-not $rootPkg.workspaces) {
  Step "Add workspaces to root package.json"
  $rootPkg | Add-Member -Name "workspaces" -MemberType NoteProperty -Value @("packages/*")
}

# 2) Load package manifests (create shells if missing)
$botPath  = Join-Path $root "packages\bot\package.json"
$tabPath  = Join-Path $root "packages\tab\package.json"

if (-not (Test-Path $botPath))  { throw "Missing packages/bot/package.json — run Add-PackageScaffolds.ps1 first." }
if (-not (Test-Path $tabPath))  { throw "Missing packages/tab/package.json — run Add-PackageScaffolds.ps1 first." }

$botPkg = ReadJson $botPath
$tabPkg = ReadJson $tabPath

# Helpers to ensure sections exist
foreach($pkg in @($rootPkg,$botPkg,$tabPkg)){
  if (-not $pkg.dependencies)   { $pkg | Add-Member -Name dependencies   -MemberType NoteProperty -Value @{} }
  if (-not $pkg.devDependencies){ $pkg | Add-Member -Name devDependencies -MemberType NoteProperty -Value @{} }
}

# 3) Plan: move these runtime deps
$toBot = @(
  "express","body-parser","botbuilder",
  "@azure/storage-queue","@azure/identity",
  "@microsoft/microsoft-graph-client",
  "isomorphic-fetch","dotenv"
)
$toTab = @("react","react-dom")

Step "Move runtime deps from root → packages"
$rootDeps = $rootPkg.dependencies | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
foreach($name in $toBot){
  if ($rootDeps -contains $name){
    $ver = $rootPkg.dependencies.$name
    Info "bot: $name@$ver"
    $botPkg.dependencies.$name = $ver
    $rootPkg.dependencies.PSObject.Properties.Remove($name) | Out-Null
  }
}
foreach($name in $toTab){
  if ($rootDeps -contains $name){
    $ver = $rootPkg.dependencies.$name
    Info "tab: $name@$ver"
    $tabPkg.dependencies.$name = $ver
    $rootPkg.dependencies.PSObject.Properties.Remove($name) | Out-Null
  }
}

# 4) Optional: remove duplicate devDeps from root if already present in package
$dupeDevInTab = @("vite","@vitejs/plugin-react","typescript","@types/react","@types/react-dom")
$dupeDevInBot = @("typescript","tsx","@types/node","@types/express","@types/body-parser")

Step "Remove duplicate devDeps from root when owned by a package"
foreach($name in $dupeDevInTab){
  if ($rootPkg.devDependencies.$name -and $tabPkg.devDependencies.$name){
    Info "remove root devDep (owned by tab): $name"
    $rootPkg.devDependencies.PSObject.Properties.Remove($name) | Out-Null
  }
}
foreach($name in $dupeDevInBot){
  if ($rootPkg.devDependencies.$name -and $botPkg.devDependencies.$name){
    Info "remove root devDep (owned by bot): $name"
    $rootPkg.devDependencies.PSObject.Properties.Remove($name) | Out-Null
  }
}

# 5) Write files
if ($DryRun) {
  Step "DryRun: showing changes (truncated)"
  Write-Host "root dependencies:" -ForegroundColor Yellow
  ($rootPkg.dependencies | ConvertTo-Json -Depth 5)
  Write-Host "`nbot dependencies:" -ForegroundColor Yellow
  ($botPkg.dependencies | ConvertTo-Json -Depth 5)
  Write-Host "`ntab dependencies:" -ForegroundColor Yellow
  ($tabPkg.dependencies | ConvertTo-Json -Depth 5)
} else {
  Step "Write updated package.json files"
  WriteJson $rootPkgPath $rootPkg
  WriteJson $botPath $botPkg
  WriteJson $tabPath $tabPkg
}

Write-Host "`n✅ Dependency layout updated." -ForegroundColor Cyan
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  1) Remove-Item -Recurse -Force node_modules, package-lock.json"
Write-Host "  2) npm i"
Write-Host "  3) npm -w @suite/tab run client:dev   (or cd packages/tab && npm run client:dev)"
Write-Host "  4) npm -w @suite/bot run server:dev   (or cd packages/bot && npm run server:dev)"
