<#
Run this from anywhere:

  PS C:\technical_update_briefings> .\tools\ppt_builder\run.ps1

It will:
  - Create/upgrade a local venv in tools\ppt_builder\.venv
  - Install python-pptx + HTML libs into that venv
  - Build a timestamped deck from the local HTML inputs and assets
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve script folder (tools\ppt_builder)
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $Here

try {
  # --- VENV BOOTSTRAP ---
  $VenvDir = Join-Path $Here ".venv"
  $PyExe   = Join-Path $VenvDir "Scripts\python.exe"

  if (-not (Test-Path $PyExe)) {
    Write-Host "Creating venv in $VenvDir ..."
    # prefer 3.12 to match pptx ecosystem stability
    if (Get-Command py -ErrorAction SilentlyContinue) {
      py -3.12 -m venv $VenvDir
    } else {
      Write-Host "Python launcher 'py' not found. Falling back to 'python'..."
      python -m venv $VenvDir
    }
  }

  # Upgrade pip + install deps *into this venv*
  & $PyExe -m pip install --upgrade pip
  & $PyExe -m pip install python-pptx beautifulsoup4 lxml Pillow XlsxWriter

  # Sanity check the interpreter really imports from this venv
  & $PyExe - << 'PY'
import sys
print("python =", sys.executable)
try:
  import pptx, bs4, lxml
  from PIL import Image
  import xlsxwriter
  print("IMPORT_OK")
except Exception as e:
  raise SystemExit("IMPORT_FAILED: %r" % (e,))
'PY'

  # --- INPUTS & ASSETS (repo-relative) ---
  $Inputs = @()
  $primary = Join-Path $Here "RoadmapPrimarySource.html"
  if (Test-Path $primary) { $Inputs += $primary }

  $msgCenter = Join-Path $Here "MessageCenterBriefingSuppliments.html"
  if (Test-Path $msgCenter) { $Inputs += $msgCenter }

  if ($Inputs.Count -eq 0) {
    throw "No inputs found. Expected RoadmapPrimarySource.html and/or MessageCenterBriefingSuppliments.html in tools\ppt_builder."
  }

  $AssetsDir = Join-Path $Here "assets"
  function A($name) { Join-Path $AssetsDir $name }

  $Cover        = A "cover.png"
  $AgendaBg     = A "agenda.png"
  $Separator    = A "separator.png"
  $ConclusionBg = A "conclusion.png"
  $ThankYou     = A "thankyou.png"
  $BrandBg      = A "brand_bg.png"         # optional plain brand swatch
  $Logo1        = A "parex-logo.png"
  $Logo2        = A "customer-logo.png"    # optional
  $Rocket       = A "rocket.png"
  $Magnifier    = A "magnifier.png"
  $AdminIcon    = A "admin.png"
  $UserIcon     = A "user.png"
  $CheckIcon    = A "check.png"

  # Month label – defaults to current if you don’t override
  $MonthLabel = (Get-Date).ToString("MMMM yyyy")

  # Output path – timestamped to dodge “file in use” locks
  $Stamp   = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $OutFile = Join-Path $Here ("RoadmapDeck_{0}.pptx" -f $Stamp)

  # Optional: template fallback (must exist to be used)
  $Template = Join-Path $Here "RoadmapDeck_Sample_Refined.pptx"
  $UseTemplate = (Test-Path $Template)

  # --- BUILD ---
  $args = @(
    "generate_deck.py",
    "-i"
  ) + $Inputs + @(
    "-o", $OutFile,
    "--month", $MonthLabel,
    "--cover", $Cover,
    "--agenda-bg", $AgendaBg,
    "--separator", $Separator,
    "--conclusion-bg", $ConclusionBg,
    "--thankyou", $ThankYou,
    "--brand-bg", $BrandBg,
    "--cover-title", "M365 Technical Update Briefing",
    "--cover-dates", $MonthLabel,
    "--separator-title", "Technical Update Briefing — $MonthLabel",
    "--logo", $Logo1,
    "--logo2", $Logo2,
    "--rocket", $Rocket,
    "--magnifier", $Magnifier,
    "--admin", $AdminIcon,
    "--user", $UserIcon,
    "--check", $CheckIcon
  )

  if ($UseTemplate) {
    $args += @("--template", $Template)
  }

  Write-Host "`nRunning deck generator..."
  & $PyExe @args

  if (-not (Test-Path $OutFile)) {
    throw "Deck generation finished but output not found: $OutFile"
  }

  Write-Host "`nSUCCESS: $OutFile"
}
finally {
  Pop-Location
}