# tools/ppt_builder/run.ps1
[CmdletBinding()]
param(
  [string]$Config = "$PSScriptRoot\deck.config.json",
  [switch]$NoVenv,
  [switch]$NoPip,
  [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-From($baseDir, $p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return $null }
  if ([System.IO.Path]::IsPathRooted($p)) { return $p }
  return (Join-Path -Path $baseDir -ChildPath $p)
}

function Must-Exist($label, $path, [switch]$Optional) {
  if ([string]::IsNullOrWhiteSpace($path)) {
    if ($Optional) { return $null }
    throw "Missing $label path."
  }
  if (-not (Test-Path -LiteralPath $path)) {
    if ($Optional) {
      Write-Verbose "Optional $label not found: $path"
      return $null
    }
    throw "$label not found: $path"
  }
  return (Resolve-Path -LiteralPath $path).Path
}

# 1) Load config (as hashtable so we can check keys safely)
if (-not (Test-Path -LiteralPath $Config)) { throw "Config file not found: $Config" }
$ConfigPath = (Resolve-Path -LiteralPath $Config).Path
$ConfigDir  = Split-Path -Parent $ConfigPath
$cfg = (Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json -AsHashtable)

# 2) Resolve and validate inputs/output relative to the config location
$inputs = @()
foreach ($raw in @($cfg.Inputs)) {
  $abs = Resolve-From $ConfigDir $raw
  $inputs += (Must-Exist "Input" $abs)
}
if ($inputs.Count -eq 0) { throw "No Inputs provided in config." }

$output = Resolve-From $ConfigDir $cfg.Output
if ([string]::IsNullOrWhiteSpace($output)) { throw "Output not provided in config." }
$null = New-Item -Path (Split-Path -Parent $output) -ItemType Directory -Force -ErrorAction SilentlyContinue

# 3) Optional assets & strings
$cover        = Must-Exist "Cover"        (Resolve-From $ConfigDir $cfg.Cover)        -Optional
$agendaBg     = Must-Exist "AgendaBg"     (Resolve-From $ConfigDir $cfg.AgendaBg)     -Optional
$separator    = Must-Exist "Separator"    (Resolve-From $ConfigDir $cfg.Separator)    -Optional
$conclusionBg = Must-Exist "ConclusionBg" (Resolve-From $ConfigDir $cfg.ConclusionBg) -Optional
$thankyou     = Must-Exist "ThankYou"     (Resolve-From $ConfigDir $cfg.ThankYou)     -Optional
$brandBg      = Must-Exist "BrandBg"      (Resolve-From $ConfigDir $cfg.BrandBg)      -Optional
$logo         = Must-Exist "Logo"         (Resolve-From $ConfigDir $cfg.Logo)         -Optional
$logo2        = Must-Exist "Logo2"        (Resolve-From $ConfigDir $cfg.Logo2)        -Optional
$rocket       = Must-Exist "Rocket"       (Resolve-From $ConfigDir $cfg.Rocket)       -Optional
$magnifier    = Must-Exist "Magnifier"    (Resolve-From $ConfigDir $cfg.Magnifier)    -Optional
$template     = Must-Exist "Template"     (Resolve-From $ConfigDir $cfg.Template)     -Optional

$month         = [string]$cfg.Month
$coverTitle    = [string]$cfg.CoverTitle
$coverDates    = [string]$cfg.CoverDates
$separatorTitle= [string]$cfg.SeparatorTitle
$railWidth     = if ($cfg.RailWidth) { [string]$cfg.RailWidth } else { $null }

# 4) Python selection + venv bootstrap
$scriptDir  = $PSScriptRoot
$venvPy     = Join-Path $scriptDir ".venv\Scripts\python.exe"
$python     = $null

if (-not $NoVenv -and (Test-Path -LiteralPath $venvPy)) {
  $python = $venvPy
} else {
  $python = "python"
}

Write-Verbose "Python => $python"
if (-not $NoPip) {
  try {
    & $python -m pip --version | Out-Null
  } catch {
    Write-Warning "pip check failed; continuing"
  }
}

# 5) Requirements (optional)
$req = Join-Path $scriptDir "requirements.txt"
if (-not $NoPip -and (Test-Path -LiteralPath $req)) {
  Write-Host "Ensuring Python deps (requirements.txt)..." -ForegroundColor Cyan
  & $python -m pip install -r $req
}

# 6) Build argument list for generate_deck.py
$gen = (Must-Exist "generate_deck.py" (Join-Path $scriptDir "generate_deck.py"))
$args = @($gen, "-i") + $inputs + @("-o", $output)

function Add-Flag($name, $val) {
  if ($null -ne $val -and $val -ne "") {
    $script:args += @($name, $val)
  }
}
Add-Flag "--month"          $month
Add-Flag "--cover-title"    $coverTitle
Add-Flag "--cover-dates"    $coverDates
Add-Flag "--separator-title"$separatorTitle
Add-Flag "--cover"          $cover
Add-Flag "--agenda-bg"      $agendaBg
Add-Flag "--separator"      $separator
Add-Flag "--conclusion-bg"  $conclusionBg
Add-Flag "--thankyou"       $thankyou
Add-Flag "--brand-bg"       $brandBg
Add-Flag "--logo"           $logo
Add-Flag "--logo2"          $logo2
Add-Flag "--rocket"         $rocket
Add-Flag "--magnifier"      $magnifier
Add-Flag "--template"       $template
Add-Flag "--rail-width"     $railWidth

# 7) Self-check
Write-Host "=== Deck build self-check ===" -ForegroundColor Yellow
"{0,-18} {1}" -f "Config:", $ConfigPath
"{0,-18} {1}" -f "Inputs:", ($inputs -join "; ")
"{0,-18} {1}" -f "Output:", $output
"{0,-18} {1}" -f "Month:", $month
"{0,-18} {1}" -f "Template:", ($template ?? "<none>")
"{0,-18} {1}" -f "RailWidth:", ($railWidth ?? "<default>")
"{0,-18} {1}" -f "Cover/Agenda:", (($cover ?? "<none>") + " / " + ($agendaBg ?? "<none>"))
"{0,-18} {1}" -f "Separator:", ($separator ?? "<none>")
"{0,-18} {1}" -f "Conclusion/Thanks:", (($conclusionBg ?? "<none>") + " / " + ($thankyou ?? "<none>"))
"{0,-18} {1}" -f "Logos:", (($logo ?? "<none>") + " / " + ($logo2 ?? "<none>"))
"{0,-18} {1}" -f "Icons:", (($rocket ?? "<none>") + " / " + ($magnifier ?? "<none>"))
Write-Host "==============================`n"

if ($WhatIf) {
  Write-Host "[WhatIf] Would run:" -ForegroundColor DarkCyan
  Write-Host ("`n{0} {1}`n" -f $python, ($args | ForEach-Object { '"{0}"' -f ($_ -replace '"','\"') }) -join ' ')
  return
}

# 8) Run
& $python @args
