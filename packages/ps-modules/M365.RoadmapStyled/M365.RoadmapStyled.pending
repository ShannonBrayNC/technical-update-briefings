#requires -Version 5.1

#region ===== Utilities =====

function ConvertTo-StringList {
  param([object]$Value)
  if ($null -eq $Value) { return @() }
  if ($Value -is [string]) { return @($Value) }
  if ($Value -is [System.Collections.IEnumerable]) {
    return @($Value | Where-Object { $_ -ne $null } | ForEach-Object { [string]$_ })
  }
  return @([string]$Value)
}

function Get-RoadmapTags {
  <#
    .SYNOPSIS
      Normalizes Products/Platforms/Clouds/Phases for a roadmap item.
  #>
  param([Parameter(Mandatory)][object]$Item)

  $tc = if ($Item.PSObject.Properties['tagsContainer']) { $Item.tagsContainer } else { $null }

  $products  = if ($tc -and $tc.PSObject.Properties['products'])  { $tc.products }  else { $Item.products }
  $platforms = if ($tc -and $tc.PSObject.Properties['platforms']) { $tc.platforms } else { $Item.platforms }
  $clouds    = if ($tc -and $tc.PSObject.Properties['clouds'])    { $tc.clouds }    else { $Item.clouds }
  $phases    = if ($tc -and $tc.PSObject.Properties['phases'])    { $tc.phases }    else { $Item.phases }

  [pscustomobject]@{
    Products  = ConvertTo-StringList $products
    Platforms = ConvertTo-StringList $platforms
    Clouds    = ConvertTo-StringList $clouds
    Phases    = ConvertTo-StringList $phases
  }
}

function ConvertTo-CloudName {
  param([string]$Name)
  if ([string]::IsNullOrWhiteSpace($Name)) { return $Name }
  $n = $Name.Trim()
  switch -Regex ($n) {
    '^Worldwide'                 { 'Worldwide (Standard Multi-Tenant)'; break }
    'GCC High'                   { 'GCC High'; break }
    'GCC'                        { 'GCC'; break }
    'DoD|DOD|Department of Defense' { 'DoD'; break }
    default { $n }
  }
}

function ConvertTo-PhaseName {
  param([string]$Name)
  if ([string]::IsNullOrWhiteSpace($Name)) { return $Name }
  $n = $Name.Trim()
  switch -Regex ($n) {
    'General\s+Availability' { 'General Availability'; break }
    'Preview'                { 'Preview'; break }
    'Rolling\s+out'          { 'Rolling out'; break }
    'In\s+development'       { 'In development'; break }
    'Launched'               { 'Launched'; break }
    'Cancelled|Canceled'     { 'Cancelled'; break }
    default { $n }
  }
}

