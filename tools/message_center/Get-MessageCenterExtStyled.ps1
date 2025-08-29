<# 
  Get-MessageCenterExtStyled.ps1
  Microsoft 365 Message Center → Styled Technical Briefing
  - App-only certificate auth
  - Robust Graph fetching with retries
  - Rich HTML briefing (grouped by Service) + optional Markdown
#>

[CmdletBinding()]
param(
  # --- Auth/Paths ---
  [string]$ClientId = "5adca85e-5309-4f49-8c8d-044fccc637f0",
  [string]$TenantId = "38ac7b7f-65e1-4a2a-8e3a-7bbe18659ebe",
  [string]$CertificateThumbprint = "5C5F3A443D8232901E0E587E0E95762418C31670",
  [string]$CsvPath = "C:\echomediaai_scripts\M365_Roadmap_Sept2025.csv",
  [string]$OutputFolder = ".\MessageCenter_Export",
  [string]$MessageCenterAPI = "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/messages",

  # --- Fetch Filters (all optional) ---
  [Nullable[DateTime]]$FromDate = $null,
  [Nullable[DateTime]]$ToDate   = $null,
  [string[]]$Services           = $null,
  [ValidateSet('planForChange','preventOrFixIssue','stayInformed')]
  [string[]]$Categories         = $null,
  [ValidateSet('normal','high','critical')]
  [string[]]$Severities         = $null,
  [switch]$IsMajorChange,
  [string[]]$Tags               = $null,
  [switch]$OnlyUnread,
  [switch]$OnlyUnarchived,
  [string]$SearchTitle,

  # --- Output ---
  [ValidateSet('md','html','both')][string]$BriefingFormat = 'html',
  [string]$BriefingTitle    = "Microsoft 365 Technical Update Briefing",
  [string]$BriefingFileName = $null
)

# ===========================
# Utilities
# ===========================
function Ensure-OutputFolder {
  param([string]$Folder)
  if (-not (Test-Path -LiteralPath $Folder)) {
    New-Item -ItemType Directory -Path $Folder | Out-Null
  }
}


# --- Workload emoji map + safe HTML helper ---
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'System.Web' })) {
  Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue | Out-Null
}
function HtmlE { param($s) [System.Web.HttpUtility]::HtmlEncode([string]$s) }

# Map known services to emojis (fallback = 🧩)
$ServiceIconMap = @{
  'Microsoft 365 suite'       = '🧩'
  'Microsoft 365 apps'        = '📦'
  'Microsoft 365 for the web' = '🧩'
  'Microsoft Teams'           = '💬'
  'Exchange Online'           = '✉️'
  'SharePoint Online'         = '🧱'
  'Microsoft OneDrive'        = '☁️'
  'Microsoft Defender XDR'    = '🛡️'
  'Microsoft Entra'           = '🔐'
  'Microsoft Intune'          = '🧰'
  'Microsoft Purview'         = '🔎'
  'Planner'                   = '🗂️'
  'Dynamics 365 Apps'         = '🧩'
  'Windows'                   = '🪟'
  'Windows Autopatch'         = '🔄'
}

function Build-ServiceMarkup {
  param([string[]]$Services)

  if (-not $Services -or $Services.Count -eq 0) {
    return "<span class='chip alt'>Unspecified</span>"
  }

  # Ordered distinct (case-insensitive)
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $ordered = foreach ($s in $Services) {
    if ($s) {
      $t = $s.Trim()
      if ($t -and $seen.Add($t)) { $t }
    }
  }

  if (-not $ordered -or $ordered.Count -eq 0) {
    return "<span class='chip alt'>Unspecified</span>"
  }

  ($ordered | ForEach-Object {
    $icon = if ($ServiceIconMap.ContainsKey($_)) { $ServiceIconMap[$_] } else { '🧩' }
    "<span class='emoji'>$icon</span> <span class='chip alt'>$(HtmlE $_)</span>"
  }) -join ' '
}

function Build-ServiceText {
  param([string[]]$Services)
  if (-not $Services -or $Services.Count -eq 0) { return "Unspecified" }

  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $ordered = foreach ($s in $Services) {
    if ($s) { $t = $s.Trim(); if ($t -and $seen.Add($t)) { $t } }
  }
  if (-not $ordered -or $ordered.Count -eq 0) { return "Unspecified" }

  ($ordered | ForEach-Object {
    $icon = if ($ServiceIconMap.ContainsKey($_)) { $ServiceIconMap[$_] } else { '🧩' }
    "$icon $_"
  }) -join '  '
}


function SafeDate {
  param($d) if (-not $d) { return '' }
  try { (Get-Date -Date $d).ToString('yyyy-MM-dd') } catch { '' }
}

function CleanBodyToText {
  param([string]$html)
  if ([string]::IsNullOrWhiteSpace($html)) { return '' }
  $w = $html
  $w = [regex]::Replace($w, '(?is)<script.*?</script>', '')
  $w = [regex]::Replace($w, '(?is)<style.*?</style>', '')
  $w = [regex]::Replace($w, '(?i)<\s*br\s*/?>', "`n")
  $w = [regex]::Replace($w, '(?i)</\s*p\s*>', "`n")
  $w = [regex]::Replace($w, '(?is)<\s*li[^>]*>\s*', '• ')
  $w = [regex]::Replace($w, '(?i)</\s*li\s*>', "`n")
  $w = [regex]::Replace($w, '(?s)<[^>]+>', '')
  try { $w = [System.Web.HttpUtility]::HtmlDecode($w) } catch {}
  $w = $w -replace "`r",""
  Normalize-Glitches $w
}
function Get-SeverityEmoji {
  param([string]$sev)
  switch (($sev | ForEach-Object ToLower)) {
    'critical' { '🔴' }
    'high'     { '🟠' }
    default    { '🔵' }
  }
}

