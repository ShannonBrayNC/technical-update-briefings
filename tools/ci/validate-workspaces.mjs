// tools/ci/validate-workspaces.mjs
import fs from "node:fs";
import path from "node:path";
const fail = (m) => { console.error("❌", m); process.exitCode = 1; };
const ok   = (m) => console.log("•", m);
const root = process.cwd();
const read = (p) => JSON.parse(fs.readFileSync(p, "utf8"));

const rootPkgPath = path.join(root, "package.json");
if (!fs.existsSync(rootPkgPath)) { fail("No package.json at repo root"); process.exit(1); }
const rootPkg = read(rootPkgPath);

// workspaces present
if (!Array.isArray(rootPkg.workspaces) || !rootPkg.workspaces.length) fail('Root package.json must declare "workspaces": ["packages/*"].');
// no runtime deps at root
if (rootPkg.dependencies && Object.keys(rootPkg.dependencies).length) fail('Root "dependencies" must be empty. Move runtime deps into packages/*.');
ok("Root package.json looks sane.");

const pkgsDir = path.join(root, "packages");
if (!fs.existsSync(pkgsDir)) { fail("packages/ folder not found"); process.exit(1); }
const pkgDirs = fs.readdirSync(pkgsDir).filter(d => fs.existsSync(path.join(pkgsDir, d, "package.json")));
if (!pkgDirs.length) fail("No packages found under packages/.");

for (const d of pkgDirs) {
  const p = path.join(pkgsDir, d, "package.json");
  const pj = read(p);
  if (!pj.name) fail(`packages/${d}/package.json missing "name"`);
  if (!/^@suite\//.test(pj.name)) fail(`packages/${d} name should start with "@suite/": got "${pj.name}"`);
  for (const bad of ["eslint","@typescript-eslint/parser","@typescript-eslint/eslint-plugin"]) {
    if (pj.dependencies && pj.dependencies[bad]) fail(`packages/${d} must not list "${bad}" in dependencies (devDependencies only).`);
  }
  if (d === "tab") {
    for (const want of ["react","react-dom"]) {
      if (!pj.dependencies || !pj.dependencies[want]) fail(`packages/tab missing dependency "${want}".`);
    }
  }
  if (d === "bot") {
    for (const want of ["express","botbuilder"]) {
      if (!pj.dependencies || !pj.dependencies[want]) fail(`packages/bot missing dependency "${want}".`);
    }
  }
  ok(`Checked ${pj.name}`);
}
if (process.exitCode) {
  console.error("\\n❌ Workspace validation failed. See messages above.");
  process.exit(1);
} else {
  console.log("\\n✅ Workspaces validation passed.");
}