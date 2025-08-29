#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string] $RepoPath,
  [string] $SecurityDir = "$PSScriptRoot/../security"
)
$ErrorActionPreference = 'Stop'

$env:SECURITY_DIR = $SecurityDir

# Recommend mapping envs to your local certs in SecurityDir
$env:AZURE_CERT_PEM_PATH = (Join-Path $SecurityDir 'graph.pem')
$env:AZURE_CERT_PFX_PATH = (Join-Path $SecurityDir 'bot.pfx')

Push-Location $RepoPath
try {
  # Use npm workspaces if present; otherwise, run individual scripts
  if (Test-Path 'package.json') {
    Write-Host "Starting bot (ts-node) ..."
    npm run dev:bot
  } else {
    Write-Host "No package.json found. Start processes manually."
  }
}
finally {
  Pop-Location
}
