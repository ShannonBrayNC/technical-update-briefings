# Lightweight smoke run – useful during edits
$Here = "c:\technical_update_briefings\technical_update_briefings\" 
$Py   = "c:\technical_update_briefings\tools\ppt_builder\.venv\Scripts\python.exe"
$Out   = "C:\technical_update_briefings\RoadmapDeck_SMOKE.pptx"
$i1 = "c:\technical_update_briefings\tools\roadmap\RoadmapPrimarySource.html"
$i2 = "c:\technical_update_briefings\tools\message_center\MessageCenterBriefingSuppliments.html"


& $Py ("c:\\technical_update_briefings\\tools\\ppt_builder\\generate_deck.py") `
  --i ($i1 , $i2) `
  --o ($Out) `
  --month ((Get-Date).ToString("09-2025")) `
  --cover (Join-Path $Here "assets\cover.png") `
  --agenda-bg (Join-Path $Here "assets\agenda.png") `
  --separator (Join-Path $Here "assets\separator.png") `
  --conclusion-bg (Join-Path $Here "assets\conclusion.png") `
  --thankyou (Join-Path $Here "assets\thankyou.png") `
  --brand-bg (Join-Path $Here "assets\brand_bg.png") `
  --cover-title "M365 Technical Update Briefing" `
  --cover-dates ((Get-Date).ToString("MMMM yyyy")) `
  --logo (Join-Path $Here "assets\parex-logo.png") `
  --logo2 (Join-Path $Here "assets\customer-logo.png") 


  #  --separator-title ("Technical Update Briefing — " + (Get-Date).ToString("MMMM yyyy")) `
  #  --rocket (Join-Path $Here "assets\rocket.png") `
  #--magnifier (Join-Path $Here "assets\magnifier.png") 
