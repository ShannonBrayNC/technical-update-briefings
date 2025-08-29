$env:TENANT = "38ac7b7f-65e1-4a2a-8e3a-7bbe18659ebe";
$env:CLIENT = "5adca85e-5309-4f49-8c8d-044fccc637f0";
$env:Pf

.\M365RoadMap\tests\Test-GraphConnectivity.ps1 -Verbose `
  -TenantId $env:TENANT `
  -ClientId $env:CLIENT `
  -PfxBase64 $env:PFX_B64 `
  -PfxPassword $env:M365_PFX_PASSWORD `
  -ExportCerPath .\output\app-cert.cer `
  -Cloud 'General'


  