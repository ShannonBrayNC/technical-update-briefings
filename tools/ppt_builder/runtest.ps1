# Lightweight smoke run – useful during edits
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Py   = Join-Path $Here ".venv\Scripts\python.exe"
if (-not (Test-Path $Py)) { & (Join-Path $Here "run.ps1"); exit }

$Stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$Out   = Join-Path $Here ("RoadmapDeck_SMOKE_{0}.pptx" -f $Stamp)

& $Py "generate_deck.py" `
  -i "..\tools\roadmap\RoadmapPrimarySource.html", "..\tools\message_center\MessageCenterBriefingSuppliments.html" `
  -o "c:\technical_update_briefings\RoadmapDeck_AutoGen.pptx"`
  --month ((Get-Date).ToString("MMMM yyyy")) `
  --cover (Join-Path $Here "assets\cover.png") `
  --agenda-bg (Join-Path $Here "assets\agenda.png") `
  --separator (Join-Path $Here "assets\separator.png") `
  --conclusion-bg (Join-Path $Here "assets\conclusion.png") `
  --thankyou (Join-Path $Here "assets\thankyou.png") `
  --brand-bg (Join-Path $Here "assets\brand_bg.png") `
  --cover-title "M365 Technical Update Briefing" `
  --cover-dates ((Get-Date).ToString("MMMM yyyy")) `
  --separator-title ("Technical Update Briefing — " + (Get-Date).ToString("MMMM yyyy")) `
  --logo (Join-Path $Here "assets\parex-logo.png") `
  --logo2 (Join-Path $Here "assets\customer-logo.png") `
  --rocket (Join-Path $Here "assets\rocket.png") `
  --magnifier (Join-Path $Here "assets\magnifier.png")


