// npm run qa (S44): accessibility, keyboard, motion and layout tests of the built wiki (e2e/*.e2e.ts) against
// `astro preview` on a fixed port, on a phone (390 x 844, touch) and a desktop (1440 x 900). Build first.
import { defineConfig, devices } from "@playwright/test";

const PORT = 4329;

export default defineConfig({
  testDir: "e2e",
  testMatch: /.*\.e2e\.ts$/,
  fullyParallel: true,
  workers: process.env.CI ? 2 : undefined,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }]] : [["list"]],
  timeout: 60_000,
  use: { baseURL: `http://localhost:${PORT}`, colorScheme: "dark", trace: "retain-on-failure" },
  projects: [
    { name: "mobile", use: { ...devices["Desktop Chrome"], viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true } },
    { name: "desktop", use: { ...devices["Desktop Chrome"], viewport: { width: 1440, height: 900 } } },
  ],
  webServer: {
    command: `npx astro preview --port ${PORT}`,
    url: `http://localhost:${PORT}/pl/`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
