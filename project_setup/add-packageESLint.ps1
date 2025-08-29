#requires -Version 7.0
param(
  [switch]$Force,           # overwrite existing .eslintrc.cjs if present
  [switch]$AddReactPlugins  # optionally add eslint-plugin-react & react-hooks to the tab package
)

$ErrorActionPreference = 'Stop'
$root = Get-Location

function Write-Text($Path, [string[]]$Lines, [switch]$Overwrite){
  $Full = Join-Path $root $Path
  $Dir  = Split-Path $Full -Parent
  if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
  if ((Test-Path $Full) -and -not $Overwrite){ Write-Host "skip: $Path (exists)" -ForegroundColor DarkGray; return }
  Set-Content -Encoding UTF8 -NoNewline -Path $Full -Value ($Lines -join "`r`n")
  Write-Host "wrote: $Path" -ForegroundColor Green
}

# --- packages/bot ---
Write-Text "packages/bot/.eslintrc.cjs" @'
/** Bot package ESLint (Node) */
module.exports = {
  root: false, // root rules are in repository root
  parser: "@typescript-eslint/parser",
  plugins: ["@typescript-eslint"],
  extends: ["eslint:recommended", "plugin:@typescript-eslint/recommended"],
  env: { node: true, es2022: true },
  ignorePatterns: ["dist", "node_modules"],
  parserOptions: { sourceType: "module" },
  rules: {
    "no-console": "off",
    "@typescript-eslint/no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }]
  },
  overrides: [
    { files: ["**/*.js"], rules: { "@typescript-eslint/no-var-requires": "off" } }
  ]
};
'@ -Overwrite:$Force

# --- packages/tab ---
if ($AddReactPlugins) {
  try {
    Write-Host "adding eslint-plugin-react & react-hooks at repo root..." -ForegroundColor Cyan
    npm i -D eslint-plugin-react eslint-plugin-react-hooks | Out-Null
  } catch {
    Write-Warning "Could not install react plugins automatically. Run: npm i -D eslint-plugin-react eslint-plugin-react-hooks"
  }

  Write-Text "packages/tab/.eslintrc.cjs" @'
/** Tab package ESLint (Browser + React) */
module.exports = {
  root: false,
  parser: "@typescript-eslint/parser",
  plugins: ["@typescript-eslint", "react", "react-hooks"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:react/recommended",
    "plugin:react-hooks/recommended"
  ],
  env: { browser: true, es2022: true },
  settings: {
    react: { version: "detect" }
  },
  ignorePatterns: ["dist", "node_modules"],
  parserOptions: { sourceType: "module", ecmaFeatures: { jsx: true } },
  rules: {
    "no-console": "off",
    "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
    "react/react-in-jsx-scope": "off"
  }
};
'@ -Overwrite:$Force
}
else {
  Write-Text "packages/tab/.eslintrc.cjs" @'
/** Tab package ESLint (Browser + React core using TS rules only) */
module.exports = {
  root: false,
  parser: "@typescript-eslint/parser",
  plugins: ["@typescript-eslint"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  env: { browser: true, es2022: true },
  ignorePatterns: ["dist", "node_modules"],
  parserOptions: { sourceType: "module", ecmaFeatures: { jsx: true } },
  rules: {
    "no-console": "off",
    "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }]
  }
};
'@ -Overwrite:$Force
}

# --- packages/shared ---
Write-Text "packages/shared/.eslintrc.cjs" @'
/** Shared types (TS only) */
module.exports = {
  root: false,
  parser: "@typescript-eslint/parser",
  plugins: ["@typescript-eslint"],
  extends: ["eslint:recommended", "plugin:@typescript-eslint/recommended"],
  env: { es2022: true },
  ignorePatterns: ["dist", "node_modules"],
  parserOptions: { sourceType: "module" },
  rules: {
    "@typescript-eslint/no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }]
  }
};
'@ -Overwrite:$Force

Write-Host "`n✅ Per-package ESLint configs added." -ForegroundColor Cyan
Write-Host "Next:"
Write-Host "  • npm run check                 # runs ESLint (root) + PS guardrails + Pester"
Write-Host "  • npm -w @suite/tab run check   # lint tab only"
Write-Host "  • npm -w @suite/bot run check   # lint bot only"
