<# =====================================================================
   run.ps1  —  M365 Roadmap Deck runner
   - Reads deck.config.json (or accepts overrides)
   - Resolves paths relative to the JSON file’s folder (fallbacks provided)
   - Calls the venv python to run generate_deck.py with correct args
   - Verbose logging shows exactly which inputs/assets are used
   ===================================================================== #>

[CmdletBinding()]
param(
  # Optional JSON config (recommended). Example: tools\ppt_builder\deck.config.json
  [string]$Config,

  # Optional overrides (take precedence over JSON):
  [string[]]$Inputs,
  [string]$Output,
  [string]$Month,
  [string]$CoverTitle,
  [string]$CoverDates,
  [string]$SeparatorTitle,
  [string]$Cover,
  [string]$AgendaBg,
  [string]$Separator,
  [string]$ConclusionBg,
  [string]$ThankYou,
  [string]$BrandBg,
  [string]$Logo,
  [string]$Logo2,
  [string]$Rocket,
  [string]$Magnifier,
  [string]$Template,
  [double]$RailWidth = 3.5,

  # Advanced
  [switch]$DryRun   # Just print the computed command; do not execute
)

# --- Constants & Script Roots -------------------------------------------------

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot  = Split-Path -Parent (Split-Path -Parent $script:ScriptDir)  # ...\tools
if (-not (Test-Path $script:RepoRoot)) { $script:RepoRoot = (Get-Location).Path }

$script:ConfigDir = $script:ScriptDir   # default; updated below if -Config supplied

# Try to use venv python in this folder; fallback to py -3.12
$script:VenvPython = Join-Path $script:ScriptDir ".venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $script:VenvPython)) {
  # fallback: system launcher
  $script:VenvPython = "py"
}

$script:GeneratePy = Join-Path $script:ScriptDir "generate_deck.py"

# --- Helpers ------------------------------------------------------------------

