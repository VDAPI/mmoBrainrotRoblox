// Unit tests of the S44 script cores: budgets, audit, stale data, robots.txt and the Wiki workflow; WIKI-GRAFIKA: art.
import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parse } from "yaml";
import { findLeaks, hreflangProblems, pageFacts, parseAdminIds, parseCodes, pathOf } from "./audit-core.mjs";
import { budgetFor, closure, gzipSize, pageScripts, staticImports } from "./budgets-core.mjs";
import { metaWithoutCommit, porcelainPaths, staleFiles } from "./stale-core.mjs";
import { alphaBounds, cropBox, itemOriginals, outputsOf, planArt, prunePublished, resolveId, safeName } from "./art-core.mjs";
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

describe("art core (WIKI-GRAFIKA)", () => {
  const published = {
    class: new Set(["Mage", "Warrior"]),
    portrait: new Set(["Mage"]),
    skill: new Set(["fireball"]),
    element: new Set(["fire"]),
    guild: new Set([]),
    profile: new Set([]),
    quest: new Set(["wolfFang"]),
    service: new Set(["blacksmith"]),
    keybind: new Set(["win_map"]),
    pass: new Set([]),
    item: new Set(["eq/sword1h@10", "mat/ore", "mat/ore_copper", "eq/wand"]),
  };
  const files = [
    "tylko_2d/klasy/class_mage.png",
    "tylko_2d/klasy/portrait_mage.png",
    "tylko_2d/klasy/portrait_hunter.png",
    "tylko_2d/umiejetnosci/mage/skill_fireball.png",
    "tylko_2d/umiejetnosci/mage/skill_manaShield.png",
    "tylko_2d/zywioly/element_fire.png",
    "tylko_2d/questy/quest_wolfFang.png",
    "tylko_2d/mapa/service_blacksmith.png",
    "tylko_2d/mapa/map_boss.png",
    "tylko_2d/hud/menu_map.png",
    "tylko_2d/hud/vip.png",
    "modele_3d/bronie/sword1h/sword1h_10.png",
    "modele_3d/bronie/wand/wand_1.png",
    "tylko_2d/materialy/ore_copper.png",
  ];
  const pictures = new Set(["eq/sword1h@10", "mat/ore_copper", "eq/wand@1"]);

  it("maps pictures to published ids only; hidden skills, other classes and unknown files stay unused", () => {
    const { entries, unused } = planArt(files, published, pictures);
    expect(entries.map((e) => e.key)).toEqual([
      "class/Mage",
      "element/fire",
      "item/eq/sword1h@10",
      "item/mat/ore_copper",
      "keybind/win_map",
      "portrait/Mage",
      "quest/wolfFang",
      "service/blacksmith",
      "skill/fireball",
    ]);
    expect(unused).toEqual([
      "modele_3d/bronie/wand/wand_1.png",
      "tylko_2d/hud/vip.png",
      "tylko_2d/klasy/portrait_hunter.png",
      "tylko_2d/mapa/map_boss.png",
      "tylko_2d/umiejetnosci/mage/skill_manaShield.png",
    ]);
    const sword = entries.find((e) => e.key === "item/eq/sword1h@10");
    expect(sword.file).toBe("item/eq-sword1h_10");
    expect(outputsOf(sword)).toEqual(["item/eq-sword1h_10-256.webp"]);
    expect(entries.find((e) => e.key === "service/blacksmith").mask).toBe(true);
    expect(outputsOf(entries.find((e) => e.key === "portrait/Mage"))).toEqual(["portrait/Mage-320.webp", "portrait/Mage-640.webp"]);
  });

  it("finds item originals like tools/icons/import_graphics.py and resolves ids ignoring case", () => {
    expect(itemOriginals("eq/armor_heavy@20")).toEqual(["modele_3d/bronie/armor_heavy/armor_heavy_20.png", "tylko_2d/ekwipunek/armor_heavy/armor_heavy_20.png"]);
    expect(itemOriginals("uniq/unique_grimrok_fang")).toContain("tylko_2d/unikaty/unique_grimrok_fang.png");
    expect(itemOriginals("bless/sage")).toEqual(["tylko_2d/blogoslawienstwa/blessing_sage.png"]);
    expect(itemOriginals("misc/backpack_20")).toContain("tylko_2d/plecaki/backpack_20.png");
    expect(itemOriginals("eq/sword1h")).toEqual([]);
    expect(resolveId("mage", new Set(["Mage"]))).toBe("Mage");
    expect(resolveId("ab", new Set(["Ab", "aB"]))).toBeNull();
    expect(resolveId("zz", new Set(["Ab"]))).toBeNull();
    expect(safeName("eq/sword1h@10")).toBe("eq-sword1h_10");
  });

  it("drops entries of ids no longer published", () => {
    const kept = prunePublished({ "skill/fireball": { file: "skill/fireball" }, "skill/prayer": { file: "skill/prayer" } }, published);
    expect(Object.keys(kept)).toEqual(["skill/fireball"]);
  });

  it("crops to the picture with a margin, centre squares and the top of portraits", () => {
    const raw = Buffer.alloc(10 * 10 * 4);
    for (const [x, y] of [[2, 3], [5, 7]]) raw[(y * 10 + x) * 4 + 3] = 255;
    const box = alphaBounds(raw, 10, 10);
    expect(box).toEqual({ left: 2, top: 3, right: 6, bottom: 8 });
    expect(alphaBounds(Buffer.alloc(16), 2, 2)).toBeNull();
    const trim = cropBox("trim", 10, 10, box);
    expect(trim.side).toBe(Math.round(5 / 0.88));
    expect(trim.top).toBe(3 - Math.floor((trim.side - 5) / 2));
    expect(cropBox("square", 1024, 1024, null)).toEqual({ left: 0, top: 0, side: 1024 });
    expect(cropBox("portrait", 1024, 1536, null)).toEqual({ left: 0, top: 77, side: 1024 });
  });
});
