# 1) Point $mod at the .psm1 on disk
$mod = 'C:\M365 Roadmap Components\Modules\M365.RoadmapStyled\M365.RoadmapStyled.psm1'

# 2) Sanity check the path really exists
Test-Path $mod
Get-Item  $mod | Select-Object FullName, Length, LastWriteTime

# 3) Clean re-import (add a small pause after remove)
Get-Module M365.RoadmapStyled | Remove-Module -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Import-Module $mod -Force -Verbose

# 4) Confirm the cmdlet is exported
Get-Command Get-M365Roadmap -Module M365.RoadmapStyled
