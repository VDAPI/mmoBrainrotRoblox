// Unit tests of the S44 script cores: budgets, audit, stale data, robots.txt and the Wiki workflow.
import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parse } from "yaml";
import { findLeaks, hreflangProblems, pageFacts, parseAdminIds, parseCodes, pathOf } from "./audit-core.mjs";
import { budgetFor, closure, gzipSize, pageScripts, staticImports } from "./budgets-core.mjs";
import { metaWithoutCommit, porcelainPaths, staleFiles } from "./stale-core.mjs";
import config from "../budgets.config.mjs";
import { robotsTxt } from "../../src/lib/robots.ts";

describe("budgets core", () => {
  it("collects scripts, modulepreloads, island URLs and inline scripts (not JSON data)", () => {
    const html = `<link rel="modulepreload" href="/_astro/a.js"><script type="module" src="/_astro/b.js"></script>
      <astro-island component-url="/_astro/c.js" renderer-url="/_astro/d.js"></astro-island>
      <script>console.log(1)</script><script type="application/json">{"x":1}</script><script src="/pagefind/p.js"></script>`;
    const { urls, inline } = pageScripts(html);
    expect(urls.sort()).toEqual(["/_astro/a.js", "/_astro/b.js", "/_astro/c.js", "/_astro/d.js"]);
    expect(inline).toEqual(["console.log(1)"]);
  });

  it("follows static imports recursively and counts every file once", () => {
    const files = { "/_astro/a.js": 'import"./b.js";import{x}from"./c.js"', "/_astro/b.js": 'import"./c.js"', "/_astro/c.js": "export const x=1" };
    expect(staticImports(files["/_astro/a.js"], "/_astro/a.js")).toEqual(["/_astro/b.js", "/_astro/c.js"]);
    expect([...closure(["/_astro/a.js", "/_astro/b.js"], (u) => files[u] ?? null)].sort()).toEqual(["/_astro/a.js", "/_astro/b.js", "/_astro/c.js"]);
  });

  it("measures gzip and picks the budget rule of a page", () => {
    expect(gzipSize("a".repeat(1000))).toBeLessThan(100);
    expect(budgetFor("pl/mapa/index.html", config).kb).toBe(60);
    expect(budgetFor("en/bosses/grimrok/index.html", config).mode).toBe("own");
    expect(budgetFor("pl/przedmioty/index.html", config).kb).toBe(config.defaultKb);
  });
});

describe("audit core", () => {
  const site = "https://w.test";
  it("reads the facts of a page", () => {
    const f = pageFacts(`<html lang="pl"><head><title> A </title><meta name="description" content="d"><link rel="canonical" href="${site}/pl/a/"><link rel="alternate" hreflang="pl" href="${site}/pl/a/"><meta property="og:image" content="${site}/x.jpg"></head><body><h1>A</h1><img src="x" alt width="1" height="1"><a href="#">x</a></body></html>`);
    expect(f).toMatchObject({ lang: "pl", h1: 1, title: "A", description: "d", canonical: `${site}/pl/a/`, ogImage: `${site}/x.jpg` });
    expect(f.images[0].alt).toBe("");
    expect(f.badLinks.length).toBe(1);
    expect(pathOf("pl/a/index.html")).toBe("/pl/a/");
    expect(pathOf("404.html")).toBe("/404.html");
  });

  it("checks reciprocal hreflang", () => {
    const pages = new Map([
      ["/pl/a/", { pl: `${site}/pl/a/`, en: `${site}/en/a/`, "x-default": `${site}/pl/a/` }],
      ["/en/a/", { pl: `${site}/pl/b/`, en: `${site}/en/a/`, "x-default": `${site}/pl/b/` }],
    ]);
    expect(hreflangProblems("/pl/a/", pages.get("/pl/a/"), pages, site)).toEqual([`hreflang not reciprocal: /en/a/ points pl at /pl/b/`]);
    expect(hreflangProblems("/en/a/", pages.get("/en/a/"), pages, site).some((p) => p.includes("does not exist"))).toBe(true);
  });

  it("parses codes and admin ids and finds whole-word leaks", () => {
    const codes = parseCodes(readFileSync("test-fixtures/Codes.luau", "utf8"));
    expect(codes).toEqual(["VAELTHORN", "SECRET42"]);
    expect(parseAdminIds("AdminUserIds = { 123, 456 }, -- 789")).toEqual(["123", "456"]);
    expect(parseAdminIds("-- AdminUserIds = { 1 }\nAdminUserIds = {} :: { number }")).toEqual([]);
    expect(findLeaks("use SECRET42 now", ["SECRET42"], [])).toEqual(["code SECRET42"]);
    expect(findLeaks("SECRET420 and secret42", ["SECRET42"], [])).toEqual([]);
    expect(findLeaks("id 1234 / 123", [], ["123"])).toEqual(["admin id 123"]);
  });
});

