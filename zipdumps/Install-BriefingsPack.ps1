#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string] $SourceZipPath,
  [Parameter(Mandatory=$true)][string] $DestinationRepoPath,
  [string] $BackupRoot = "$PSScriptRoot/backups"
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $DestinationRepoPath)) { throw "Repo path not found: $DestinationRepoPath" }
if (-not (Test-Path $SourceZipPath)) { throw "Zip not found: $SourceZipPath" }

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$backupPath = Join-Path $BackupRoot $timestamp

New-Item -ItemType Directory -Force -Path $backupPath | Out-Null

# Expand zip to temp
$temp = Join-Path $env:TEMP ("briefings_" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Force -Path $temp | Out-Null
Expand-Archive -Path $SourceZipPath -DestinationPath $temp -Force

# Paths to install from the zips (bot or starter pack layout)
$installRoots = @(
  'packages',
  'scripts',
  'adaptiveCards',
  'modules',
  '.github',
  'docs',
  '.env.sample'
)

foreach ($root in $installRoots) {
  $src = Join-Path $temp $root
  if (-not (Test-Path $src)) { continue }
  $dst = Join-Path $DestinationRepoPath $root

  # Backup existing destination content if present
  if (Test-Path $dst) {
    $dstBackup = Join-Path $backupPath $root
    New-Item -ItemType Directory -Force -Path $dstBackup | Out-Null
    Copy-Item -Path (Join-Path $dst '*') -Destination $dstBackup -Recurse -Force -ErrorAction SilentlyContinue
  }

  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
  Write-Host ("Installed " + $root)
}

Write-Host ("Backup created at: " + $backupPath)
Write-Host "Done."
