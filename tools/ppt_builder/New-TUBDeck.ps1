  
& "C:\technical_update_briefings\tools\ppt_builder\.venv\Scripts\python.exe" `
  "C:\technical_update_briefings\tools\ppt_builder\generate_deck.py" `
  -i "C:\technical_update_briefings\tools\roadmap\RoadmapPrimarySource.html" `
     "C:\technical_update_briefings\tools\message_center\MessageCenterBriefingSuppliments.html" `
  -o "C:\technical_update_briefings\RoadmapDeck_AutoGen.pptx" `
  --style "C:\technical_update_briefings\tools\ppt_builder\style_template.yaml" `
  --month "September 2025" `
  --cover "C:\technical_update_briefings\tools\ppt_builder\assets\cover.png" `
  --agenda-bg "C:\technical_update_briefings\tools\ppt_builder\assets\agenda.png" `
  --separator "C:\technical_update_briefings\tools\ppt_builder\assets\separator.png" `
  --conclusion-bg "C:\technical_update_briefings\tools\ppt_builder\assets\conclusion.png" `
  --thankyou "C:\technical_update_briefings\tools\ppt_builder\assets\thankyou.png" `
  --brand-bg "C:\technical_update_briefings\tools\ppt_builder\assets\background.png" `
  --logo "C:\technical_update_briefings\tools\ppt_builder\assets\logo1.png" `
  --logo2 "C:\technical_update_briefings\tools\ppt_builder\assets\logo2.png" `
  --icon-rocket  "C:\technical_update_briefings\tools\ppt_builder\assets\rocket.png" `
  --icon-preview "C:\technical_update_briefings\tools\ppt_builder\assets\preview.png" `
  --icon-dev    "C:\technical_update_briefings\tools\ppt_builder\assets\dev.png" `
  --icon-endusers "C:\technical_update_briefings\tools\ppt_builder\assets\audience_end_users.png" `
  --icon-admins   "C:\technical_update_briefings\tools\ppt_builder\assets\audience_admins.png" `
  --rail-width 3.5 `
  --debug-dump "$env:TEMP\items.json"
  

