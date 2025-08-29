#requires -Version 7.0
<#
.SYNOPSIS
  Wrapper for generate_deck.py that supports JSON config or CLI args.

.EXAMPLES
  ./run.ps1 -Config ./deck.config.json
  ./run.ps1 -Inputs ./RoadmapPrimarySource.html -Output ./RoadmapDeck_AutoGen.pptx
#>

param(
  [string]$Config,
  [string[]]$Inputs,
  [string]$Output,
  [string]$Month,
  [double]$RailWidth,
  [string]$Template,            # accepts absolute or relative path
  [hashtable]$Assets,           # optional hashtable of asset overrides
  [switch]$VerbosePython        # show full python command
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function _Read-JsonAsHashtable {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Config not found: $Path"
  }
  try {
    (Get-Content -LiteralPath $Path -Raw) | ConvertFrom-Json -AsHashtable
  } catch {
    throw "Failed to parse JSON config: $Path. $_"
  }
}

function _To-Array {
  param($Value)
  if ($null -eq $Value) { return @() }
  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) { return @($Value) }
  return @("$Value")
}

function _Resolve-PathOrNull {
  param(
    [Parameter(Mandatory)][string]$PathLike,
    [string]$BaseDir = $null  # resolve relative to this directory first
  )
  try {
    # If it’s already rooted and exists, return it.
    if ([System.IO.Path]::IsPathRooted($PathLike)) {
      return (Test-Path -LiteralPath $PathLike) ? (Resolve-Path -LiteralPath $PathLike).Path : $null
    }

    $candidates = @()

    if ($BaseDir) {
      $candidates += (Join-Path -Path $BaseDir -ChildPath $PathLike)
    }

    # Also try relative to repo root (if available) and script root
    if ($script:RepoRoot) {
      $candidates += (Join-Path -Path $script:RepoRoot -ChildPath $PathLike)
    }

    # Directory of the JSON config file (or the script dir if -Config not provided)
    $ConfigPath = $null
    if ($PSBoundParameters.ContainsKey('Config')) {
      $ConfigPath = (Resolve-Path -LiteralPath $Config).Path
    }
    $script:ConfigDir = if ($ConfigPath) { Split-Path -Parent $ConfigPath } else { $PSScriptRoot }


    $candidates += (Join-Path -Path $PSScriptRoot -ChildPath $PathLike)
    $candidates += (Join-Path -Path (Get-Location).Path -ChildPath $PathLike)

    foreach ($c in $candidates) {
      if (Test-Path -LiteralPath $c) {
        return (Resolve-Path -LiteralPath $c).Path
      }
    }
    return $null
  } catch {
    return $null
  }
}

function _Pick {
  <#
    Returns the first non-empty value among: explicit param, config key(s), fallback.
    $Keys can be a single key-name or an array of alternates (case-insensitive).
  #>
  param(
    $ParamValue,
    [hashtable]$Cfg,
    [object]$Keys,
    $Fallback = $null
  )
  if ($PSBoundParameters.ContainsKey('ParamValue') -and $ParamValue) { return $ParamValue }
  if ($Cfg) {
    $tryKeys = @()
    if ($Keys -is [string]) { $tryKeys = @($Keys) } else { $tryKeys = @($Keys) }
    foreach ($k in $tryKeys) {
      foreach ($kv in $Cfg.GetEnumerator()) {
        if ($kv.Key -ieq $k -and $kv.Value) { return $kv.Value }
      }
    }
  }
  return $Fallback
}



# Example inside your asset loop when fetching each path:
$p = _Get-Asset -Cfg $cfg -Keys $assetMap[$flag]
if ($p) {
  $p2 = _Resolve-PathOrNull -PathLike $p -BaseDir $script:ConfigDir
  if ($p2) { $assetArgs += @("--$flag", $p2) }
}





# --- Load config if provided ---
$cfg = @{}
if ($Config) { $cfg = _Read-JsonAsHashtable -Path $Config }

