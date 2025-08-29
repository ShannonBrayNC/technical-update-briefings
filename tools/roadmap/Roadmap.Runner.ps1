#requires -Version 7.0
param(
  [string]$OutputPath = 'C:\M365 Roadmap Components\Roadmap_Latest.html',
  [switch]$NextMonth,       # default on below
  [switch]$GAQuarter,       # with -NextMonth, include the whole quarter
  [int]$Top = 200
)

# ---------------- Utilities ----------------
function Ensure-StringList { param($InputObject)
  if ($null -eq $InputObject) { return @() }
  if ($InputObject -is [string]) { return ([string]::IsNullOrWhiteSpace($InputObject) ? @() : @($InputObject)) }
  if ($InputObject -is [System.Collections.IEnumerable]) {
    return @($InputObject | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  }
  @([string]$InputObject)
}
function Normalize-Cloud { param([string]$Name)
  if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
  $n = $Name.Trim()
  switch -Regex ($n) {
    '^(WW|Worldwide|Commercial|Standard Multi-Tenant)$' { 'Worldwide (Standard Multi-Tenant)' ; break }
    '^(GCC|Government Community Cloud|G)$'              { 'GCC' ; break }
    '^(GCC High|GCCH)$'                                 { 'GCC High' ; break }
    '^(DoD|DOD)$'                                       { 'DoD' ; break }
    default { $n }
  }
}
function Normalize-Phase { param([string]$Name)
  if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
  $n = $Name.Trim()
  switch -Regex ($n) {
    '^(General\s*Availability|GA)$'                     { 'General Availability' ; break }
    '^Preview$'                                         { 'Preview' ; break }
    '^Targeted\s*Release(\s*\(Entire Organization\))?$' { $n ; break }
    '^(In development)$'                                { 'In development' ; break }
    '^(Rolling out)$'                                   { 'Rolling out' ; break }
    '^(Launched)$'                                      { 'Launched' ; break }
    default { $n }
  }
}
function Try-ParseDate { param([string]$Text,[ref]$DateOut)
  $DateOut.Value = [datetime]::MinValue
  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
  if ([datetime]::TryParse($Text, [ref]$d = [datetime]::MinValue)) { $DateOut.Value = $d; return $true }
  if ($Text -match '(January|February|March|April|May|June|July|August|September|October|November|December)\s+(?:CY)?(\d{4})') {
    $m=$matches[1]; $y=[int]$matches[2]
    $DateOut.Value = [datetime]::ParseExact("01 $m $y",'dd MMMM yyyy',[Globalization.CultureInfo]::InvariantCulture)
    return $true
  }
  if ($Text -match 'CY(\d{4})') {
    $y=[int]$matches[1]
    $DateOut.Value = [datetime]::ParseExact("01 Jan $y",'dd MMM yyyy',[Globalization.CultureInfo]::InvariantCulture)
    return $true
  }
  $false
}
function Get-ItemTags { param([Parameter(Mandatory)][object]$Item)
  $tc = $Item.PSObject.Properties['tagsContainer'] ? $Item.tagsContainer : $null
  $products  = if ($tc -and $tc.PSObject.Properties['products'])       { Ensure-StringList $tc.products }       elseif ($Item.PSObject.Properties['products'])  { Ensure-StringList $Item.products }  else { @() }
  $platforms = if ($tc -and $tc.PSObject.Properties['platforms'])      { Ensure-StringList $tc.platforms }      elseif ($Item.PSObject.Properties['platforms']) { Ensure-StringList $Item.platforms } else { @() }
  $clouds    = if ($tc -and $tc.PSObject.Properties['cloudInstances']) { Ensure-StringList $tc.cloudInstances } elseif ($Item.PSObject.Properties['clouds'])    { Ensure-StringList $Item.clouds }    else { @() }
  $phases    = if ($tc -and $tc.PSObject.Properties['releasePhase'])   { Ensure-StringList $tc.releasePhase }   elseif ($Item.PSObject.Properties['phases'])    { Ensure-StringList $Item.phases }    else { @() }
  [pscustomobject]@{
    products  = @($products  | ForEach-Object  { $_.Trim() } | Where-Object { $_ })
    platforms = @($platforms | ForEach-Object  { $_.Trim() } | Where-Object { $_ })
    clouds    = @($clouds    | ForEach-Object  { Normalize-Cloud $_ } | Where-Object { $_ })
    phases    = @($phases    | ForEach-Object  { Normalize-Phase $_ } | Where-Object { $_ })
  }
}

# ---------------- Filter ----------------
function Filter-RoadmapItems {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$Items,
    [string[]]$Products,
    [string[]]$Platforms,
    [string[]]$CloudInstances,
    [string[]]$ReleasePhase,
    [string[]]$Status,
    [string]$Text,
    [Nullable[datetime]]$UpdatedSince,
    [Nullable[datetime]]$CreatedSince,
    [Nullable[datetime]]$GAFrom,
    [Nullable[datetime]]$GATo
  )

  $wantProducts  = @($Products      | ForEach-Object { $_.ToLowerInvariant() })
  $wantPlatforms = @($Platforms     | ForEach-Object { $_.ToLowerInvariant() })
  $wantClouds    = @($CloudInstances| ForEach-Object { Normalize-Cloud $_ })
  $wantPhases    = @($ReleasePhase  | ForEach-Object { Normalize-Phase $_ })
  $wantStatus    = @($Status        | ForEach-Object { $_.Trim().ToLowerInvariant() })
  $textNeedle    = if ($Text) { $Text.Trim() } else { $null }

  $out = New-Object System.Collections.Generic.List[object]
  foreach($it in $Items){

    if ($textNeedle) {
      $hay = @([string]$it.title,[string]$it.id,[string]$it.description) -join ' '
      if ($hay -notmatch [regex]::Escape($textNeedle)) { continue }
    }

    if ($wantStatus.Count -gt 0) {
      $st = ([string]$it.status).Trim().ToLowerInvariant()
      if (-not ($wantStatus -contains $st)) { continue }
    }

    if ($UpdatedSince.HasValue -or $CreatedSince.HasValue) {
      $dC=$null;$dM=$null
      [void][datetime]::TryParse([string]$it.created,[ref]$dC)
      [void][datetime]::TryParse([string]$it.modified,[ref]$dM)
      if ($UpdatedSince.HasValue -and ($null -eq $dM -or $dM -lt $UpdatedSince.Value)) { continue }
      if ($CreatedSince.HasValue -and ($null -eq $dC -or $dC -lt $CreatedSince.Value)) { continue }
    }

    $tags = Get-ItemTags -Item $it
    if ($wantProducts.Count -gt 0)  { $p=@($tags.products | ForEach-Object { $_.ToLowerInvariant() }); if ( (@($p | Where-Object { $wantProducts -contains $_ }).Count) -eq 0) { continue } }
    if ($wantPlatforms.Count -gt 0) { $p=@($tags.platforms| ForEach-Object { $_.ToLowerInvariant() }); if ( (@($p | Where-Object { $wantPlatforms -contains $_ }).Count) -eq 0) { continue } }
    if ($wantClouds.Count -gt 0)    { if ( (@($tags.clouds | Where-Object { $wantClouds -contains $_ }).Count) -eq 0) { continue } }
    if ($wantPhases.Count -gt 0)    { if ( (@($tags.phases | Where-Object { $wantPhases -contains $_ }).Count) -eq 0) { continue } }

    if ($GAFrom.HasValue -and $GATo.HasValue) {
      $gaText = $null
      if     ($it.PSObject.Properties['ga'])          { $gaText = [string]$it.ga }
      elseif ($it.PSObject.Properties['releaseDate']) { $gaText = [string]$it.releaseDate }
      if (-not $gaText -and $it.PSObject.Properties['description']) {
        if ([string]$it.description -match 'GA:\s*([A-Za-z]+\s+(?:CY)?\d{4})') { $gaText = $matches[1] }
      }
      $gaDate = $null
      if (Try-ParseDate -Text $gaText -DateOut ([ref]$gaDate)) {
        if ($gaDate -lt $GAFrom.Value -or $gaDate -gt $GATo.Value) { continue }
      }
    }

    $out.Add($it) | Out-Null
  }
  ,$out.ToArray()
}

