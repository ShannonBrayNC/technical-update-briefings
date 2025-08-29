#requires -Version 7.0
[CmdletBinding()]
param()

function Get-BriefingGraphMessages {
    [CmdletBinding()]
    param(
        [datetime] $Since,
        [int] $Top = 100
    )

    $tenant = $env:TENANT_ID
    $client = $env:AZURE_CLIENT_ID
    $thumb  = $env:AZURE_CERT_THUMBPRINT

    if (-not $tenant -or -not $client -or -not $thumb) {
        throw 'TENANT_ID, AZURE_CLIENT_ID, and AZURE_CERT_THUMBPRINT are required.'
    }

    Import-Module Microsoft.Graph -ErrorAction Stop
    Connect-MgGraph -TenantId $tenant -ClientId $client -CertificateThumbprint $thumb -NoWelcome | Out-Null

    $messages = Get-MgServiceAnnouncementMessage -All -Property id,title,category,services,publishDateTime,lastModifiedDateTime,severity,actionType,viewPoint
    if ($Since) { $messages = $messages | Where-Object { $_.LastModifiedDateTime -ge $Since } }

    $out = @(
        foreach ($m in $messages | Select-Object -First $Top) {
            $product = if ($m.Services -and $m.Services.Count -gt 0) { $m.Services[0] } else { $null }
            [pscustomobject]@{
                id             = $m.Id
                source         = 'graph-message-center'
                title          = $m.Title
                summary        = $m.Summary
                product        = $product
                category       = $m.Category
                impact         = ($m.Severity).ToString().ToLowerInvariant()
                actionRequired = $m.ActionType
                audience       = 'admins'
                rolloutPhase   = $null
                status         = $null
                tags           = @()
                links          = @(@{ label='Message center'; url=$m.ViewPoint.Link })
                publishedAt    = $m.PublishDateTime
                lastUpdatedAt  = $m.LastModifiedDateTime
            }
        }
    )
    return $out
}