# --- Coalesce inputs ---
# Accept multiple spellings so we don’t get blocked:
#   Inputs | Input | Source | Sources | Html | Files
$inputsAny = _Pick -ParamValue $Inputs -Cfg $cfg -Keys @(
  'Inputs','Input','Source','Sources','Html','Files'
)
$inputs = @()
foreach ($x in _To-Array $inputsAny) {
  $r = _Resolve-PathOrNull $x
  if ($r) { $inputs += $r } else { Write-Warning "Input not found (skipped): $x" }
}
if (-not $inputs -or $inputs.Count -eq 0) {
  throw "No inputs resolved. Provide -Inputs or put an 'Inputs' array in your config JSON."
}

# --- Other options ---
$outPath   = _Pick -ParamValue $Output    -Cfg $cfg -Keys @('Output','Out','Deck','OutputPath') -Fallback 'RoadmapDeck_AutoGen.pptx'
$monthVal  = _Pick -ParamValue $Month     -Cfg $cfg -Keys @('Month','MonthStr','CoverMonth')
$templateP = _Pick -ParamValue $Template  -Cfg $cfg -Keys @('Template','TemplatePath')
if ($templateP) { $templateP = _Resolve-PathOrNull $templateP }

# Rail width (float), allow ints too
$rail = $null
if ($PSBoundParameters.ContainsKey('RailWidth') -and $RailWidth) { $rail = [double]$RailWidth }
elseif ($cfg.ContainsKey('RailWidth')) { $rail = [double]$cfg.RailWidth }
elseif ($cfg.ContainsKey('Rail') -and $cfg.Rail) { $rail = [double]$cfg.Rail }
else { $rail = 3.5 }


# --- Resolve optional assets (support snake_case and PascalCase) ---
# map of CLI flag name => accepted config keys
$assetMap = @{
  'brand-bg'      = @('brand_bg','BrandBg')
  'cover'         = @('cover','Cover')
  'agenda-bg'     = @('agenda_bg','AgendaBg')
  'separator'     = @('separator','Separator')
  'conclusion-bg' = @('conclusion_bg','ConclusionBg')
  'thankyou'      = @('thankyou','ThankYou')
  'logo'          = @('logo','Logo')
  'logo2'         = @('logo2','Logo2')
  'rocket'        = @('rocket','Rocket')
  'magnifier'     = @('magnifier','Magnifier')
}

$assetArgs = @()
foreach ($flag in $assetMap.Keys) {
  $p = _Get-Asset -Cfg $cfg -Keys $assetMap[$flag]
  if ($p) { $assetArgs += @("--$flag", $p) }
}


# --- Python and generator path ---
$venvPy = Join-Path $PSScriptRoot ".venv/Scripts/python.exe"
if (-not (Test-Path -LiteralPath $venvPy)) { $venvPy = 'python' }
$gen = Join-Path $PSScriptRoot 'generate_deck.py'
if (-not (Test-Path -LiteralPath $gen)) {
  throw "Generator not found: $gen"
}

# --- Build argv for python script ---
$argv = @()

# inputs
$argv += @('-i') + $inputs

# output
$argv += @('-o', $outPath)

# month
if ($monthVal) { $argv += @('--month', "$monthVal") }

# template
if ($templateP) { $argv += @('--template', $templateP) }

# rail width
if ($rail) { $argv += @('--rail-width', ("{0:0.###}" -f $rail)) }


# cover/separator text (optional)
$coverTitle  = _Pick -ParamValue $CoverTitle     -Cfg $cfg -Keys @('CoverTitle')
$coverDates  = _Pick -ParamValue $CoverDates     -Cfg $cfg -Keys @('CoverDates')
$sepTitle    = _Pick -ParamValue $SeparatorTitle -Cfg $cfg -Keys @('SeparatorTitle')

if ($coverTitle) { $argv += @('--cover-title',  $coverTitle) }
if ($coverDates) { $argv += @('--cover-dates',  $coverDates) }
if ($sepTitle)   { $argv += @('--separator-title', $sepTitle) }




# assets
$argv += $assetArgs

if ($VerbosePython) {
  Write-Host "`n> $venvPy `"$gen`" $($argv -join ' ')" -ForegroundColor Cyan
}

# --- Run ---
try {
  & $venvPy $gen @argv
} catch {
  if ($_.Exception -and $_.Exception.Message -match 'Permission denied.*\.pptx') {
    Write-Error "Failed to write '$outPath'. Close the deck if it is open and try again."
  } else {
    throw
  }
}
