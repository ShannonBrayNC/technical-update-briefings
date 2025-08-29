# --- 0) Point to the module
$mod = 'C:\M365 Roadmap Components\Modules\M365.RoadmapStyled\M365.RoadmapStyled.psm1'

# --- 1) Backup
$bak = "$mod.bak_{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item $mod $bak -Force
Write-Host "Backup saved to: $bak"

# --- 2) Append a corrected Filter-RoadmapItems (this overrides the old definition)
$fix = @'
# ==== patched on {PATCHED} ====
function Filter-RoadmapItems {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [object[]] $Items,

    [string[]] $Products,
    [string[]] $Platforms,
    [string[]] $CloudInstances,
    [string[]] $ReleasePhase,
    [string[]] $Status,
    [string]   $Text,

    [datetime] $UpdatedSince,
    [datetime] $CreatedSince,

    # Correct types — single DateTime values, nullable by omission
    [datetime] $GAFrom,
    [datetime] $GATo
  )

  # local helpers so we don't depend on other module functions
  function _list($x){ if($null -eq $x){ @() } elseif($x -is [string]){ @($x) } else { @($x) } }
  function _norm($x){ (_list $x) | ForEach-Object { $_.ToString().Trim() } }
  function _lower($x){ (_norm $x) | ForEach-Object { $_.ToLowerInvariant() } }

  function _toDate([object]$v){
    # prefer module helper if present
    $cf = Get-Command -Name ConvertFrom-RoadmapDate -ErrorAction SilentlyContinue
    if($cf){ return ConvertFrom-RoadmapDate $v }
    if([string]::IsNullOrWhiteSpace([string]$v)){ return $null }
    $s = [string]$v

    # "September CY2025"
    if($s -match '^(?<mon>[A-Za-z]+)\s+CY(?<y>\d{4})$'){
      $m = [datetime]::ParseExact($Matches.mon,'MMMM',[Globalization.CultureInfo]::InvariantCulture).Month
      return Get-Date -Year $Matches.y -Month $m -Day 1
    }
    # "Q3 CY2025" -> first month of quarter
    if($s -match '^Q(?<q>[1-4])\s+CY(?<y>\d{4})$'){
      $startMonth = 1 + ([int]$Matches.q - 1) * 3
      return Get-Date -Year $Matches.y -Month $startMonth -Day 1
    }
    $dt = $null
    if([datetime]::TryParse($s, [ref]$dt)){ return $dt }
    return $null
  }

  $data = @($Items)

  if($Products){
    $want = _lower $Products
    $data = $data | Where-Object {
      (_lower ($_.products)) | Where-Object { $want -contains $_ } | Measure-Object | Select-Object -ExpandProperty Count
    }
  }

  if($Platforms){
    $want = _lower $Platforms
    $data = $data | Where-Object {
      (_lower ($_.platforms)) | Where-Object { $want -contains $_ } | Measure-Object | Select-Object -ExpandProperty Count
    }
  }

  if($CloudInstances){
    $want = _lower $CloudInstances
    $data = $data | Where-Object {
      (_lower ($_.clouds)) | Where-Object { $want -contains $_ } | Measure-Object | Select-Object -ExpandProperty Count
    }
  }

  if($ReleasePhase){
    $want = _lower $ReleasePhase
    $data = $data | Where-Object {
      (_lower ($_.phases)) | Where-Object { $want -contains $_ } | Measure-Object | Select-Object -ExpandProperty Count
    }
  }

  if($Status){
    $want = _lower $Status
    $data = $data | Where-Object {
      $s = $_.status
      if($null -eq $s){ $false } else { $want -contains $s.ToString().ToLowerInvariant() }
    }
  }

  if($UpdatedSince){
    $data = $data | Where-Object {
      $d = _toDate $_.modified
      $d -and $d -ge $UpdatedSince
    }
  }

  if($CreatedSince){
    $data = $data | Where-Object {
      $d = _toDate $_.created
      $d -and $d -ge $CreatedSince
    }
  }

  if($GAFrom -or $GATo){
    $from = if($GAFrom){ $GAFrom } else { [datetime]::MinValue }
    $to   = if($GATo){   $GATo   } else { [datetime]::MaxValue }
    $data = $data | Where-Object {
      $ga = _toDate $_.generalAvailability
      $ga -and $ga -ge $from -and $ga -le $to
    }
  }

  if($Text){
    $needle = $Text.ToLowerInvariant()
    $data = $data | Where-Object {
      $hay = @(
        $_.id, $_.title, $_.description,
        (_list $_.products)  -join ' ',
        (_list $_.platforms) -join ' ',
        (_list $_.clouds)    -join ' ',
        (_list $_.phases)    -join ' '
      ) -join ' '
      $hay.ToLowerInvariant().Contains($needle)
    }
  }

  ,@($data)  # return array even for 0/1 items
}
# ==== end patched ====
'@ -replace '\{PATCHED\}', (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Add-Content -Path $mod -Value "`r`n$fix`r`n" -Encoding UTF8

# --- 3) Clean re-import (tiny pause avoids remove/import race)
Get-Module M365.RoadmapStyled | Remove-Module -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Import-Module $mod -Force -Verbose

# --- 4) Verify the parameter types
$fp = (Get-Command Filter-RoadmapItems -Module M365.RoadmapStyled).Parameters
"GAFrom type: {0}" -f $fp['GAFrom'].ParameterType.FullName
"GATo   type: {0}" -f $fp['GATo'  ].ParameterType.FullName
