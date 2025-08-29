
Remove-Module M365.RoadmapStyled -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Import-Module 'C:\M365 Roadmap Components\Modules\M365.RoadmapStyled\M365.RoadmapStyled.psm1' -Force -Verbose


$out = 'C:\M365 Roadmap Components\Roadmap_Latest.html'
$null = Get-M365Roadmap -NextMonth -GroupBy Cloud -Top 200 `
  -CloudInstances 'GCC','GCC High','DoD','Worldwide (Standard Multi-Tenant)' `
  -OutputPath $out -Verbose

Start-Process $out

