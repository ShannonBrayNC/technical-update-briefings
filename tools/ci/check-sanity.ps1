# 0) Make sure you're in the repo root
cd C:\technical_update_briefings

# 1) Ensure workspaces are declared at root (once)
npm pkg set workspaces[0]="packages/*"

# 2) Make sure packages exist and have package.json (create minimal scaffolds if missing)
#    (Safe to run even if they already exist)
New-Item -ItemType Directory -Force packages/bot, packages/tab, packages/shared/src | Out-Null

# bot package.json
'{
  "name": "@suite/bot",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "server:dev": "tsx watch server/index.ts",
    "server:build": "tsc -p tsconfig.json",
    "server:start": "node dist/server/index.js",
    "check": "eslint \\"server/**/*.ts\\" --max-warnings=0"
  },
  "dependencies": {},
  "devDependencies": {}
}' | Out-File -Encoding utf8 -NoNewline .\packages\bot\package.json

# tab package.json
'{
  "name": "@suite/tab",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "client:dev": "vite --config tab/vite.config.ts",
    "client:build": "vite build --config tab/vite.config.ts",
    "check": "eslint \\"tab/**/*.{ts,tsx}\\" --max-warnings=0"
  },
  "dependencies": {},
  "devDependencies": {}
}' | Out-File -Encoding utf8 -NoNewline .\packages\tab\package.json

# shared package.json
'{
  "name": "@suite/shared",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "exports": "./src/index.ts"
}' | Out-File -Encoding utf8 -NoNewline .\packages\shared\package.json

# 3) **Move runtime deps out of the root** (empty the root dependencies)
#    This removes the "dependencies" section entirely.
npm pkg delete dependencies

# 4) Clean install so npm recomputes the workspace graph
Remove-Item -Recurse -Force node_modules, package-lock.json -ErrorAction SilentlyContinue
npm i
