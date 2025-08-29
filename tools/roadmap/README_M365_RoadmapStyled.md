
# M365.RoadmapStyled Module (Clean Rebuild)

## Exported Cmdlets
- **Connect-GraphCertificate** — placeholder for future Graph certificate auth.
- **Get-M365ServiceMessages** — placeholder to keep interface parity with your message center module.
- **Get-M365Roadmap** — fetches the public Microsoft 365 Roadmap API, filters, and renders a styled HTML report.

## Get-M365Roadmap Parameters (most relevant)
- `-Products <string[]>` — e.g., 'Microsoft Teams','SharePoint'
- `-Platforms <string[]>` — e.g., 'Web','iOS','Mac'
- `-CloudInstances <string[]>` — accepts: `Worldwide (Standard Multi-Tenant)`, `GCC`, `GCC High`, `DoD`
- `-ReleasePhase <string[]>` — if it includes **General Availability**, it is treated as `-Status 'Launched'`
- `-Status <string[]>` — roadmap `status` property (`In development`, `Rolling out`, `Launched`, `Cancelled`)
- `-UpdatedSince <DateTime>` / `-CreatedSince <DateTime>` — dates parsed from `"Month CYyyyy"` strings when possible
- `-ThisMonth` | `-NextMonth` | `-NextQuarter` — sets a GA target month (used by the client-side toggle)
- `-GroupBy <Cloud|Technology|None>` — default `Cloud`
- `-Top <int>` — trims the list after sorting (default 200)
- `-OutputPath <string>` — file path for the HTML report

## HTML features
- Sidebar filters for **Cloud**, **Technology**, **Platforms**, **Status**
- **Apply** button to re-filter
- Toggle: **Exact Month Only** (unchecked) vs **Include entire quarter** (checked)
- Group headers hide automatically when empty
- Cloud badges: 🌐 Worldwide, 🏛️ GCC, 🏛️✨ GCC High, 🛡️ DoD

## Quick Test
1. Copy `M365.RoadmapStyled.fixed.psm1` into your module folder.
2. Run `Quick-Check.ps1`.

If anything looks off, share the console output (`-Verbose`) and we’ll tune further.