function Get-CategoryEmoji {
  param([string]$cat)
  switch (($cat | ForEach-Object ToLower)) {
    'planforchange'     { '📣' }
    'preventorfixissue' { '🛠️' }
    default             { 'ℹ️' }   # stayInformed or unknown
  }
}

function Get-ServiceEmoji {
  param([string]$svc)
  $s = ($svc -as [string])
  if ([string]::IsNullOrWhiteSpace($s)) { return '🧩' }
  $s = $s.ToLower()
  switch -regex ($s) {
    'teams'                 { '💬'; break }
    'windows autopatch'     { '🧭'; break }
    'windows'               { '🪟'; break }
    'exchange|outlook'      { '✉️'; break }
    'sharepoint'            { '🧱'; break }
    'onedrive'              { '☁️'; break }
    'intune'                { '🧰'; break }
    'purview'               { '🔍'; break }
    'defender|xdr'          { '🛡️'; break }
    'entra|azure ad'        { '🔐'; break }
    'viva'                  { '🧠'; break }
    'planner'               { '📅'; break }
    'microsoft 365 apps|office' { '📦'; break }
    default                 { '🧩' }
  }
}

# Robust section extractor for MC body HTML
function Extract-SectionsFromBody {
  param([string]$HtmlBody)
  $sections = @{}
  if ([string]::IsNullOrWhiteSpace($HtmlBody)) { return $sections }

  $text = $HtmlBody -replace '(?is)<script.*?</script>',''
  $text = $text -replace '(?is)<style.*?</style>',''
  $text = $text -replace '(?i)<\s*br\s*/?>',"`n"
  $text = $text -replace '(?i)</\s*p\s*>',"`n"
  $text = [regex]::Replace($text, '(?s)<[^>]+>', '')
  try { $text = [System.Web.HttpUtility]::HtmlDecode($text) } catch {}
  $text = $text -replace "`r",""
  $text = Normalize-Glitches $text

  # Header patterns
  $rxSummary = '(?im)^(summary|overview)\s*:?\s*$'
  $rxWhen    = '(?im)^(when(\s+this)?\s+will\s+happen|timeline)\s*:?\s*$'
  $rxAffect  = '(?im)^(how(\s+this|\s+will)?\s+affect\s+your\s+organization)\s*:?\s*$'
  $rxPrepare = '(?im)^(what\s+you\s+need\s+to\s+do(\s+to\s+prepare)?)\s*:?\s*$'
  $rxLearn   = '(?im)^(learn\s+more)\s*:?\s*$'

  function Get-Block([string]$content, [string]$headerPattern, [string[]]$allHeaders) {
    $m = [regex]::Match($content, $headerPattern)
    if (-not $m.Success) { return $null }
    $start = $m.Index + $m.Length
    $nextIdx = $content.Length
    foreach ($h in $allHeaders) {
      $n = [regex]::Match($content.Substring($start), $h)
      if ($n.Success) {
        $cand = $start + $n.Index
        if ($cand -lt $nextIdx) { $nextIdx = $cand }
      }
    }
    (Normalize-Glitches ($content.Substring($start, $nextIdx - $start))).Trim()
  }

  $all = @($rxSummary,$rxWhen,$rxAffect,$rxPrepare,$rxLearn)
  $sections['Summary']   = Get-Block $text $rxSummary $all
  $sections['When']      = Get-Block $text $rxWhen    $all
  $sections['Affect']    = Get-Block $text $rxAffect  $all
  $sections['Prepare']   = Get-Block $text $rxPrepare $all
  $sections['Learn']     = Get-Block $text $rxLearn   $all
  $sections
}

# Build a sentence-safe summary and a details body that excludes the summary
function Build-SummaryAndDetails {
  param(
    [string]$SummarySection,
    [string]$RawText,
    [hashtable]$Sections,
    [int]$MaxChars = 360
  )

  # Build a sentence-safe summary
  $source = if ($SummarySection -and $SummarySection.Trim()) { $SummarySection.Trim() } else { $RawText }
  $source = Normalize-Glitches $source
  $summaryUsed = ''
  if ([string]::IsNullOrWhiteSpace($source)) {
    $summaryOut = ''
  } else {
    $sentences = $source -split '(?<=[\.\!\?])\s+(?=[A-Z(])'
    $buf = ''
    foreach ($s in $sentences) {
      $next = if ($buf) { "$buf $s" } else { $s }
      if ($next.Length -le $MaxChars) {
        $buf = $next
      } else {
        if ($buf -eq '') {
          # Single long sentence; cut at word boundary and ellipsize
          $cut = $s.Substring(0, [Math]::Min($MaxChars, $s.Length))
          $cut = $cut -replace '\s+\S*$', ''
          $buf = $cut.Trim() + '…'
          $summaryUsed = $cut.Trim()
        }
        break
      }
    }
    if ($buf -eq '') { $buf = $source.Substring(0, [Math]::Min($MaxChars, $source.Length)) }
    $summaryOut = (Normalize-Glitches $buf).Trim()
    if (-not $summaryUsed) { $summaryUsed = $summaryOut }
  }

  # Do NOT include structured sections in "Full details"
  $keys = @('When','Affect','Prepare','Learn')
  $hasStructured = $false
  foreach ($k in $keys) {
    if ($Sections.ContainsKey($k) -and $Sections[$k]) { $hasStructured = $true; break }
  }
  if ($hasStructured) {
    return @{ SummaryText = $summaryOut; DetailsText = '' }
  }

  # Otherwise, include remaining raw text minus the summary snippet (if it starts with it)
  $raw = Normalize-Glitches $RawText
  if ($summaryUsed) {
    $pattern = '^' + [regex]::Escape($summaryUsed)
    $raw = [regex]::Replace($raw, $pattern, '', 'IgnoreCase')
  }
  @{ SummaryText = $summaryOut; DetailsText = (Normalize-Glitches $raw).Trim() }
}

