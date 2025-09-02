param(
  [string]$Month        = "September 2025",
  [string]$Root         = "C:\technical_update_briefings",
  [double]$RailWidth    = 3.5,
  # Optional overrides (leave blank to use defaults under $Root\tools\ppt_builder\assets)
  [string]$Out          = "",
  [string]$Style        = "",
  [string]$Roadmap      = "",
  [string]$MessageCenter= "",
  [string]$BrandBG      = "",
  [string]$Cover        = "",
  [string]$Agenda       = "",
  [string]$Separator    = "",
  [string]$Conclusion   = "",
  [string]$ThankYou     = "",
  [string]$Logo1        = "",
  [string]$Logo2        = "",
  [string]$IconRocket   = "",
  [string]$IconPreview  = "",
  [string]$IconEndUsers = "",
  [string]$IconAdmins   = "",
  [string]$Template     = ""
)

# ---------- defaults ----------
$Builder  = Join-Path $Root "tools\ppt_builder"
$Assets   = Join-Path $Builder "assets"
if (-not $Style)         { $Style         = Join-Path $Builder "style_template.yaml" }
if (-not $Roadmap)       { $Roadmap       = Join-Path $Root   "tools\roadmap\RoadmapPrimarySource.html" }
if (-not $MessageCenter) { $MessageCenter = Join-Path $Root   "tools\message_center\MessageCenterBriefingSuppliments.html" }
if (-not $Cover)         { $Cover         = Join-Path $Assets "cover.png" }
if (-not $Agenda)        { $Agenda        = Join-Path $Assets "agenda.png" }
if (-not $Separator)     { $Separator     = Join-Path $Assets "separator.png" }
if (-not $Conclusion)    { $Conclusion    = Join-Path $Assets "conclusion.png" }
if (-not $ThankYou)      { $ThankYou      = Join-Path $Assets "thankyou.png" }
if (-not $Logo1)         { $Logo1         = Join-Path $Assets "logo1.png" }
if (-not $Logo2)         { $Logo2         = Join-Path $Assets "logo2.png" }
if (-not $BrandBG)       { $BrandBG       = Join-Path $Assets "background.png" }
if (-not $IconRocket)    { $IconRocket    = Join-Path $Assets "rocket.png" }
if (-not $IconPreview)   { $IconPreview   = Join-Path $Assets "preview.png" }
if (-not $IconEndUsers)  { $IconEndUsers  = Join-Path $Assets "audience_end_users.png" }
if (-not $IconAdmins)    { $IconAdmins    = Join-Path $Assets "audience_admins.png" }
if (-not $Out)           { $Out           = Join-Path $Root   ("RoadmapDeck_AutoGen_{0}.pptx" -f (Get-Date -f "yyyyMMdd_HHmmss")) }

$Py  = Join-Path $Builder ".venv\Scripts\python.exe"
$Gen = Join-Path $Builder "generate_deck.py"

# ---------- helper to append flag if file exists ----------
function Add-IfPath([string]$flag, [string]$path) {
  if ($path -and (Test-Path $path)) { $script:argsList += @($flag, $path) }
}
function Add-IfValue([string]$flag, [string]$value) {
  if ($null -ne $value -and $value -ne "") { $script:argsList += @($flag, $value) }
}

$_styled = if (Test-Path $Style) { (Resolve-Path $Style).Path } else { "MISSING" }

# ---------- build args for generate_deck.py ----------
$argsList = @(
  '-i', $Roadmap, $MessageCenter,
  '-o', $Out,
  '--style', $_styled,
  '--month', $Month,
  '--rail-width', "$RailWidth"
)

Add-IfPath '--cover'          $Cover
Add-IfPath '--agenda-bg'      $Agenda
Add-IfPath '--separator'      $Separator
Add-IfPath '--conclusion-bg'  $Conclusion
Add-IfPath '--thankyou'       $ThankYou
Add-IfPath '--logo'           $Logo1
Add-IfPath '--logo2'          $Logo2
Add-IfPath '--brand-bg'       $BrandBG
Add-IfPath '--icon-rocket'    $IconRocket
Add-IfPath '--icon-preview'   $IconPreview
Add-IfPath '--icon-endusers'  $IconEndUsers
Add-IfPath '--icon-admins'    $IconAdmins
Add-IfPath '--template'       $Template

Write-Host "=== TUBDeck ==="
Write-Host "Month: $Month"
Write-Host "Inputs:" (Resolve-Path $Roadmap).Path ";" (Resolve-Path $MessageCenter).Path
Write-Host "Out: $Out"
Write-Host "Style:" $_styled
Write-Host "Rail Width: $RailWidth"
Write-Host "Optional assets that will be used if present:"
'cover','agenda','separator','conclusion','thankyou','logo1','logo2','brandBG','iconRocket','iconPreview','iconEndUsers','iconAdmins' | Out-Null
# (Quick presence summary)
$present = @{}
$present["cover"]        = (Test-Path $Cover)
$present["agenda"]       = (Test-Path $Agenda)
$present["separator"]    = (Test-Path $Separator)
$present["conclusion"]   = (Test-Path $Conclusion)
$present["thankyou"]     = (Test-Path $ThankYou)
$present["logo1"]        = (Test-Path $Logo1)
$present["logo2"]        = (Test-Path $Logo2)
$present["brandBG"]      = (Test-Path $BrandBG)
$present["iconRocket"]   = (Test-Path $IconRocket)
$present["iconPreview"]  = (Test-Path $IconPreview)
$present["iconEndUsers"] = (Test-Path $IconEndUsers)
$present["iconAdmins"]   = (Test-Path $IconAdmins)
$present.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host (" - {0,-12} : {1}" -f $_.Name, ($_.Value ? "yes" : "no")) }

# ---------- run ----------
& $Py $Gen @argsList
exit $LASTEXITCODE
