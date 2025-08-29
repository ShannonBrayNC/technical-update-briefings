#requires -Version 7.0
param(
  [switch]$Force  # overwrite existing files if present
)

$ErrorActionPreference = 'Stop'
$Root = Get-Location

function Step($m){ Write-Host "==> $m" -ForegroundColor Green }
function Info($m){ Write-Host "   - $m" -ForegroundColor DarkGray }
function Write-Utf8Text([string]$Path, [string[]]$Lines, [switch]$Overwrite){
  $full = Join-Path $Root $Path
  $dir  = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if ((Test-Path $full) -and -not $Overwrite){ Info "skip: $Path (exists)"; return }
  $content = [string]::Join("`r`n", $Lines)
  $enc = [System.Text.UTF8Encoding]::new($false) # no BOM
  [System.IO.File]::WriteAllText($full, $content, $enc)
  Info "wrote: $Path"
}
function Write-Json([string]$Path, $Object, [switch]$Overwrite){
  $full = Join-Path $Root $Path
  $dir  = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if ((Test-Path $full) -and -not $Overwrite){ Info "skip: $Path (exists)"; return }
  $json = $Object | ConvertTo-Json -Depth 30
  $enc = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($full, $json, $enc)
  Info "wrote: $Path"
}

# ---------- BOT ----------
Step "Scaffold packages/bot"
$botPkg = [ordered]@{
  name    = "@suite/bot"
  version = "0.1.0"
  private = $true
  type    = "module"
  scripts = [ordered]@{
    "server:dev"   = "tsx watch server/index.ts"
    "server:build" = "tsc -p tsconfig.json"
    "server:start" = "node dist/server/index.js"
    "check"        = "eslint ""server/**/*.ts"" --max-warnings=0"
  }
  dependencies = [ordered]@{
    express = "^4.19.2"
    "body-parser" = "^1.20.2"
    botbuilder = "^4.22.1"
    "@azure/storage-queue" = "^12.16.0"
    "@azure/identity" = "^4.4.1"
    "@microsoft/microsoft-graph-client" = "^3.0.7"
    "isomorphic-fetch" = "^3.0.0"
    dotenv = "^16.4.5"
  }
  devDependencies = [ordered]@{
    typescript = "^5.4.5"
    tsx = "^4.7.0"
    "@types/node" = "^20.12.7"
    "@types/express" = "^4.17.21"
    "@types/body-parser" = "^1.19.5"
  }
}
$botTs = @{
  compilerOptions = @{
    target = "ES2022"; module = "ES2022"; moduleResolution = "Bundler"
    outDir = "dist"; rootDir = "."
    strict = $true; esModuleInterop = $true; skipLibCheck = $true
  }
  include = @("server/**/*.ts")
}
Write-Json "packages/bot/package.json" $botPkg -Overwrite:$Force
Write-Json "packages/bot/tsconfig.json" $botTs   -Overwrite:$Force
Write-Utf8Text "packages/bot/.env.sample" @(
  "MicrosoftAppType=SingleTenant"
  "MicrosoftAppId=<YOUR-APP-ID>"
  "MicrosoftAppTenantId=<YOUR-TENANT-ID>"
  "CertificateThumbprint=<YOUR-THUMBPRINT>"
  "CertificatePrivateKey=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
  "QUEUE_KIND=memory"
) -Overwrite:$Force

