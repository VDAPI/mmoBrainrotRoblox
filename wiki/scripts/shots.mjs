// npm run shots: builds when dist/ is missing, starts `astro preview` and saves full-page screenshots of
// scripts/shots.pages.mjs at 390x844 and 1440x900 to .shots/<name>-<width>.png.
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { PAGES } from "./shots.pages.mjs";

const PORT = 4329;
const SIZES = [
  { width: 390, height: 844 },
  { width: 1440, height: 900 },
];

if (!existsSync("dist")) {
  const build = spawnSync("npm", ["run", "build"], { stdio: "inherit", shell: true });
  if (build.status !== 0) process.exit(build.status ?? 1);
}

let chromium;
try {
  ({ chromium } = await import("playwright"));
} catch {
  console.error("Brak Playwright: npm install, potem npx playwright install chromium");
  process.exit(1);
}

const server = spawn("npx", ["astro", "preview", "--port", String(PORT)], { shell: true, stdio: "pipe" });
const base = `http://localhost:${PORT}`;
for (let i = 0; i < 60; i++) {
  try {
    const response = await fetch(`${base}/pl/`);
    if (response.ok) break;
  } catch {
    /* not up yet */
  }
  await new Promise((r) => setTimeout(r, 500));
}

let browser;
try {
  browser = await chromium.launch();
} catch {
  console.error("Brak przeglądarki: npx playwright install chromium");
  server.kill();
  process.exit(1);
}
mkdirSync(".shots", { recursive: true });
for (const size of SIZES) {
  const page = await browser.newPage({ viewport: size, deviceScaleFactor: 1, colorScheme: "dark" });
  for (const entry of PAGES) {
    await page.goto(base + entry.path, { waitUntil: "networkidle" });
    // lazy images (S38 renders) load only near the viewport: load them all before the full-page capture
    await page.evaluate(async () => {
      const imgs = [...document.images];
      for (const img of imgs) img.loading = "eager";
      await Promise.all(imgs.map((img) => img.decode().catch(() => null)));
    });
    await page.waitForTimeout(400);
    const file = `.shots/${entry.name}-${size.width}.png`;
    await page.screenshot({ path: file, fullPage: true });
    console.log(file);
  }
  await page.close();
}
await browser.close();
server.kill();
process.exit(0);