describe("stale data core", () => {
  it("compares meta.json without the data commit and date", () => {
    const a = JSON.stringify({ dataCommit: "a", dataDate: "1", dataHash: "x" });
    const b = JSON.stringify({ dataCommit: "b", dataDate: "2", dataHash: "x" });
    const c = JSON.stringify({ dataCommit: "b", dataDate: "2", dataHash: "y" });
    expect(metaWithoutCommit(a)).toBe(metaWithoutCommit(b));
    const paths = porcelainPaths(" M wiki/src/data/meta.json\n M wiki/src/data/items.json\n?? wiki/public/img/items/x.webp\n M src/x.luau\n");
    expect(staleFiles(paths, a, b)).toEqual(["wiki/src/data/items.json"]);
    expect(staleFiles(paths, a, c)).toEqual(["wiki/src/data/meta.json", "wiki/src/data/items.json"]);
  });
});

describe("robots.txt", () => {
  it("allows production and blocks previews", () => {
    const prod = robotsTxt("https://w.test", false);
    expect(prod).toContain("Allow: /");
    expect(prod).toContain("Disallow: /pl/styleguide/");
    expect(prod).toContain("Sitemap: https://w.test/sitemap-index.xml");
    expect(robotsTxt("https://w.test", true)).toBe("User-agent: *\nDisallow: /\n");
  });
});

describe("Wiki workflow", () => {
  const wf = parse(readFileSync("../.github/workflows/wiki.yml", "utf8"));
  const steps = wf.jobs.wiki.steps;
  const index = (re) => steps.findIndex((s) => re.test(s.name ?? "") || re.test(s.uses ?? "") || re.test(s.run ?? ""));

  it("runs on push, PR, by hand and weekly, with path filters", () => {
    expect(Object.keys(wf.on).sort()).toEqual(["pull_request", "push", "schedule", "workflow_dispatch"]);
    expect(wf.on.schedule[0].cron).toBe("17 4 * * 1");
    for (const p of ["wiki/**", "src/shared/**", "tools/WikiData/**", ".github/workflows/wiki.yml"]) {
      expect(wf.on.push.paths).toContain(p);
      expect(wf.on.pull_request.paths).toContain(p);
    }
  });

  it("checks out the full history and runs the steps in order", () => {
    expect(steps[0].with["fetch-depth"]).toBe(0);
    const order = [/setup-rokit/, /setup-node/, /npm ci/, /npm run data/, /stale-data/, /tests\/run\.luau/, /npm run check/, /playwright install/, /npm run qa/, /wrangler-action/];
    const at = order.map(index);
    expect(at.every((i) => i >= 0)).toBe(true);
    expect([...at].sort((a, b) => a - b)).toEqual(at);
  });

  it("deploys only with both secrets and never from forks; previews are noindex", () => {
    expect(wf.jobs.wiki.env.HAS_CF).toContain("secrets.CLOUDFLARE_API_TOKEN");
    expect(wf.jobs.wiki.env.HAS_CF).toContain("secrets.CLOUDFLARE_ACCOUNT_ID");
    const deploy = steps[index(/wrangler-action/)];
    expect(deploy.if).toContain("env.HAS_CF == 'true'");
    expect(deploy.if).toContain("github.event.pull_request.head.repo.full_name == github.repository");
    expect(deploy.with.apiToken).toBe("${{ secrets.CLOUDFLARE_API_TOKEN }}");
    expect(deploy.with.accountId).toBe("${{ secrets.CLOUDFLARE_ACCOUNT_ID }}");
    const check = steps[index(/npm run check/)];
    expect(check.env.PUBLIC_NOINDEX).toContain("pull_request");
    expect(steps.some((s) => (s.run ?? "").includes("Brak sekretów Cloudflare"))).toBe(true);
  });

  it("ships the Cloudflare headers file", () => {
    expect(existsSync("public/_headers")).toBe(true);
    if (existsSync("dist")) expect(existsSync("dist/_headers")).toBe(true);
  });
});
