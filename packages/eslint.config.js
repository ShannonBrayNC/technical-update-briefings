// eslint.config.js (root)
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["packages/**/{server,src,tab}/**/*.{ts,tsx,js}", "server/**/*.{ts,tsx,js}"],
    languageOptions: { ecmaVersion: 2023, sourceType: "module" },
    rules: {
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }]
    }
  }
];
