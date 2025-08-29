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