function Ensure-GraphModule {
  # Make sure the Graph SDK is present enough for Connect-MgGraph + Invoke-MgGraphRequest
  $needed = @('Microsoft.Graph.Authentication','Microsoft.Graph')
  foreach ($n in $needed) {
    if (-not (Get-Module -ListAvailable -Name $n)) {
      try {
        Install-Module $n -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
      } catch {
        Write-Warning "Could not install $n automatically. You may need: Install-Module $n -Scope CurrentUser"
      }
    }
  }
  Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
  # Import the umbrella module if available (not strictly required in newer SDKs)
  Import-Module Microsoft.Graph -ErrorAction SilentlyContinue | Out-Null
}

function Normalize-Glitches {
  param([string]$s)
  if ([string]::IsNullOrWhiteSpace($s)) { return $s }
  $t = $s
  # Decode common entities
  try {
    if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'System.Web' })) {
      Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue | Out-Null
    }
    $t = [System.Web.HttpUtility]::HtmlDecode($t)
  } catch {}
  # NBSP → normal space (handle both actual NBSP and literal &nbsp;)
  $t = $t -replace '\xA0', ' '
  $t = $t -replace '&nbsp;', ' '

  # Stray bracket artifacts
  $t = $t -replace '(?m)^\s*\]\s*', ''             # leading ']' at line start
  $t = $t -replace ':\]', ':'                      # fix "something:]"
  $t = $t -replace '(?i)your organization:\]', 'your organization:'  # extra-safe for the common case

  # Minor grammar cleanups we’ve seen
  $t = $t -replace '(?i)\byou organization\b', 'your organization'

  # Whitespace tidy
  $t = $t -replace '[ \t]{2,}', ' '
  $t = $t -replace '(\n){3,}', "`n`n"
  $t.Trim()
}


function Connect-GraphWithCert {
  param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ClientId,
    [Parameter(Mandatory)][string]$CertificateThumbprint
  )
  Write-Host "Connecting to Microsoft Graph (app-only cert auth)..." -ForegroundColor Cyan
  Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome | Out-Null

  # Some environments don’t ship Select-MgProfile; we don’t rely on it because our URIs use /v1.0/
  if (Get-Command Select-MgProfile -ErrorAction SilentlyContinue) {
    Select-MgProfile -Name 'v1.0'
  }

  # Sanity check for Invoke-MgGraphRequest presence
  if (-not (Get-Command Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
    throw "Invoke-MgGraphRequest not found. Ensure Microsoft.Graph or Microsoft.Graph.Authentication is installed and imported."
  }

  Write-Host "Connected. Tenant=$TenantId AppId=$ClientId" -ForegroundColor Green
}


function Resolve-MessageCenterBaseUri {
  param([string]$BaseApi)
  if ([string]::IsNullOrWhiteSpace($BaseApi)) {
    return 'https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/messages'
  }
  $u = $BaseApi.Trim().TrimEnd('/')

  if ($u -match '^https://graph\.microsoft\.com/?$') {
    return 'https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/messages'
  }
  if ($u -notmatch '/(v1\.0|beta)/') {
    return 'https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/messages'
  }
  if ($u -notmatch '/admin/serviceAnnouncement/messages$') {
    return $u + '/admin/serviceAnnouncement/messages'
  }
  return $u
}

function Build-QueryUri {
  param([string]$Base, [string[]]$QueryParts)
  $q = ($QueryParts | Where-Object { $_ -and $_.Trim() }) -join '&'
  if ($Base -match '\?$')     { return $Base + $q }
  if ($Base -match '\?.+')    { return $Base + '&' + $q }
  return $Base + '?' + $q
}

function Invoke-GraphGet {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Uri)

  $maxRetries = 6
  for ($retry = 0; $retry -lt $maxRetries; $retry++) {
    try {
      # Use MgGraph built-in request (auth context already set)
      $res = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
      return $res
    } catch {
      $msg = $_.Exception.Message
      $status = $null
      if ($msg -match '\((\d{3})\)') { $status = [int]$matches[1] }

      # Retry on 429 or transient 5xx
      if ($status -in 429,500,502,503,504 -or $msg -match 'Too Many Requests') {
        $delay = [math]::Min([math]::Pow(2, $retry), 30)
        if (-not $delay -or $delay -le 0) { $delay = [math]::Min([math]::Pow(2, $retry), 30) }
        Write-Warning "Graph transient error ($status). Retrying in $delay sec..."
        Start-Sleep -Seconds $delay
        continue
      }
      throw
    }
  }
  throw "Invoke-GraphGet: exceeded retry attempts for $Uri"
}

