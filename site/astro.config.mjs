import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";
import { fileURLToPath } from "node:url";

export default defineConfig({
  site: "https://skillset.app",
  vite: {
    plugins: [tailwindcss()],
    server: { fs: { allow: [fileURLToPath(new URL("..", import.meta.url))] } },
  },
});