function Write-Header([string]$Text) {
  Write-Host ""
  Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function _Read-Json([string]$Path) {
  try {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    return $raw | ConvertFrom-Json -AsHashtable
  } catch {
    Write-Warning "Failed to read JSON '$Path' : $($_.Exception.Message)"
    return $null
  }
}

function _Resolve-PathOrNull {
  param(
    [Parameter(Mandatory)][string]$PathLike,
    [string]$BaseDir = $null
  )
  try {
    if ([System.IO.Path]::IsPathRooted($PathLike)) {
      return (Test-Path -LiteralPath $PathLike) ? (Resolve-Path -LiteralPath $PathLike).Path : $null
    }

    $candidates = @()

    if ($BaseDir)                     { $candidates += (Join-Path -Path $BaseDir -ChildPath $PathLike) }
    if ($script:RepoRoot)             { $candidates += (Join-Path -Path $script:RepoRoot -ChildPath $PathLike) }
    if ($script:ScriptDir)            { $candidates += (Join-Path -Path $script:ScriptDir -ChildPath $PathLike) }
    $candidates += (Join-Path -Path (Get-Location).Path -ChildPath $PathLike)

    foreach ($c in $candidates) {
      if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
    }
    return $null
  } catch { return $null }
}

function _Pick([hashtable]$Cfg, [string]$Key, [object]$Override) {
  if ($PSBoundParameters.ContainsKey($Key) -and $null -ne $Override -and ($Override -ne "")) { return $Override }
  if ($Cfg -and $Cfg.ContainsKey($Key) -and $null -ne $Cfg[$Key] -and ($Cfg[$Key] -ne ""))   { return $Cfg[$Key] }
  return $null
}

# Returns array of "--FLAG", "value" pairs for a single asset path
function _AssetFlag([string]$Flag, [string]$PathLike, [string]$BaseDir) {
  if (-not $PathLike) { return @() }
  $resolved = _Resolve-PathOrNull -PathLike $PathLike -BaseDir $BaseDir
  if ($resolved) { return @("--$Flag", $resolved) }
  Write-Warning "Asset not found for --$Flag : $PathLike  (base '$BaseDir')"
  return @()
}

function _Ensure-OutputPath([string]$PathLike, [string]$BaseDir) {
  $candidate = if ($PathLike) { $PathLike } else { "RoadmapDeck_AutoGen.pptx" }
  $full = _Resolve-PathOrNull -PathLike $candidate -BaseDir $BaseDir
  if (-not $full) {
    # If the parent exists, build a full path there; else put in current folder
    $parent = Split-Path -Parent (Join-Path -Path $BaseDir -ChildPath $candidate)
    if (-not (Test-Path -LiteralPath $parent)) { $parent = (Get-Location).Path }
    $full = Join-Path -Path $parent -ChildPath (Split-Path -Leaf $candidate)
  }
  return $full
}

function _Build-Argv {
  param(
    [hashtable]$Cfg
  )

  # Resolve Inputs relative to the config directory
  $inputsRaw = @()
  if ($PSBoundParameters.ContainsKey('Inputs') -and $Inputs) { $inputsRaw = @($Inputs) }
  elseif ($Cfg -and $Cfg.ContainsKey('Inputs')) { $inputsRaw = @($Cfg.Inputs) }

  $inputsResolved = @()
  foreach ($raw in $inputsRaw) {
    if (-not $raw) { continue }
    $p = _Resolve-PathOrNull -PathLike $raw -BaseDir $script:ConfigDir
    if ($p) { $inputsResolved += $p } else { Write-Warning "Input not found: $raw  (base '$($script:ConfigDir)')" }
  }

  if ($inputsResolved.Count -eq 0) {
    Write-Warning "No valid input files resolved — the deck will only contain shell slides."
  }

  # Output path
  $outWanted = _Pick $Cfg 'Output' $Output
  $outFull   = _Ensure-OutputPath -PathLike $outWanted -BaseDir $script:ConfigDir

  # Prevent ‘file in use’ errors: if cannot open for write, add timestamp
  try {
    $fs = [System.IO.File]::Open($outFull, 'OpenOrCreate', 'ReadWrite', 'None')
    $fs.Close()
  } catch {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $leaf  = [System.IO.Path]::GetFileNameWithoutExtension($outFull)
    $ext   = [System.IO.Path]::GetExtension($outFull)
    $dir   = Split-Path -Parent $outFull
    $alt   = Join-Path $dir "$leaf`_$stamp$ext"
    Write-Warning "Output appears locked. Writing to: $alt"
    $outFull = $alt
  }

  $argv = @()

  if ($inputsResolved.Count -gt 0) {
    $argv += '-i'
    $argv += $inputsResolved
  }

  $argv += @('-o', $outFull)

  # Simple scalar flags
  $scalars = @(
    @{ key='Month';          flag='--month' },
    @{ key='CoverTitle';     flag='--cover-title' },
    @{ key='CoverDates';     flag='--cover-dates' },
    @{ key='SeparatorTitle'; flag='--separator-title' },
    @{ key='Template';       flag='--template' }
  )

  foreach ($m in $scalars) {
    $val = _Pick $Cfg $m.key (Get-Variable -Name $m.key -ValueOnly -ErrorAction SilentlyContinue)
    if ($val) { $argv += @($m.flag, $val) }
  }

  # Numeric rail width
  $rw = $RailWidth
  if (-not $PSBoundParameters.ContainsKey('RailWidth') -and $Cfg -and $Cfg.ContainsKey('RailWidth')) {
    $rw = [double]$Cfg['RailWidth']
  }
  if ($rw -gt 0) { $argv += @('--rail-width', "$rw") }

  # Asset flags (each is a single path)
  $assetPairs = @(
    @{ flag='cover';         key='Cover' },
    @{ flag='agenda-bg';     key='AgendaBg' },
    @{ flag='separator';     key='Separator' },
    @{ flag='conclusion-bg'; key='ConclusionBg' },
    @{ flag='thankyou';      key='ThankYou' },
    @{ flag='brand-bg';      key='BrandBg' },
    @{ flag='logo';          key='Logo' },
    @{ flag='logo2';         key='Logo2' },
    @{ flag='rocket';        key='Rocket' },
    @{ flag='magnifier';     key='Magnifier' }
  )

  foreach ($ap in $assetPairs) {
    $val = _Pick $Cfg $ap.key (Get-Variable -Name $ap.key -ValueOnly -ErrorAction SilentlyContinue)
    if ($val) {
      $argv += (_AssetFlag -Flag $ap.flag -PathLike $val -BaseDir $script:ConfigDir)
    }
  }

  # Final log
  Write-Header "Resolved Inputs"
  if ($inputsResolved.Count -gt 0) { $inputsResolved | ForEach-Object { Write-Host "  - $_" } }
  else { Write-Host "  (none)" }

  Write-Header "Output"
  Write-Host "  $outFull"

  Write-Header "Command Preview"
  $preview = @($script:VenvPython, $script:GeneratePy) + $argv
  Write-Host "  $($preview -join ' ')"

  return $argv
}

function _Ensure-Deps {
  # Only if we found a real Python exe (not the py launcher).
  $isRealExe = ($script:VenvPython -ne 'py' -and (Test-Path -LiteralPath $script:VenvPython))
  if (-not $isRealExe) {
    Write-Verbose "Using 'py' launcher; assuming dependencies are available."
    return
  }

  & $script:VenvPython -m pip install --upgrade pip *> $null
  & $script:VenvPython -m pip install python-pptx beautifulsoup4 lxml Pillow XlsxWriter *> $null
}

function Invoke-DeckBuilder([hashtable]$Cfg) {
  if (-not (Test-Path -LiteralPath $script:GeneratePy)) {
    throw "generate_deck.py not found at: $script:GeneratePy"
  }
  _Ensure-Deps

  $argv = _Build-Argv -Cfg $Cfg

  if ($DryRun) {
    Write-Header "DryRun"
    Write-Host "Skipping execution."
    return
  }

  Write-Header "Running"
  if ($script:VenvPython -eq 'py') {
    # Use py -3.12 if available
    & py -3.12 $script:GeneratePy @argv
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "py -3.12 failed; retrying with 'py' default"
      & py $script:GeneratePy @argv
    }
  } else {
    & $script:VenvPython $script:GeneratePy @argv
  }

  if ($LASTEXITCODE -ne 0) {
    throw "generate_deck.py exited with code $LASTEXITCODE"
  }
}

# --- Main ---------------------------------------------------------------------

Write-Header "Deck Runner"

$cfg = $null
if ($PSBoundParameters.ContainsKey('Config') -and $Config) {
  $cfgPath = (Resolve-Path -LiteralPath $Config -ErrorAction SilentlyContinue)
  if (-not $cfgPath) { throw "Config not found: $Config" }
  $cfg = _Read-Json $cfgPath.Path
  if (-not $cfg) { throw "Failed to read/parse JSON config: $($cfgPath.Path)" }
  $script:ConfigDir = Split-Path -Parent $cfgPath.Path
  Write-Verbose "Using config: $($cfgPath.Path)"
  Write-Verbose "ConfigDir:    $script:ConfigDir"
} else {
  Write-Verbose "No config provided; using only parameter overrides."
  $script:ConfigDir = $script:ScriptDir
}

try {
  Invoke-DeckBuilder -Cfg $cfg
  Write-Host "`nDone." -ForegroundColor Green
} catch {
  Write-Error $_
  exit 1
}