# ===========================
# Fetch + Refine
# ===========================
function Get-MessageCenterMessages {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$BaseApi,
    [Nullable[DateTime]]$FromDate,
    [string[]]$Services,
    [ValidateSet('planForChange','preventOrFixIssue','stayInformed')] [string[]]$Categories,
    [ValidateSet('normal','high','critical')] [string[]]$Severities,
    [switch]$IsMajorChange,
    [ValidateRange(1,999)][int]$Top = 100
  )

  # Never reassign validated param variables; copy to locals
  $svc = if ($Services)   { @($Services   | Where-Object { $_ -and $_.Trim() }) } else { $null }
  $cat = if ($Categories) { @($Categories | Where-Object { $_ -and $_.Trim() }) } else { $null }
  $sev = if ($Severities) { @($Severities | Where-Object { $_ -and $_.Trim() }) } else { $null }

  $base = Resolve-MessageCenterBaseUri $BaseApi

  # fields we need for rendering/filters
  $selectFields = @(
    'id','title','category','severity','isMajorChange','services','tags','viewPoint',
    'lastModifiedDateTime','startDateTime','endDateTime','actionRequiredByDateTime',
    'body','details'
  )

  $qs = @()
  $qs += ('$select=' + ($selectFields -join ','))
  $qs += '$orderby=lastModifiedDateTime desc'
  $qs += ('$top=' + $Top)

  $filters = @()
  if ($FromDate) {
    $iso = (Get-Date $FromDate -Format "yyyy-MM-ddTHH:mm:ssZ")
    $filters += "lastModifiedDateTime ge $iso"
  }
  if ($cat) {
    $filters += '(' + (($cat | ForEach-Object { "category eq '$_'" }) -join ' or ') + ')'
  }
  if ($sev) {
    $filters += '(' + (($sev | ForEach-Object { "severity eq '$_'" }) -join ' or ') + ')'
  }
  if ($IsMajorChange) {
    $filters += 'isMajorChange eq true'
  }
  if ($svc) {
    # services is a collection<string>; use any()
    $filters += '(' + (($svc | ForEach-Object { "services/any(s:s eq '$_')" }) -join ' or ') + ')'
  }
  if ($filters.Count) { $qs += ('$filter=' + ($filters -join ' and ')) }

  $uri = Build-QueryUri -Base $base -QueryParts $qs
  Write-Verbose "GET $uri"

  $all = @()
  $next = $uri
  $guard = 0
  while ($next -and $guard -lt 50) {
    $guard++
    $resp = Invoke-GraphGet -Uri $next
    if (-not $resp) {
      Write-Warning "Empty response body for $next"
      break
    }

    if ($resp.PSObject.Properties.Name -contains 'value') {
      if ($resp.value -is [array]) { $all += $resp.value }
      elseif ($resp.value) { $all += ,$resp.value }
    }

    $next = $null
    if ($resp.PSObject.Properties.Name -contains '@odata.nextLink') {
      $next = $resp.'@odata.nextLink'
    }
  }

  if ($all.Count -gt $Top) { $all = $all | Select-Object -First $Top }
  return $all
}

function Refine-Messages {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][array]$Messages,
    [Nullable[DateTime]]$ToDate,
    [string[]]$Tags,
    [switch]$OnlyUnread,
    [switch]$OnlyUnarchived,
    [string]$SearchTitle
  )

  $items = $Messages

  if ($ToDate) {
    $items = $items | Where-Object { $_.lastModifiedDateTime -le $ToDate }
  }
  if ($Tags) {
    $wanted = @($Tags | Where-Object { $_ -and $_.Trim() })
    if ($wanted.Count -gt 0) {
      $items = $items | Where-Object { $_.tags -and (($_.tags | ForEach-Object { $_.ToString().ToLower() }) | Where-Object { $wanted -contains $_ }) }
    }
  }
  if ($OnlyUnread) {
    $items = $items | Where-Object { $_.viewPoint -and ($_.viewPoint.isRead -eq $false) }
  }
  if ($OnlyUnarchived) {
    $items = $items | Where-Object { $_.viewPoint -and ($_.viewPoint.isArchived -eq $false) }
  }
  if ($SearchTitle) {
    $needle = $SearchTitle.ToLower()
    $items = $items | Where-Object { $_.title -and $_.title.ToLower().Contains($needle) }
  }

  # De-dupe by id
  $items = $items | Sort-Object id -Unique
  return ,$items
}

