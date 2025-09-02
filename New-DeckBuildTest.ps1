param(
  [string]$Month      = "September 2025",
  [string]$Root       = "C:\technical_update_briefings",
  [double]$RailWidth  = 3.5,
  [string]$Out        = "",
  [string]$Template   = "",          # optional .pptx template
  [string]$DebugDump  = ""           # optional path to write merged items JSON
)

# paths
$Builder  = Join-Path $Root "tools\ppt_builder"
$Py       = Join-Path $Builder ".venv\Scripts\python.exe"
$Run      = Join-Path $Builder "run_build.py"

$Roadmap  = Join-Path $Root "tools\roadmap\RoadmapPrimarySource.html"
$MC       = Join-Path $Root "tools\message_center\MessageCenterBriefingSuppliments.html"

$Assets   = Join-Path $Builder "assets"
$Cover    = Join-Path $Assets  "cover.png"
$Agenda   = Join-Path $Assets  "agenda.png"
$Sep      = Join-Path $Assets  "separator.png"
$Conc     = Join-Path $Assets  "conclusion.png"
$Thx      = Join-Path $Assets  "thankyou.png"
$Logo1    = Join-Path $Assets  "logo1.png"
$Logo2    = Join-Path $Assets  "logo2.png"
$BrandBG  = Join-Path $Assets  "background.png"

$Rocket   = Join-Path $Assets  "rocket.png"
$Preview  = Join-Path $Assets  "preview.png"
$EndUsers = Join-Path $Assets  "audience_end_users.png"
$Admins   = Join-Path $Assets  "audience_admins.png"

if (-not $Out) { $Out = Join-Path $Root ("RoadmapDeck_Test_{0}.pptx" -f (Get-Date -f "yyyyMMdd_HHmmss")) }

# helpers
function Add-IfPath([string]$flag, [string]$path) {
  if ($path -and (Test-Path $path)) { $script:argsList += @($flag, $path) }
}
function Add-IfValue([string]$flag, [string]$value) {
  if ($null -ne $value -and $value -ne "") { $script:argsList += @($flag, $value) }
}

# args for run_build.py (note underscores)
$argsList = @(
  '-i', $Roadmap, $MC,
  '-o', $Out,
  '--month', $Month,
  '--rail_width', "$RailWidth"
)

Add-IfPath  '--template'      $Template
Add-IfPath  '--cover'         $Cover
Add-IfPath  '--agenda'        $Agenda
Add-IfPath  '--separator'     $Sep
Add-IfPath  '--conclusion'    $Conc
Add-IfPath  '--thankyou'      $Thx
Add-IfPath  '--brand_bg'      $BrandBG        # underscore
Add-IfPath  '--logo'          $Logo1
Add-IfPath  '--logo2'         $Logo2
Add-IfPath  '--icon_rocket'   $Rocket         # underscore
Add-IfPath  '--icon_preview'  $Preview        # underscore
Add-IfPath  '--icon_endusers' $EndUsers       # underscore
Add-IfPath  '--icon_admins'   $Admins         # underscore
Add-IfPath  '--debug_dump'    $DebugDump      # underscore

Write-Host "=== DeckBuildTest (run_build.py) ==="
Write-Host "Inputs:" (Resolve-Path $Roadmap).Path ";" (Resolve-Path $MC).Path
Write-Host "Out:    $Out"
Write-Host "Month:  $Month"
Write-Host "Rail:   $RailWidth"
& $Py $Run @argsList
exit $LASTEXITCODE
