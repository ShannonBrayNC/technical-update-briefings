$RP   = "C:\technical_update_briefings\tools\roadmap\RoadmapPrimarySource.html"
$MC   = "C:\technical_update_briefings\tools\message_center\MessageCenterBriefingSuppliments.html"
$BG   = "C:\technical_update_briefings\tools\ppt_builder\assets\background.png"   # brand background
$COV  = "C:\technical_update_briefings\tools\ppt_builder\assets\cover.png"
$AG   = "C:\technical_update_briefings\tools\ppt_builder\assets\agenda.png"
$SEP  = "C:\technical_update_briefings\tools\ppt_builder\assets\separator.png"
$CON  = "C:\technical_update_briefings\tools\ppt_builder\assets\conclusion.png"
$THX  = "C:\technical_update_briefings\tools\ppt_builder\assets\thankyou.png"
$L1   = "C:\technical_update_briefings\tools\ppt_builder\assets\logo1.png"
$L2   = "C:\technical_update_briefings\tools\ppt_builder\assets\logo2.png"
$STYLE= "C:\technical_update_briefings\tools\ppt_builder\style_template.yaml"
$RS   = "C:\technical_update_briefings\tools\ppt_builder\assets\rocket.png"
$MG   = "C:\technical_update_briefings\tools\ppt_builder\assets\magnifier.png"
$Out  = "C:\technical_update_briefings\RoadmapDeck_AutoGen_$((Get-Date).ToString('yyyyMMdd_HHmmss')).pptx"


# sanity check the files
$paths = @($RP,$MC,$BG,$COV,$AG,$SEP,$CON,$THX,$L1,$L2,$STYLE,$OUT, $RS, $MG)
$paths | % { "{0}  ->  {1}" -f $_, (Test-Path $_) } | Write-Host

# close any open PPTX first, then run:
& "C:\technical_update_briefings\tools\ppt_builder\.venv\Scripts\python.exe" `
  "C:\technical_update_briefings\tools\ppt_builder\generate_deck.py" `
  -i $RP $MC `
  -o $Out `
  --style $STYLE `
  --month "September 2025" `
  --cover $COV `
  --conclusion $CON `
  --thankyou $THX `
  --logo $L1 `
  --logo2 $L2 `
  --rail-width 3.5 `
  --brand-bg $BG `
  --agenda $AG `
  --separator $SEP  

  
  