# ===========================
# Section Extraction (robust, PS 5.1 friendly)
# ===========================
function Extract-SectionsFromBody {
  [CmdletBinding()]
  param([string]$HtmlBody)

  $sections = @{}
  if ([string]::IsNullOrWhiteSpace($HtmlBody)) { return $sections }

  $work = $HtmlBody
  $work = [regex]::Replace($work, '(?is)<script.*?</script>', '')
  $work = [regex]::Replace($work, '(?is)<style.*?</style>', '')
  $work = [regex]::Replace($work, '(?i)<\s*br\s*/?>', "`n")
  $work = [regex]::Replace($work, '(?i)</\s*p\s*>', "`n")
  $work = [regex]::Replace($work, '(?i)</\s*h[1-6]\s*>', "`n")
  $work = [regex]::Replace($work, '(?is)<\s*li[^>]*>\s*', '• ')
  $work = [regex]::Replace($work, '(?i)</\s*li\s*>', "`n")
  $work = [regex]::Replace($work, '(?s)<[^>]+>', '')

  if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'System.Web' })) {
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue | Out-Null
  }
  if ([type]::GetType('System.Web.HttpUtility')) {
    $work = [System.Web.HttpUtility]::HtmlDecode($work)
  }

  $work = $work -replace "`r",""
  $work = [regex]::Replace($work, "[ \t]{2,}", " ")
  $work = [regex]::Replace($work, "(\n){3,}", "`n`n")
  $work = $work.Trim()

  $defs = @(
    @{ Key='Summary';   Pattern='(?i)^\s*(?:\[\s*)?(summary|overview|introduction)(?:\s*\])?\s*:?\s*$' },
    @{ Key='When';      Pattern='(?i)^\s*(?:\[\s*)?(?:when\s+will\s+(?:this|it)\s+happen|when\s+(?:this|it)\s+will\s+happen|timeline|timing|key\s+dates|rollout(?:\s+schedule)?)(?:\s*\])?\s*:?\s*$' },
    @{ Key='Affect';    Pattern='(?i)^\s*(?:\[\s*)?(?:how\s+(?:this|it)\s+will\s+affect|how\s+will\s+(?:this|it)\s+affect|impact|user\s+impact|org(?:anization)?\s+impact)(?:\s*\])?\s*:?\s*$' },
    @{ Key='Prepare';   Pattern='(?i)^\s*(?:\[\s*)?(?:what\s+you\s+need\s+to\s+do(?:\s+to\s+prepare)?|prepare|preparation|admin\s+actions?|actions?\s+required|next\s+steps|recommended\s+actions?)(?:\s*\])?\s*:?\s*$' },
    @{ Key='Compliance';Pattern='(?i)^\s*(?:\[\s*)?(?:compliance\s+considerations?)(?:\s*\])?\s*:?\s*$' },
    @{ Key='Learn';     Pattern='(?i)^\s*(?:\[\s*)?(?:learn\s+more|additional\s+information|resources)(?:\s*\])?\s*:?\s*$' }
  )

  $rx = @()
  foreach ($d in $defs) {
    $start = [regex]$d.Pattern
    $inlinePat = ($d.Pattern -replace '\$\s*$', '') + '\s*:?\s*(.+)$'
    $inline = [regex]$inlinePat
    $rx += [pscustomobject]@{ Key=$d.Key; Start=$start; Inline=$inline }
  }

  $buffers = @{
    Summary    = New-Object System.Collections.Generic.List[string]
    When       = New-Object System.Collections.Generic.List[string]
    Affect     = New-Object System.Collections.Generic.List[string]
    Prepare    = New-Object System.Collections.Generic.List[string]
    Compliance = New-Object System.Collections.Generic.List[string]
    Learn      = New-Object System.Collections.Generic.List[string]
  }

  $current = $null
  foreach ($raw in ($work -split "`n")) {
    $line = $raw.Trim()
    if ($line -eq '') { continue }

    $matched = $false

    foreach ($r in $rx) {
      if ($r.Start.IsMatch($line)) { $current = $r.Key; $matched = $true; break }
    }
    if ($matched) { continue }

    foreach ($r in $rx) {
      $m = $r.Inline.Match($line)
      if ($m.Success) {
        $current = $r.Key
        $rest = $m.Groups[1].Value.Trim()
        if ($rest) { [void]$buffers[$current].Add($rest) }
        $matched = $true
        break
      }
    }
    if ($matched) { continue }

    if (-not $current) { $current = 'Summary' }
    [void]$buffers[$current].Add($line)
  }

  foreach ($k in $buffers.Keys) {
    if ($buffers[$k].Count -gt 0) {
      $val = ($buffers[$k] -join "`n")
      $val = ($val -replace "[ \t]{2,}", " ").Trim()
      $sections[$k] = $val
    }
  }
  return $sections
}

