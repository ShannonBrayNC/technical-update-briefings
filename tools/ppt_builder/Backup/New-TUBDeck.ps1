param(
  [string]$Month = "September 2025"
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

& $Py $Gen `
  -i $Roadmap $MC `
  -o $Out `
  --style $Style `
  --month $Month `
  --cover $Cover --agenda $Agenda --separator $Sep `
  --conclusion $Conc --thankyou $Thx `
  --logo $Logo1 --logo2 $Logo2 `
  --brand-bg $BrandBG `
  --icon-rocket $Rocket `
  --icon-preview $Preview `
  --rail-width 3.5
