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