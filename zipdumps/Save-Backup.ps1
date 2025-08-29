#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string] $RepoPath,
  [string] $BackupRoot = "$PSScriptRoot/backups"
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $RepoPath)) { throw "Repo path not found: $RepoPath" }

Push-Location $RepoPath
try {
  $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $backupPath = Join-Path $BackupRoot $timestamp
  New-Item -ItemType Directory -Force -Path $backupPath | Out-Null

  # Identify changed files (tracked & modified)
  $changed = git status --porcelain | ForEach-Object {
    $line = $_.Trim()
    if (-not $line) { return }
    $parts = $line.Split(' ',2)
    if ($parts.Count -lt 2) { return }
    $file = $parts[1]
    $file
  } | Where-Object { $_ -and (Test-Path $_) }

  if (-not $changed) {
    Write-Host "No modified files to back up."
    return
  }

  foreach ($f in $changed) {
    $src = Join-Path $RepoPath $f
    $dst = Join-Path $backupPath $f
    $dstDir = Split-Path -Parent $dst
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    Copy-Item -Path $src -Destination $dst -Force
  }

  Write-Host ("Backed up " + (@($changed).Count) + " file(s) to " + $backupPath)
}
finally {
  Pop-Location
}