# ===========================
# Briefing Generators
# ===========================
function New-BriefingMarkdown {
  [CmdletBinding()]
  param(
    [array]$Messages,
    [string]$Title,
    [string]$OutputFolder,
    [string]$FileName
  )

  Ensure-OutputFolder -Folder $OutputFolder
  if (-not $FileName) { $FileName = "Briefing_" + (Get-Date).ToString('yyyyMMdd-HHmmss') }
  $mdPath = Join-Path $OutputFolder ($FileName + '.md')

  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("# $Title")
  [void]$sb.AppendLine()
  [void]$sb.AppendLine("_Generated: $(Get-Date -Format 'yyyy-MM-dd')_")
  [void]$sb.AppendLine()

  # Group by service for MD (readability)
  $groups = $Messages | ForEach-Object {
    if ($_.services -and $_.services.Count -gt 0) {
      foreach ($svc in $_.services) { [pscustomobject]@{ Service=$svc; Item=$_ } }
    } else { [pscustomobject]@{ Service='Unspecified'; Item=$_ } }
  } | Group-Object Service | Sort-Object Name

  foreach ($g in $groups) {
    [void]$sb.AppendLine("## $($g.Name)")
    [void]$sb.AppendLine()

    foreach ($row in $g.Group) {
      $m = $row.Item
      $sev = if ($m.severity) { $m.severity.ToLower() } else { 'normal' }
      $sevEmoji = Get-SeverityEmoji $sev
      $catEmoji = Get-CategoryEmoji $m.category

      $sections = Extract-SectionsFromBody -HtmlBody $m.body.content
      if (-not $sections['Summary'] -and $m.details) {
        $sum = ($m.details | Where-Object { $_.name -match 'summary' } | Select-Object -First 1).value
        if ($sum) { $sections['Summary'] = $sum }
      }

      $raw = CleanBodyToText $m.body.content
      $built = Build-SummaryAndDetails -SummarySection $sections['Summary'] -RawText $raw -Sections $sections -MaxChars 360
      $summaryText = $built['SummaryText']
      $detailsText = $built['DetailsText']

      $svcText = Build-ServiceText -Services $m.services
      $tagsText = if ($m.tags) { ($m.tags -join ", ") } else { $null }

      [void]$sb.AppendLine("### $($m.title)")
      [void]$sb.AppendLine("- **Category:** $catEmoji $($m.category)  •  **Severity:** $sevEmoji $($m.severity)  •  **Services:** $svcText")
      if ($tagsText) { [void]$sb.AppendLine("- **Tags:** $tagsText") }

      $d1 = SafeDate $m.lastModifiedDateTime
      $d2 = SafeDate $m.startDateTime
      $d3 = SafeDate $m.endDateTime
      $dates = @()
      if ($d1) { $dates += "Last updated $d1" }
      if ($d2) { $dates += "Rollout start $d2" }
      if ($d3) { $dates += "Rollout end $d3" }
      if ($dates.Count -gt 0) { [void]$sb.AppendLine("- **Dates:** " + ($dates -join " • ")) }
      if ($m.actionRequiredByDateTime) { [void]$sb.AppendLine("- **Action by:** " + (SafeDate $m.actionRequiredByDateTime)) }
      if ($m.id) { [void]$sb.AppendLine("- **Message ID:** " + $m.id) }

      if ($summaryText) { [void]$sb.AppendLine("- **Summary:** " + (Normalize-Glitches $summaryText)) }

      if ($sections['When']) {
        [void]$sb.AppendLine("<details><summary><b>When will this happen?</b></summary>")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine((Normalize-Glitches $sections['When']))
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("</details>")
      }
      if ($sections['Affect']) {
        [void]$sb.AppendLine("<details><summary><b>How will this affect your organization?</b></summary>")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine((Normalize-Glitches $sections['Affect']))
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("</details>")
      }
      if ($sections['Prepare']) {
        [void]$sb.AppendLine("<details><summary><b>What you need to do to prepare</b></summary>")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine((Normalize-Glitches $sections['Prepare']))
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("</details>")
      }
      if ($sections['Learn']) {
        [void]$sb.AppendLine("<details><summary><b>Learn more</b></summary>")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine((Normalize-Glitches $sections['Learn']))
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("</details>")
      }

      if ($detailsText) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("<details><summary><b>Full details</b></summary>")
        foreach ($p in ((Normalize-Glitches $detailsText) -split "`n`n")) {
          $t = $p.Trim()
          if ($t) { [void]$sb.AppendLine($t); [void]$sb.AppendLine() }
        }
        [void]$sb.AppendLine("</details>")
      }

      [void]$sb.AppendLine()
    }
  }

  $sb.ToString() | Out-File -FilePath $mdPath -Encoding UTF8
  Write-Host "Saved Markdown briefing: $mdPath" -ForegroundColor Green
  return $mdPath
}



