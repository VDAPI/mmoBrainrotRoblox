import { defineConfig } from "vitest/config";

// S44: unit tests of the wiki (src) and of the pure cores of the build scripts (scripts/lib); e2e/ is Playwright.
export default defineConfig({ test: { include: ["src/**/*.test.ts", "scripts/**/*.test.mjs"] } });
