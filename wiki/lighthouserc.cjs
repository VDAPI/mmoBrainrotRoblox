// npm run lighthouse (S44): Lighthouse CI on the built site (dist/), mobile preset, the key pages of
// scripts/shots.pages.mjs without the 404. Every category must reach 0.95. Run locally without PUBLIC_NOINDEX (it
// would lower SEO). Reports go to .lighthouse/.
const { execFileSync } = require("node:child_process");

// KEY_PAGES lives in an ES module: read it through a short node call (lhci loads this file synchronously).
const pages = JSON.parse(
  execFileSync(process.execPath, ["--input-type=module", "-e", "const m = await import('./scripts/shots.pages.mjs'); console.log(JSON.stringify(m.KEY_PAGES));"], { encoding: "utf8" })
    .trim()
    .split("\n")
    .pop(),
);

let chromePath;
try {
  chromePath = require("playwright").chromium.executablePath();
} catch {
  chromePath = undefined;
}

module.exports = {
  ci: {
    collect: {
      staticDistDir: "./dist",
      url: pages.filter((p) => p.name !== "404").map((p) => `http://localhost${p.path}`),
      numberOfRuns: 1,
      ...(chromePath ? { chromePath } : {}),
      settings: { chromeFlags: "--headless=new --no-sandbox" },
    },
    assert: {
      assertMatrix: [
        {
          matchingUrlPattern: "^(?!.*/szukaj/).*$",
          assertions: {
            "categories:performance": ["error", { minScore: 0.95 }],
            "categories:accessibility": ["error", { minScore: 0.95 }],
            "categories:best-practices": ["error", { minScore: 0.95 }],
            "categories:seo": ["error", { minScore: 0.95 }],
          },
        },
        {
          // The search page is noindex on purpose (results are not content; docs/WIKI.md "Decyzje" S44), which
          // Lighthouse counts against SEO. Every other category keeps the 0.95 threshold.
          matchingUrlPattern: ".*/szukaj/.*",
          assertions: {
            "categories:performance": ["error", { minScore: 0.95 }],
            "categories:accessibility": ["error", { minScore: 0.95 }],
            "categories:best-practices": ["error", { minScore: 0.95 }],
          },
        },
      ],
    },
    upload: { target: "filesystem", outputDir: ".lighthouse" },
  },
};
