// Audit of dist/ (S44, part of npm run check): language, one <h1>, unique titles, descriptions, canonical and
// reciprocal hreflang from SITE_URL, sitemap vs noindex, og:image files, <img> alt/width/height, empty links, leaks of
// reward codes and administrator ids, and missing monster renders / item icons (warnings). Exits 1 on an error.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { findLeaks, hreflangProblems, pageFacts, parseAdminIds, parseCodes, pathOf } from "./lib/audit-core.mjs";

const DIST = "dist";
const SITE = (process.env.SITE_URL || "https://vaelthorn-wiki.pages.dev").replace(/\/+$/, "");
const NOINDEX = process.env.PUBLIC_NOINDEX === "1";
const GAME_NAME = "VAELTHORN";
// Pages that are not normal pages: the language redirect at the root.
const SPECIAL = new Set(["index.html"]);

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path, out);
    else out.push(path);
  }
  return out;
}

const errors = [];
const warnings = [];
const files = walk(DIST);
const rel = (p) => relative(DIST, p).split(sep).join("/");
const htmlFiles = files.filter((f) => f.endsWith(".html")).map(rel);
const facts = new Map(htmlFiles.map((f) => [f, pageFacts(readFileSync(join(DIST, f), "utf8"))]));
const byPath = new Map([...facts].map(([f, x]) => [pathOf(f), x.hreflang]));

const titles = { pl: new Map(), en: new Map() };
for (const [file, x] of facts) {
  if (SPECIAL.has(file)) continue;
  const path = pathOf(file);
  const lang = path.startsWith("/en/") ? "en" : "pl";
  const err = (m) => errors.push(`${path}: ${m}`);
  if (x.lang !== lang) err(`<html lang="${x.lang}"> (expected ${lang})`);
  if (x.h1 !== 1) err(`${x.h1} <h1>`);
  if (!x.title) err("empty <title>");
  else {
    const seen = titles[lang].get(x.title);
    if (seen && !x.robots?.includes("noindex")) err(`same <title> as ${seen}: "${x.title}"`);
    titles[lang].set(x.title, path);
  }
  if (!x.description) warnings.push(`${path}: no meta description`);
  if (x.robots?.includes("noindex") && !NOINDEX) {
    // 404 and styleguide pages: no canonical checks needed beyond existence
  }
  if (path.endsWith(".html") && file.includes("404")) continue; // copies of the 404 pages
  if (!x.canonical || !x.canonical.startsWith(`${SITE}/`)) err(`canonical "${x.canonical}" not absolute from ${SITE}`);
  for (const p of hreflangProblems(path, x.hreflang, byPath, SITE)) err(p);
  if (!x.ogImage || !x.ogImage.startsWith(`${SITE}/`)) err(`og:image "${x.ogImage}" not absolute`);
  else if (!existsSync(join(DIST, x.ogImage.slice(SITE.length + 1)))) err(`og:image file missing: ${x.ogImage}`);
  for (const img of x.images) {
    if (img.alt === undefined) err(`<img> without alt: ${img.tag.slice(0, 100)}`);
    if (!img.width || !img.height) err(`<img> without width/height: ${img.tag.slice(0, 100)}`);
  }
  for (const a of x.badLinks) err(`empty link: ${a.slice(0, 100)}`);
}

// Sitemap: only indexable pages, every listed page exists.
const sitemapFiles = files.filter((f) => /sitemap-\d+\.xml$/.test(f));
const listed = new Set();
for (const f of sitemapFiles) for (const m of readFileSync(f, "utf8").matchAll(/<loc>([^<]+)<\/loc>/g)) listed.add(m[1]);
for (const url of listed) {
  if (!url.startsWith(`${SITE}/`)) errors.push(`sitemap: ${url} not absolute from ${SITE}`);
  if (url.includes("?")) errors.push(`sitemap: ${url} has a query`);
  const path = url.slice(SITE.length);
  const file = path.endsWith("/") ? `${path.slice(1)}index.html` : path.slice(1);
  const x = facts.get(file);
  if (!x) errors.push(`sitemap: ${url} does not exist`);
  else if (x.robots?.includes("noindex") && !NOINDEX) errors.push(`sitemap: ${url} is noindex`);
}
for (const [file, x] of facts) {
  if (x.robots?.includes("noindex") && listed.has(`${SITE}${pathOf(file)}`) && !NOINDEX) errors.push(`noindex page in sitemap: ${pathOf(file)}`);
}
if (!existsSync(join(DIST, "robots.txt"))) errors.push("no robots.txt");
if (!existsSync(join(DIST, "_headers"))) errors.push("no _headers");
for (const f of ["404.html", "pl/404.html", "en/404.html"]) if (!existsSync(join(DIST, f))) errors.push(`no ${f}`);

// Leaks: reward codes and administrator ids anywhere in the built text files.
const codesFile = join("..", "src", "shared", "Data", "Codes.luau");
const configFile = join("..", "src", "shared", "Config.luau");
let codes = existsSync(codesFile) ? parseCodes(readFileSync(codesFile, "utf8")) : [];
if (codes.includes(GAME_NAME)) {
  warnings.push(`reward code ${GAME_NAME} equals the game name: not searched`);
  codes = codes.filter((c) => c !== GAME_NAME);
}
const ids = existsSync(configFile) ? parseAdminIds(readFileSync(configFile, "utf8")) : [];
for (const f of files.filter((p) => /\.(html|json|js|xml|txt|css)$/.test(p))) {
  for (const leak of findLeaks(readFileSync(f, "utf8"), codes, ids)) errors.push(`LEAK ${rel(f)}: ${leak}`);
}

// Missing pictures (warnings; listed in docs/WIKI.md "Niedokończone").
const monsters = JSON.parse(readFileSync("src/data/monsters.json", "utf8")).monsters;
for (const m of monsters) if (!existsSync(join("public", "img", "mobs", `${m.id}.webp`))) warnings.push(`no render public/img/mobs/${m.id}.webp`);
if (existsSync(join("..", "art", "icons"))) {
  const manifest = existsSync("src/generated/item-icons.json") ? JSON.parse(readFileSync("src/generated/item-icons.json", "utf8")).files : {};
  const items = JSON.parse(readFileSync("src/data/items.json", "utf8")).items;
  const missing = items.filter((i) => !manifest[i.id]).map((i) => i.id);
  if (missing.length) warnings.push(`${missing.length} items without an icon: ${missing.slice(0, 10).join(", ")}${missing.length > 10 ? ", …" : ""}`);
}

console.log(`audit: ${htmlFiles.length} pages, ${listed.size} sitemap URLs, ${codes.length} codes and ${ids.length} admin ids searched`);
for (const w of warnings.slice(0, 20)) console.warn(`audit: warning: ${w}`);
if (warnings.length > 20) console.warn(`audit: … ${warnings.length - 20} more warnings`);
for (const e of errors.slice(0, 50)) console.error(`audit: ${e}`);
if (errors.length > 50) console.error(`audit: … ${errors.length - 50} more errors`);
process.exit(errors.length > 0 ? 1 : 0);