function New-BriefingHtml {
  [CmdletBinding()]
  param(
    [array]$Messages,
    [string]$Title,
    [string]$OutputFolder,
    [string]$FileName,
    [ValidateSet('Service','Severity')][string]$GroupBy='Service',
    [int]$MaxDetailsChars = 360,        # sentence-safe summary cap
    [switch]$ShowSections = $true,
    [switch]$ShowRawDetails = $true
  )

  Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue | Out-Null
  Ensure-OutputFolder -Folder $OutputFolder
  if (-not $FileName) { $FileName = "Briefing_" + (Get-Date).ToString('yyyyMMdd-HHmmss') }
  $htmlPath = Join-Path $OutputFolder ($FileName + '.html')

  $date     = (Get-Date).ToString('yyyy-MM-dd')
  $total    = $Messages.Count
  $maj      = ($Messages | Where-Object {$_.isMajorChange}).Count
  $highCrit = ($Messages | Where-Object { $_.severity -in @('high','critical') }).Count

  if ($GroupBy -eq 'Service') {
    # One group per service (ordered distinct per message), fallback to 'Unspecified'
    $groups = $Messages | ForEach-Object {
      if ($_.services -and $_.services.Count -gt 0) {
        foreach ($svc in $_.services) { [pscustomobject]@{ Name=$svc; Item=$_ } }
      } else {
        [pscustomobject]@{ Name='Unspecified'; Item=$_ }
      }
    } | Group-Object Name | Sort-Object Name
  } else {
    # One group per severity (critical/high/normal), fallback to 'normal'
    $groups = $Messages | ForEach-Object {
      $sev = if ($_.severity) { $_.severity } else { 'normal' }
      [pscustomobject]@{ Name=$sev; Item=$_ }
    } | Group-Object Name | Sort-Object Name
  }

  $style = @'
    :root{
      --accent:#2563eb; --critical:#dc2626; --high:#d97706; --normal:#3b82f6;
      --bg:#0b1020; --card:#121735; --text:#e6e8ef; --muted:#a7b0c2; --chip:#243b74;
    }
    *{box-sizing:border-box}
    body{margin:0;font-family:Segoe UI,Arial,sans-serif;color:var(--text);background:linear-gradient(180deg,#0b1020 0%,#0e1734 100%)}
    a{color:var(--accent);text-decoration:none}
    .wrap{max-width:1200px;margin:0 auto;padding:24px}
    .hero{background:radial-gradient(1200px 400px at 20% -20%, rgba(37,99,235,.35), transparent 50%),
                  radial-gradient(1200px 400px at 100% 0%, rgba(16,185,129,.2), transparent 55%),
                  linear-gradient(90deg, rgba(255,255,255,.04), rgba(255,255,255,0));
           border-bottom:1px solid rgba(255,255,255,.06); padding:18px 24px;}
    .hero-inner{max-width:1200px;margin:0 auto;display:flex;align-items:center;gap:14px}
    .logo{width:36px;height:36px;border-radius:10px;background:#0c1330;display:flex;align-items:center;justify-content:center;overflow:hidden;border:1px solid rgba(255,255,255,.08)}
    .title{font-weight:700;font-size:20px;letter-spacing:.2px}
    .subtitle{color:var(--muted);font-size:12.5px;margin-top:2px}
    .meta{color:var(--muted);margin:14px 0 18px;font-size:13px}
    .stat{display:inline-block;padding:2px 8px;border-radius:999px;background:rgba(255,255,255,.06);margin-right:6px}
    h2{margin:28px 0 12px;font-size:18px;letter-spacing:.2px}
    .toc{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:8px;margin:12px 0 20px}
    .toc a{display:block;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.08);padding:8px 10px;border-radius:10px}
    .card{background:var(--card);border:1px solid rgba(255,255,255,.08);border-left:6px solid var(--accent);border-radius:14px;padding:14px 16px;margin:12px 0;box-shadow:0 6px 14px rgba(0,0,0,.18)}
    .card.sev-critical{border-left-color:var(--critical)} .card.sev-high{border-left-color:var(--high)} .card.sev-normal{border-left-color:var(--normal)}
    .line{display:flex;align-items:center;gap:8px;margin:6px 0 4px;flex-wrap:wrap}
    .chip{display:inline-block;background:var(--chip);border:1px solid rgba(255,255,255,.12);border-radius:999px;padding:2px 10px;font-size:12px}
    .chip.alt{background:rgba(255,255,255,.06)}
    .badge{display:inline-block;border-radius:999px;padding:2px 8px;font-size:12px;border:1px solid rgba(255,255,255,.12)}
    .sev-badge.critical{background:rgba(220,38,38,.15)} .sev-badge.high{background:rgba(217,119,6,.15)} .sev-badge.normal{background:rgba(59,130,246,.15)}
    .emoji{font-family:"Segoe UI Emoji","Apple Color Emoji","Noto Color Emoji",sans-serif;font-size:16px;line-height:1}
    .tag{display:inline-block;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.08);border-radius:6px;padding:2px 8px;margin-right:6px;margin-top:4px;font-size:12px}
    .dates{color:var(--muted);font-size:12.5px;margin-top:6px}
    .section{margin-top:8px} .label{font-weight:700}
    details{margin-top:8px;border:1px dashed rgba(255,255,255,.18);border-radius:10px;padding:8px 10px;background:rgba(255,255,255,.03)}
    summary{cursor:pointer;user-select:none}
'@

  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("<html><head><meta charset='utf-8'><title>$Title</title><style>$style</style></head><body>")
  [void]$sb.AppendLine("<div class='hero'><div class='hero-inner'><div class='logo'><span class='emoji'>🧭</span></div><div><div class='title'>$(HtmlE $Title)</div><div class='subtitle'>Generated $date</div></div></div></div>")
  [void]$sb.AppendLine("<div class='wrap'>")
  [void]$sb.AppendLine("<div class='meta'><span class='stat'>Total: $total</span><span class='stat'>Major: $maj</span><span class='stat'>High/Critical: $highCrit</span><span class='stat'>Grouped by: $GroupBy</span></div>")

  # TOC
  [void]$sb.AppendLine("<div class='toc'>")
  foreach ($g in $groups) {
    $name = $g.Name; $id = ($name -replace '[^a-zA-Z0-9]+','-').ToLower().Trim('-')
    [void]$sb.AppendLine("<a href='#$id'>$(HtmlE $name)</a>")
  }
  [void]$sb.AppendLine("</div>")

  foreach ($g in $groups) {
    $name = $g.Name; $id = ($name -replace '[^a-zA-Z0-9]+','-').ToLower().Trim('-')
    [void]$sb.AppendLine("<h2 id='$id'>$(HtmlE $name)</h2>")

    foreach ($row in $g.Group) {
      $m = $row.Item
      $sev = ($m.severity ? $m.severity.ToLower() : 'normal')
      if ($sev -notin @('critical','high','normal')) { $sev = 'normal' }
      $sevEmoji = Get-SeverityEmoji $sev
      $catEmoji = Get-CategoryEmoji $m.category

      $sections = Extract-SectionsFromBody -HtmlBody $m.body.content
      if (-not $sections['Summary'] -and $m.details) {
        $sum = ($m.details | Where-Object { $_.name -match 'summary' } | Select-Object -First 1).value
        if ($sum) { $sections['Summary'] = $sum }
      }

      $raw = CleanBodyToText $m.body.content
      $built = Build-SummaryAndDetails -SummarySection $sections['Summary'] -RawText $raw -Sections $sections -MaxChars $MaxDetailsChars
      $summaryText = $built['SummaryText']
      $detailsText = $built['DetailsText']

      $tagsHtml = if ($m.tags) { ($m.tags | ForEach-Object { "<span class='tag'>$(HtmlE $_)</span>" }) -join '' } else { '' }
      $svcHtml = Build-ServiceMarkup -Services $m.services

      [void]$sb.AppendLine("<div class='card sev-$sev'>")
      [void]$sb.AppendLine("<h4>$(HtmlE $m.title)</h4>")
      [void]$sb.AppendLine("<div class='line'><span class='emoji'>$sevEmoji</span><span class='badge sev-badge $sev'>$(HtmlE $m.severity)</span> <span class='emoji'>$catEmoji</span><span class='chip'>$(HtmlE $m.category)</span> $svcHtml</div>")
      if ($tagsHtml) { [void]$sb.AppendLine("<div>$tagsHtml</div>") }

      $dates = @()
      $d1 = SafeDate $m.lastModifiedDateTime; if ($d1) { $dates += "Last updated $d1" }
      $d2 = SafeDate $m.startDateTime;       if ($d2) { $dates += "Rollout start $d2" }
      $d3 = SafeDate $m.endDateTime;         if ($d3) { $dates += "Rollout end $d3" }
      if ($dates.Count -gt 0) { [void]$sb.AppendLine("<div class='dates'><b>Dates:</b> " + ($dates -join " &middot; ") + "</div>") }
      $actionBy = SafeDate $m.actionRequiredByDateTime
      if ($actionBy) { [void]$sb.AppendLine("<div class='dates'><b>Action by:</b> $actionBy</div>") }
      if ($m.id) { [void]$sb.AppendLine("<div class='dates'><b>Message ID:</b> $(HtmlE $m.id)</div>") }

      if ($ShowSections) {
        if ($summaryText) { [void]$sb.AppendLine("<div class='section'><span class='label'>Summary:</span> $(HtmlE (Normalize-Glitches $summaryText))</div>") }
        if ($sections['When']) {
          [void]$sb.AppendLine("<details class='exp-section'><summary><b>When will this happen?</b></summary><div style='margin-top:6px'>$(HtmlE (Normalize-Glitches $sections['When']))</div></details>")
        }
        if ($sections['Affect']) {
          [void]$sb.AppendLine("<details class='exp-section'><summary><b>How will this affect your organization?</b></summary><div style='margin-top:6px'>$(HtmlE (Normalize-Glitches $sections['Affect']))</div></details>")
        }
        if ($sections['Prepare']) {
          [void]$sb.AppendLine("<details class='exp-section'><summary><b>What you need to do to prepare</b></summary><div style='margin-top:6px'>$(HtmlE (Normalize-Glitches $sections['Prepare']))</div></details>")
        }
        if ($sections['Learn']) {
          [void]$sb.AppendLine("<details class='exp-section'><summary><b>Learn more</b></summary><div style='margin-top:6px'>$(HtmlE (Normalize-Glitches $sections['Learn']))</div></details>")
        }
      }

      if ($ShowRawDetails -and $detailsText) {
        [void]$sb.AppendLine("<details><summary><b>Full details</b></summary><div style='margin-top:6px'>$(HtmlE (Normalize-Glitches $detailsText))</div></details>")
      }

      [void]$sb.AppendLine("</div>") # /card
    }
  }

  [void]$sb.AppendLine("</div></body></html>")
  $sb.ToString() | Out-File -FilePath $htmlPath -Encoding UTF8
  Write-Host "Saved HTML briefing: $htmlPath" -ForegroundColor Green
  return $htmlPath
}


# ===========================
# MAIN
# ===========================
try {
  Ensure-OutputFolder -Folder $OutputFolder
  Ensure-GraphModule
  Connect-GraphWithCert -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint

  # Build fetch parameters WITHOUT reassigning validated script params
  $fetchParams = @{
    BaseApi = $MessageCenterAPI
    Top     = 100
  }
  if ($FromDate)   { $fetchParams.FromDate   = $FromDate }
  if ($Services)   { $fetchParams.Services   = @($Services   | Where-Object { $_ -and $_.Trim() }) }
  if ($Categories) { $fetchParams.Categories = @($Categories | Where-Object { $_ -and $_.Trim() }) }
  if ($Severities) { $fetchParams.Severities = @($Severities | Where-Object { $_ -and $_.Trim() }) }
  if ($IsMajorChange) { $fetchParams.IsMajorChange = $true }

  $messages = Get-MessageCenterMessages @fetchParams

  # Client-side refinements
  $refineParams = @{ Messages = $messages }
  if ($ToDate)         { $refineParams.ToDate         = $ToDate }
  if ($Tags)           { $refineParams.Tags           = $Tags }
  if ($OnlyUnread)     { $refineParams.OnlyUnread     = $true }
  if ($OnlyUnarchived) { $refineParams.OnlyUnarchived = $true }
  if ($SearchTitle)    { $refineParams.SearchTitle    = $SearchTitle }

  $refined = Refine-Messages @refineParams

  if (-not $refined -or $refined.Count -eq 0) {
    Write-Warning "No Message Center items matched filters."
  }

  $briefBaseName = if ($BriefingFileName) { $BriefingFileName } else { "Briefing_" + (Get-Date).ToString('yyyyMMdd-HHmmss') }
  switch ($BriefingFormat) {
    'md'   { New-BriefingMarkdown -Messages $refined -Title $BriefingTitle -OutputFolder $OutputFolder -FileName $briefBaseName }
    'html' { New-BriefingHtml     -Messages $refined -Title $BriefingTitle -OutputFolder $OutputFolder -FileName $briefBaseName }
    'both' { 
      New-BriefingMarkdown -Messages $refined -Title $BriefingTitle -OutputFolder $OutputFolder -FileName $briefBaseName | Out-Null
      New-BriefingHtml     -Messages $refined -Title $BriefingTitle -OutputFolder $OutputFolder -FileName $briefBaseName
    }
  }
}
catch {
  Write-Error $_
}
finally {
  try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
}
