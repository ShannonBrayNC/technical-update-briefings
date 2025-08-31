$RP   = "C:\technical_update_briefings\tools\roadmap\RoadmapPrimarySource.html"
$MC   = "C:\technical_update_briefings\tools\message_center\MessageCenterBriefingSuppliments.html"
$BG   = "C:\technical_update_briefings\tools\ppt_builder\assets\background.png"
$STYLE= "C:\technical_update_briefings\tools\ppt_builder\style_template.yaml"
$COV  = "C:\technical_update_briefings\tools\ppt_builder\assets\cover.png"
$AG   = "C:\technical_update_briefings\tools\ppt_builder\assets\agenda.png"
$SEP  = "C:\technical_update_briefings\tools\ppt_builder\assets\separator.png"
$CON  = "C:\technical_update_briefings\tools\ppt_builder\assets\conclusion.png"
$THX  = "C:\technical_update_briefings\tools\ppt_builder\assets\thankyou.png"
$L1   = "C:\technical_update_briefings\tools\ppt_builder\assets\logo1.png"
$L2   = "C:\technical_update_briefings\tools\ppt_builder\assets\logo2.png"
$Out  = "C:\technical_update_briefings\RoadmapDeck_AutoGen_$((Get-Date).ToString('yyyyMMdd_HHmmss')).pptx"
$RS =   "C:\technical_update_briefings\tools\ppt_builder\assets\rocket.png"
$MG =   "C:\technical_update_briefings\tools\ppt_builder\assets\magnifier.png"

& "C:\technical_update_briefings\tools\ppt_builder\.venv\Scripts\python.exe" `
  "C:\technical_update_briefings\tools\ppt_builder\generate_deck.py" `
  -i $RP $MC `
  -o $Out `
  --style $STYLE `
  --month "September 2025" `
  --cover $COV `
  --agenda $AG `
  --separator $SEP `
  --conclusion $CON `
  --thankyou $THX `
  --logo $L1 `
  --logo2 $L2 `
  --brand-bg $BG `
  --rail-width 3.5 
  