function Try-ParseDate {
  [OutputType([bool])]
  param(
    [string]$Text,
    [ref]$DateOut
  )
  $DateOut.Value = [datetime]::MinValue
  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }

  $d = [datetime]::MinValue
  if ([datetime]::TryParse($Text, [ref]$d)) { $DateOut.Value = $d; return $true }

  # Month + Year (optionally with CY)
  if ($Text -match '(January|February|March|April|May|June|July|August|September|October|November|December)\s+(?:CY)?(\d{4})') {
    $m = $matches[1]; $y = [int]$matches[2]
    $DateOut.Value = [datetime]::ParseExact("01 $m $y", 'dd MMMM yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
    return $true
  }

  # CYyyyy -> Jan 1 that year
  if ($Text -match 'CY(\d{4})') {
    $y = [int]$matches[1]
    $DateOut.Value = [datetime]::ParseExact("01 January $y", 'dd MMMM yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
    return $true
  }

  return $false
}

function Select-RoadmapItems {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$Items,

    [string[]]$Products,
    [string[]]$Platforms,
    [string[]]$CloudInstances,
    [string[]]$ReleasePhase,
    [string[]]$Status,
    [string]  $Text,
    [Nullable[datetime]]$UpdatedSince,
    [Nullable[datetime]]$CreatedSince,
    [Nullable[datetime]]$GAFrom,
    [Nullable[datetime]]$GATo
  )

  $wantProducts  = @($Products      | ForEach-Object { $_.ToString().ToLowerInvariant().Trim() })
  $wantPlatforms = @($Platforms     | ForEach-Object { $_.ToString().ToLowerInvariant().Trim() })
  $wantClouds    = @($CloudInstances| ForEach-Object { (ConvertTo-CloudName $_).ToLowerInvariant() })
  $wantPhases    = @($ReleasePhase  | ForEach-Object { (ConvertTo-PhaseName $_).ToLowerInvariant() })
  $wantStatus    = @($Status        | ForEach-Object { $_.ToString().ToLowerInvariant().Trim() })
  $needle        = if ([string]::IsNullOrWhiteSpace($Text)) { $null } else { $Text.ToLowerInvariant() }

  $out = New-Object System.Collections.Generic.List[object]

  foreach ($it in $Items) {
    $tags = Get-RoadmapTags -Item $it
    $p  = @($tags.Products  | ForEach-Object { $_.ToLowerInvariant() })
    $pl = @($tags.Platforms | ForEach-Object { $_.ToLowerInvariant() })
    $c  = @($tags.Clouds    | ForEach-Object { (ConvertTo-CloudName $_).ToLowerInvariant() })
    $ph = @($tags.Phases    | ForEach-Object { (ConvertTo-PhaseName $_).ToLowerInvariant() })

    if ($needle) {
      $hay = (("{0} {1}" -f [string]$it.title, [string]$it.description)).ToLowerInvariant()
      if ($hay.IndexOf($needle) -lt 0) { continue }
    }

    if ($wantProducts.Count  -gt 0 -and (-not ($p  | Where-Object { $wantProducts  -contains $_ }))) { continue }
    if ($wantPlatforms.Count -gt 0 -and (-not ($pl | Where-Object { $wantPlatforms -contains $_ }))) { continue }
    if ($wantClouds.Count    -gt 0 -and (-not ($c  | Where-Object { $wantClouds    -contains $_ }))) { continue }
    if ($wantPhases.Count    -gt 0 -and (-not ($ph | Where-Object { $wantPhases    -contains $_ }))) { continue }

    if ($wantStatus.Count -gt 0) {
      $st = ([string]$it.status).ToLowerInvariant()
      if (-not ($wantStatus -contains $st)) { continue }
    }

    if ($UpdatedSince.HasValue) {
      $mod = $null; [void][datetime]::TryParse([string]$it.modified, [ref]$mod)
      if ($mod -and $mod -lt $UpdatedSince.Value) { continue }
    }
    if ($CreatedSince.HasValue) {
      $cr = $null; [void][datetime]::TryParse([string]$it.created, [ref]$cr)
      if ($cr -and $cr -lt $CreatedSince.Value) { continue }
    }

    if ($GAFrom.HasValue -or $GATo.HasValue) {
      $gaText = [string]$it.ga
      $d1 = $null
      $hit = $false
      if ($gaText -and (Try-ParseDate -Text $gaText -DateOut ([ref]$d1))) { $hit = $true }
      if ($hit) {
        if ($GAFrom.HasValue -and $d1 -lt $GAFrom.Value) { continue }
        if ($GATo.HasValue   -and $d1 -gt $GATo.Value)   { continue }
      }
      # If we cannot infer a GA month, keep it.
    }

    $out.Add($it) | Out-Null
  }

  ,$out.ToArray()
}

function ConvertTo-HtmlSafe {
  param([string]$s)
  if ($null -eq $s) { return '' }
  return ($s -replace '&','&amp;'
             -replace '<','&lt;'
             -replace '>','&gt;'
             -replace '"','&quot;'
             -replace "'","&#39;")}

