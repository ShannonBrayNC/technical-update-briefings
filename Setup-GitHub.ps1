# 0) initialize git (if not already)
git init -b main

# 1) basic identity (if you’ve never set it)
git config user.name "ShannonBrayNC"
git config user.email "shannonbraync@outlook.com"

# 2) .gitignore (don’t commit secrets, build output, or virtual envs)
@'
# node / vite
node_modules/
dist/
*.log
*.lock

# env + secrets
.env
**/.env
*.pfx
*.pem
*.cer
*.key
security/

# python
.venv/
__pycache__/
*.pyc

# editors
.vscode/
.DS_Store
Thumbs.db
'@ | Out-File -Encoding utf8 .gitignore

# 3) (optional but smart) Git LFS for large binaries like *.pptx
git lfs install
git lfs track "*.pptx" "*.zip"
echo "*.pptx filter=lfs diff=lfs merge=lfs -text" | Out-File -Encoding utf8 -Append .gitattributes
echo "*.zip   filter=lfs diff=lfs merge=lfs -text" | Out-File -Encoding utf8 -Append .gitattributes

# 4) make sure root package.json exists & workspaces are set (you already fixed this)
# npm run validate should pass before you push
npm run validate

# 5) first commit
git add .
git commit -m "chore: initialize monorepo (tab+bot), guardrails & CI"

# 6) create GitHub repo and push (private)
gh auth login --web
gh repo create technical-update-briefings --private --source . --remote origin --push
