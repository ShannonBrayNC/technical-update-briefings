import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  root: __dirname,
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": "http://localhost:3978",
      "/healthz": "http://localhost:3978",
      "/api/messages": "http://localhost:3978",
    },
  },
  build: { outDir: "dist", emptyOutDir: true },
});
