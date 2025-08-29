# 0) make sure you’re at the repo root
cd C:\technical_update_briefings

# 1) (re)create a clean root package.json with workspaces
npm init -y
npm pkg set name="technical-update-briefings" private=true type="module" workspaces[0]="packages/*"

# 2) root scripts (tooling only)
npm pkg set scripts.precheck='pwsh -NoLogo -File ./build/Precheck.ps1'
npm pkg set scripts.ps:test='pwsh -NoLogo -Command Invoke-Pester -CI -Path ./tests'
npm pkg set scripts.lint='eslint "packages/**/{server,tab,src}/**/*.{ts,tsx,js}" --max-warnings=0'
npm pkg set scripts.validate='node tools/ci/validate-workspaces.mjs'
npm pkg set scripts.check='npm run precheck && npm run ps:test && npm run lint && npm run validate'

# 3) dev tooling at the root (NO runtime deps at root)
npm pkg set devDependencies.eslint="^9.12.0" `
               devDependencies.@typescript-eslint/parser="^8.0.0" `
               devDependencies.@typescript-eslint/eslint-plugin="^8.0.0" `
               devDependencies.eslint-plugin-react="^7.37.5" `
               devDependencies.eslint-plugin-react-hooks="^5.2.0"

# 4) ensure there are no runtime deps at root (validator requirement)
npm pkg delete dependencies

# 5) clean install to refresh the workspace graph
Remove-Item -Recurse -Force node_modules, package-lock.json -ErrorAction SilentlyContinue
npm i
