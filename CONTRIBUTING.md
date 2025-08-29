{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "Node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "jsx": "react-jsx",
    "outDir": "./dist",
    "baseUrl": "."
  },
  "include": [
    "packages/**/*.ts",
    "packages/**/*.tsx"
  ],
  "exclude": [
    "**/node_modules",
    "**/dist",
    "**/.venv"
  ]
}
