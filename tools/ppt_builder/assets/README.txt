Clean Roadmap Assets (Your uploads)
===================================
These are your cleaned images, renamed to the exact filenames the runner/script expect.
Drop them into an `assets` folder and point `run.ps1` to them as shown below.

Included files:
  - thankyou.png
  - agenda.png
  - conclusion.png
  - cover.png
  - separator.png
  - rocket.png
  - magnifier.png
  - parex-logo.png
  - customer-logo.png
  - globe.png

Example usage:

  .\run.ps1 `
    -Inputs @("Roadmap_Latest.html","Briefing_*.html") `
    -Output ".\RoadmapDeck.pptx" -SafeSave `
    -Cover .\assets\cover.png -AgendaBg .\assets\agenda.png `
    -Separator .\assets\separator.png -ConclusionBg .\assets\conclusion.png `
    -ThankYou .\assets\thankyou.png -SeparatorOverlay .\assets\globe.png `
    -IconRollout .\assets\rocket.png -IconPreview .\assets\magnifier.png `
    -Logo .\assets\parex-logo.png -LogoWidth 1.6 `
    -Logo2 .\assets\customer-logo.png -Logo2Width 1.2 -Logo2Anchor left `
    -RailWidth 2.6 -RailTop 0 -RailBottom 0 `
    -CoverHasText -AgendaHasText -SeparatorHasText
