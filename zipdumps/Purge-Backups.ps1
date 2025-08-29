#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string] $BackupRoot,
  [int] $KeepHours = 2
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $BackupRoot)) { Write-Host "Nothing to purge."; return }

$cutoff = (Get-Date).AddHours(-1 * $KeepHours)
$dirs = Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue

$purged = 0
foreach ($d in $dirs) {
  if ($d.LastWriteTime -lt $cutoff) {
    Remove-Item -Path $d.FullName -Recurse -Force
    $purged++
  }
}
Write-Host ("Purged " + $purged + " backup folder(s) older than " + $KeepHours + " hour(s).")