# ---------- TAB ----------
Step "Scaffold packages/tab"
$tabPkg = [ordered]@{
  name    = "@suite/tab"
  version = "0.1.0"
  private = $true
  type    = "module"
  scripts = [ordered]@{
    "client:dev"   = "vite --config tab/vite.config.ts"
    "client:build" = "vite build --config tab/vite.config.ts"
    "check"        = "eslint ""tab/**/*.{ts,tsx}"" --max-warnings=0"
  }
  dependencies = [ordered]@{
    react = "^18.3.1"
    "react-dom" = "^18.3.1"
  }
  devDependencies = [ordered]@{
    vite = "^5.2.0"
    "@vitejs/plugin-react" = "^4.2.0"
    typescript = "^5.4.5"
    "@types/react" = "^18.2.79"
    "@types/react-dom" = "^18.2.25"
  }
}
$tabTs = @{
  compilerOptions = @{
    target = "ES2022"; jsx = "react-jsx"; module = "ES2022"; moduleResolution = "Bundler"
    strict = $true; skipLibCheck = $true
  }
  include = @("tab/*.ts","tab/*.tsx")
}
Write-Json "packages/tab/package.json" $tabPkg -Overwrite:$Force
Write-Json "packages/tab/tsconfig.json"  $tabTs  -Overwrite:$Force

Write-Utf8Text "packages/tab/tab/index.html" @(
  "<!doctype html>"
  "<html>"
  "  <head>"
  "    <meta charset=""UTF-8""/>"
  "    <meta name=""viewport"" content=""width=device-width,initial-scale=1.0""/>"
  "    <title>Briefing Tab</title>"
  "    <script src=""https://cdn.tailwindcss.com""></script>"
  "  </head>"
  "  <body class=""bg-slate-50"">"
  "    <div id=""root""></div>"
  "    <script type=""module"" src=""/index.tsx""></script>"
  "  </body>"
  "</html>"
) -Overwrite:$Force

Write-Utf8Text "packages/tab/tab/index.tsx" @(
  'import React from "react";'
  'import { createRoot } from "react-dom/client";'
  'import MeetingTab from "./MeetingTab";'
  'const root = document.getElementById("root")!;'
  'createRoot(root).render(<MeetingTab />);'
) -Overwrite:$Force

Write-Utf8Text "packages/tab/tab/vite.config.ts" @(
  'import { defineConfig } from "vite";'
  'import react from "@vitejs/plugin-react";'
  'export default defineConfig({'
  '  root: __dirname,'
  '  plugins: [react()],'
  '  server: { port: 5173 },'
  '  build: { outDir: "dist" }'
  '});'
) -Overwrite:$Force

if (-not (Test-Path (Join-Path $Root "packages/tab/tab/MeetingTab.tsx")) -or $Force) {
  Write-Utf8Text "packages/tab/tab/MeetingTab.tsx" @(
    'import React from "react";'
    'export default function MeetingTab(){'
    '  return (<div className="p-6">Paste your MeetingTab.tsx from canvas here.</div>);'
    '}'
  ) -Overwrite:$Force
} else {
  Info "skip: packages/tab/tab/MeetingTab.tsx (exists)"
}

# ---------- SHARED ----------
Step "Scaffold packages/shared"
if (-not (Test-Path (Join-Path $Root "packages/shared"))) {
  New-Item -ItemType Directory -Force -Path "packages/shared/src" | Out-Null
}
$sharedPkg = [ordered]@{
  name    = "@suite/shared"
  version = "0.1.0"
  private = $true
  type    = "module"
  exports = "./src/index.ts"
}
Write-Json "packages/shared/package.json" $sharedPkg -Overwrite:$Force
Write-Utf8Text "packages/shared/src/index.ts" @(
  'export type FeedKind = "roadmap" | "message-center" | "azure-updates" | "security";'
  'export type Citation = { title: string; url: string };'
  'export type AskAnswer = { short: string; details?: string; citations: Citation[] };'
) -Overwrite:$Force

Write-Host "`n✅ Package scaffolds complete." -ForegroundColor Cyan
Write-Host "Next:"
Write-Host "  1) npm i"
Write-Host "  2) npm run check"
Write-Host "  3) npm -w @suite/tab run client:dev   (or cd packages/tab && npm run client:dev)"
Write-Host "  4) npm -w @suite/bot run server:dev   (or cd packages/bot && npm run server:dev)"