# ---------------- HTML ----------------
function New-RoadmapHtml {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$Items,
    [string]$Title = 'Microsoft 365 Roadmap Briefing',
    [string]$Subtitle,
    [ValidateSet('None','Cloud')][string]$GroupBy = 'Cloud'
  )

  $now = Get-Date
  $json = ($Items | ForEach-Object {
    $t = Get-ItemTags -Item $_
    @{
      id          = "$($_.id)"
      title       = "$($_.title)"
      description = "$($_.description)"
      created     = "$($_.created)"
      modified    = "$($_.modified)"
      status      = "$($_.status)"
      products    = $t.products
      platforms   = $t.platforms
      clouds      = $t.clouds
      phases      = $t.phases
    }
  }) | ConvertTo-Json -Depth 6

@"
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8" />
<title>$Title</title>
<meta name="viewport" content="width=device-width,initial-scale=1" />
<style>
:root{--bg:#0f172a;--card:#0b1220;--chip:#111b2f;--text:#e5e7eb;--muted:#94a3b8;--border:#1e293b}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,Segoe UI,Roboto}
.wrap{max-width:1180px;margin:24px auto;padding:0 16px}
h1{font-size:22px;margin:0 0 4px}.sub{color:var(--muted);font-size:12px;margin-bottom:16px}
.toolbar{background:#0b1220;padding:14px;border:1px solid var(--border);border-radius:14px}
.row{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:8px 0}
.search{flex:1;min-width:260px;background:#0a1020;border:1px solid var(--border);border-radius:10px;padding:10px 12px;color:var(--text)}
.btn{padding:8px 12px;background:#13233f;color:var(--text);border:1px solid var(--border);border-radius:10px;cursor:pointer}
.btn:hover{background:#193056}.chip{display:inline-flex;align-items:center;gap:6px;padding:6px 10px;background:#111b2f;border:1px solid var(--border);border-radius:999px;font-size:12px}
.pill{display:inline-flex;gap:6px;align-items:center;padding:4px 8px;background:#0a1020;border:1px dashed var(--border);border-radius:999px;color:var(--muted);font-size:12px}
.h{display:flex;align-items:center;gap:8px;font-weight:600;margin:22px 0 8px}.cloud{padding:10px 12px;border:1px solid var(--border);border-radius:12px;background:#0b1220}
.card{background:#0b1220;border:1px solid var(--border);border-radius:16px;padding:14px;margin:12px 0}
.title{font-weight:700;margin-bottom:8px}.badges{display:flex;gap:6px;flex-wrap:wrap;margin-top:6px}
.badge{background:#0a1020;border:1px solid var(--border);border-radius:999px;padding:2px 8px;font-size:11px;color:#9fb1cc}
details{margin-top:10px}summary{cursor:pointer;color:#9fb1cc}.counts{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:10px}
.count{font-size:12px;color:#9fb1cc}.hide{display:none!important}
</style></head><body>
<div class="wrap">
  <h1>$Title</h1>
  <div class="sub">Generated $($now.ToString('yyyy-MM-dd HH:mm'))$([string]::IsNullOrWhiteSpace($Subtitle) ? '' : " · $Subtitle")</div>
  <div class="counts" id="top-counts"></div>
  <div class="toolbar" id="toolbar">
    <div class="row">
      <input id="q" class="search" placeholder="Search title, ID, description..." />
      <button class="btn" id="apply">Apply</button>
      <button class="btn" id="clear">Clear</button>
    </div>
    <div class="row" id="chips-products"></div>
    <div class="row" id="chips-platforms"></div>
    <div class="row" id="chips-clouds"></div>
    <div class="row" id="chips-phases"></div>
    <div class="row" id="chips-status"></div>
  </div>
  <div id="groups"></div>
</div>
<script>
const DATA = $json;
const uniq=a=>Array.from(new Set(a.filter(Boolean)));
const norm=s=>(s||'').toLowerCase();
const ALL={
  products : uniq(DATA.flatMap(x=>x.products||[])).sort(),
  platforms: uniq(DATA.flatMap(x=>x.platforms||[])).sort(),
  clouds   : uniq(DATA.flatMap(x=>x.clouds||[])).sort(),
  phases   : uniq(DATA.flatMap(x=>x.phases||[])).sort(),
  status   : uniq(DATA.map(x=>norm(x.status))).sort()
};
const state={ q:'', products:new Set(), platforms:new Set(), clouds:new Set(), phases:new Set(), status:new Set() };
function chipRow(id,title,items,set){
  const host=document.getElementById(id); host.innerHTML='';
  if(items.length===0){ const s=document.createElement('span'); s.className='pill'; s.textContent=`No ${title}`; host.appendChild(s); return;}
  for(const v of items){
    const cb=document.createElement('input'); cb.type='checkbox'; cb.id=(id+'_'+v).replace(/[^a-z0-9]+/ig,'_');
    cb.addEventListener('change',()=>{ if(cb.checked) set.add(v); else set.delete(v); });
    const lab=document.createElement('label'); lab.className='chip'; lab.appendChild(cb); lab.appendChild(document.createTextNode(' '+v));
    host.appendChild(lab);
  }
}
function renderChips(){
  chipRow('chips-products','products',ALL.products,state.products);
  chipRow('chips-platforms','platforms',ALL.platforms,state.platforms);
  chipRow('chips-clouds','clouds',ALL.clouds,state.clouds);
  chipRow('chips-phases','phases',ALL.phases,state.phases);
  chipRow('chips-status','status',ALL.status,state.status);
}
function passes(it){
  if(state.q){
    const h=`${it.title||''} ${it.id||''} ${it.description||''}`.toLowerCase();
    if(!h.includes(state.q.toLowerCase())) return false;
  }
  if(state.products.size>0){ const s=new Set((it.products||[]).map(norm)); if(![...state.products].some(x=>s.has(x))) return false; }
  if(state.platforms.size>0){ const s=new Set((it.platforms||[]).map(norm)); if(![...state.platforms].some(x=>s.has(x))) return false; }
  if(state.clouds.size>0){ const s=new Set(it.clouds||[]); if(![...state.clouds].some(x=>s.has(x))) return false; }
  if(state.phases.size>0){ const s=new Set(it.phases||[]); if(![...state.phases].some(x=>s.has(x))) return false; }
  if(state.status.size>0){ if(!state.status.has(norm(it.status))) return false; }
  return true;
}
function groupKey(it){ return (it.clouds && it.clouds[0]) || 'Unknown'; }
function render(){
  const groups={}; for(const it of DATA){ if(!passes(it)) continue; const k=groupKey(it); (groups[k]??=([])).push(it); }
  const cHost=document.getElementById('top-counts'); cHost.innerHTML='';
  const total=Object.values(groups).reduce((a,b)=>a+b.length,0);
  const mk=(t,n)=>{ const s=document.createElement('span'); s.className='count'; s.textContent=`${t}: ${n}`; return s; };
  cHost.appendChild(mk('Total',total));
  const order=['DoD','GCC','GCC High','Worldwide (Standard Multi-Tenant)','Unknown'];
  const icons={'DoD':'🪖','GCC':'🏛️','GCC High':'🛡️','Worldwide (Standard Multi-Tenant)':'🌐','Unknown':'❓'};
  const container=document.getElementById('groups'); container.innerHTML='';
  for(const key of order){
    const arr=groups[key]||[]; if(arr.length===0) continue;
    const h=document.createElement('div'); h.className='h';
    h.innerHTML=`<div class="chip"><span>${icons[key]||'☁️'}</span><strong>${key}</strong></div>`; container.appendChild(h);
    const box=document.createElement('div'); box.className='cloud'; container.appendChild(box);
    for(const it of arr){
      const card=document.createElement('div'); card.className='card';
      const prods=(it.products||[]).map(p=>`<span class="badge">${p}</span>`).join(' ');
      const plats=(it.platforms||[]).map(p=>`<span class="badge">${p}</span>`).join(' ');
      const clds =(it.clouds||[]).map(p=>`<span class="badge">${p}</span>`).join(' ');
      const phs  =(it.phases||[]).map(p=>`<span class="badge">${p}</span>`).join(' ');
      card.innerHTML = `
        <div class="title">${it.title||'(no title)'}</div>
        <div class="badges">${it.status?`<span class="badge">${it.status}</span>`:''} ${prods}${plats}${clds}${phs}</div>
        <details><summary>Description</summary><div style="margin-top:8px;color:#cbd5e1">${(it.description||'').replace(/</g,'&lt;')}</div></details>
        <div class="badges" style="margin-top:8px">
          ${it.id?`<span class="badge">ID: ${it.id}</span>`:''}
          ${it.created?`<span class="badge">Created: ${it.created}</span>`:''}
          ${it.modified?`<span class="badge">Modified: ${it.modified}</span>`:''}
        </div>`;
      box.appendChild(card);
    }
  }
}
function wire(){
  renderChips();
  document.getElementById('apply').addEventListener('click',()=>{ state.q=document.getElementById('q').value||''; render(); });
  document.getElementById('clear').addEventListener('click',()=>{
    state.q=''; state.products.clear(); state.platforms.clear(); state.clouds.clear(); state.phases.clear(); state.status.clear();
    document.getElementById('q').value=''; renderChips(); render();
  });
  document.getElementById('q').addEventListener('keydown',e=>{ if(e.key==='Enter'){ document.getElementById('apply').click(); }});
  render();
}
wire();
</script>
</body></html>
"@
}

# ---------------- Driver ----------------
Write-Verbose "Fetching Roadmap…"
$raw = Invoke-RestMethod -Uri 'https://www.microsoft.com/releasecommunications/api/v1/m365'
$items = if ($raw -is [System.Collections.IEnumerable]) { @($raw) } elseif ($raw.PSObject.Properties['features']) { @($raw.features) } else { @($raw) }
Write-Verbose "Items fetched: $($items.Count)"

# GA window (default = next month)
if (-not $NextMonth) { $NextMonth = $true }

$GAFrom=$null; $GATo=$null
if ($NextMonth) {
  $start   = Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day 1
  $nmStart = $start.AddMonths(1); $nmEnd = $nmStart.AddMonths(1).AddDays(-1)
  if ($GAQuarter) {
    $qIndex = [math]::Floor(($nmStart.Month - 1) / 3)
    $qStart = Get-Date -Year $nmStart.Year -Month ($qIndex*3+1) -Day 1
    $qEnd   = $qStart.AddMonths(3).AddDays(-1)
    $GAFrom=$qStart; $GATo=$qEnd
    Write-Verbose ("GA window: {0}..{1} (quarter)" -f $GAFrom.ToShortDateString(),$GATo.ToShortDateString())
  } else {
    $GAFrom=$nmStart; $GATo=$nmEnd
    Write-Verbose ("GA window: {0}..{1} (exact month)" -f $GAFrom.ToShortDateString(),$GATo.ToShortDateString())
  }
}

# Sort by modified desc, cap Top
if ($items.Count -gt 0) {
  $sortable = foreach($it in $items){
    $d=[datetime]::MinValue; [void][datetime]::TryParse([string]$it.modified,[ref]$d)
    [pscustomobject]@{ _k=$d; _it=$it }
  }
  $items = @($sortable | Sort-Object _k -Descending | ForEach-Object { $_._it })
}
if ($Top -gt 0 -and $items.Count -gt 0) { $items = @($items | Select-Object -First $Top) }

# Server-side filter: clouds + statuses (so page loads snappy)
$clouds  = @('GCC','GCC High','DoD','Worldwide (Standard Multi-Tenant)')
$status  = @('Launched','Rolling out','In development')
$items   = Filter-RoadmapItems -Items $items -CloudInstances $clouds -Status $status -GAFrom $GAFrom -GATo $GATo
Write-Verbose "Items after filter: $($items.Count)"

# Render
$html = New-RoadmapHtml -Items $items -Title 'Microsoft 365 Roadmap Briefing' -Subtitle 'Client filters: Apply/Clear, hide empty clouds' -GroupBy Cloud
Set-Content -Path $OutputPath -Value $html -Encoding UTF8
Write-Host "Roadmap written to: $OutputPath"
Start-Process $OutputPath
