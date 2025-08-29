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