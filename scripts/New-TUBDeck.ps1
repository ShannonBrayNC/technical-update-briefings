param(
  [string]$Month = "September 2025"
)


# Build a safe, conditional argument list
$argsList = @(
  '-i', $Roadmap, $MC,
  '-o', $Out,
  '--style', $Style,
  '--month', $Month,
  '--rail-width', '3.5'
)





$Root     = "C:\technical_update_briefings"
$Builder  = Join-Path $Root "tools\ppt_builder"
$Roadmap  = Join-Path $Root "tools\roadmap\RoadmapPrimarySource.html"
$MC       = Join-Path $Root "tools\message_center\MessageCenterBriefingSuppliments.html"

$Assets   = Join-Path $Builder "assets"
$Style    = Join-Path $Builder "style_template.yaml"
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

$Py       = Join-Path $Builder ".venv\Scripts\python.exe"
$Gen      = Join-Path $Builder "generate_deck.py"
$Out      = Join-Path $Root ("RoadmapDeck_AutoGen_{0}.pptx" -f (Get-Date -f "yyyyMMdd_HHmmss"))
$EndUsers = Join-Path $Assets "audience_end_users.png"
$Admins   = Join-Path $Assets "audience_admins.png"



if (Test-Path $EndUsers) { $argsList += @('--icon-endusers', $EndUsers) }
if (Test-Path $Admins)   { $argsList += @('--icon-admins',   $Admins) }
if (Test-Path $Cover)   { $argsList += @('--cover', $Cover) }
if (Test-Path $Agenda)  { $argsList += @('--agenda-bg', $Agenda) }         # <-- agenda-bg
if (Test-Path $Sep)     { $argsList += @('--separator', $Sep) }
if (Test-Path $Conc)    { $argsList += @('--conclusion-bg', $Conc) }       # <-- conclusion-bg
if (Test-Path $Thx)     { $argsList += @('--thankyou', $Thx) }
if (Test-Path $Logo1)   { $argsList += @('--logo', $Logo1) }
if (Test-Path $Logo2)   { $argsList += @('--logo2', $Logo2) }
if (Test-Path $BrandBG) { $argsList += @('--brand-bg', $BrandBG) }         # <-- brand-bg
if (Test-Path $Rocket)  { $argsList += @('--icon-rocket', $Rocket) }
if (Test-Path $Preview) { $argsList += @('--icon-preview', $Preview) }



$BRAND = "C:\technical_update_briefings\tools\ppt_builder\assets\background.png"

& "C:\technical_update_briefings\tools\ppt_builder\.venv\Scripts\python.exe" `
  "C:\technical_update_briefings\tools\ppt_builder\generate_deck.py" `
  -i $RP $MC `
  -o $Out `
  --style $STYLE `
  --month "September 2025" `
  --cover $COV --agenda-bg $AG --separator $SEP `
  --conclusion-bg $CON --thankyou $THX `
  --logo $L1 --logo2 $L2 `
  --rail-width  @('--rail-width, 3.5') `
  @($(if (Test-Path $BRAND) { '--brand-bg', $BRAND })) `
  @($(if (Test-Path $ROCKET) { '--icon-rocket', $ROCKET })) `
  @($(if (Test-Path $PREVIEW){ '--icon-preview', $PREVIEW })) `
  @($(if (Test-Path $END)    { '--icon-endusers', $END })) `
  @($(if (Test-Path $ADM)    { '--icon-admins',   $ADM }))