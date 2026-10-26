import { svelte } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vitest/config";

export default defineConfig({
    plugins: [svelte(), tailwindcss()],
    server: {
        // Same origin as production: nginx forwards /api to the API container.
        proxy: { "/api": process.env.SETTLE_API ?? "http://localhost:8080" },
    },
    test: {
        include: ["src/**/*.test.ts"],
    },
});
