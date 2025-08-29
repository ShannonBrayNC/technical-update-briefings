// eslint.config.cjs (root)
// Reuse your existing .eslintrc.cjs files via the FlatCompat shim.
const { FlatCompat } = require('@eslint/eslintrc');
const js = require('@eslint/js');

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

module.exports = [
  // Ignore build artifacts
  {
    ignores: [
      '**/node_modules/**',
      '**/dist/**',
      '**/build/**',
      '**/.venv/**',
      '**/.cache/**',
    ],
  },

  // Base JS recommended
  js.configs.recommended,

  // Root .eslintrc.cjs (if you have one)
  ...compat.config({ extends: ['./.eslintrc.cjs'] }),

  // Per-package configs you already have:
  ...compat.config({
    files: ['packages/bot/**/*.{ts,tsx,js}'],
    extends: ['./packages/bot/.eslintrc.cjs'],
  }),
  ...compat.config({
    files: ['packages/shared/**/*.{ts,tsx,js}'],
    extends: ['./packages/shared/.eslintrc.cjs'],
  }),
  ...compat.config({
    files: ['packages/tab/**/*.{ts,tsx,js}'],
    extends: ['./packages/tab/.eslintrc.cjs'],
  }),
];
