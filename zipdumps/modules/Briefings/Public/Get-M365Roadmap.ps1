#requires -Version 7.0
[CmdletBinding()]
param()

function Get-M365Roadmap {
    [CmdletBinding()]
    param(
        [datetime] $Since,
        [int] $Top = 200
    )

    $base = $env:M365_ROADMAP_BASE
    if (-not $base) { throw 'M365_ROADMAP_BASE is required.' }

    $segments = @($base.TrimEnd('/'), 'roadmap')
    $url = ($segments -join '/')
    $res = Invoke-RestMethod -Method GET -Uri $url -ErrorAction Stop

    $items = if ($res.items) { $res.items } else { $res }
    if ($Since) { $items = $items | Where-Object { [datetime]($_.lastModifiedDateTime ?? $_.lastUpdated ?? $_.publicationDate) -ge $Since } }

    $mapped = @(
        foreach ($r in $items | Select-Object -First $Top) {
            $tags = @()
            if ($r.tags) { $tags = @($r.tags.ToString().Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

            $links = @()
            if ($r.externalLink) { $links += [pscustomobject]@{ label='Roadmap'; url=$r.externalLink } }
            if ($r.learnMoreLink) { $links += [pscustomobject]@{ label='Learn more'; url=$r.learnMoreLink } }

            [pscustomobject]@{
                id             = [string]($r.id ?? $r.featureId ?? $r.rowKey ?? [guid]::NewGuid())
                source         = 'm365-roadmap'
                title          = ($r.title ?? $r.featureName ?? '(no title)')
                summary        = ($r.description ?? $r.summary)
                product        = ($r.product ?? $r.productName ?? $r.workload)
                category       = ($r.category ?? $r.categoryName)
                impact         = (($r.impact ?? 'medium').ToString().ToLowerInvariant())
                actionRequired = $null
                audience       = ($r.audience ?? 'admins')
                rolloutPhase   = ($r.releasePhase ?? $r.releasePhaseName ?? $r.ring)
                status         = ($r.status ?? $r.state)
                tags           = $tags
                links          = $links
                publishedAt    = ($r.createdDateTime ?? $r.startDate)
                lastUpdatedAt  = ($r.lastModifiedDateTime ?? $r.lastUpdated ?? $r.publicationDate)
            }
        }
    )
    return $mapped
}
