// JS budgets of every page (S44; S39–S41 checked a few pages): sums the gzip size of the scripts each page in dist/
// loads (scripts/lib/budgets-core.mjs) against scripts/budgets.config.mjs, warns about heavy CSS, HTML and images,
// and fails on too many files for Cloudflare Pages. Report: .reports/budgets.json and the 20 heaviest pages.
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, relative, sep } from "node:path";
import config from "./budgets.config.mjs";
import { budgetFor, closure, gzipSize, pageScripts } from "./lib/budgets-core.mjs";

const DIST = "dist";
if (!existsSync(DIST)) {
  console.error("budgets: no dist/ (run npm run build first)");
  process.exit(1);
}

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path, out);
    else out.push(path);
  }
  return out;
}

const files = walk(DIST);
const rel = (p) => relative(DIST, p).split(sep).join("/");
const errors = [];
const warnings = [];

// Cloudflare Pages limits
if (files.length > config.files.max) errors.push(`${files.length} files in dist (limit ${config.files.max})`);
else if (files.length > config.files.warn) warnings.push(`${files.length} files in dist (warning from ${config.files.warn})`);
for (const f of files) {
  const size = statSync(f).size;
  if (size > config.files.maxFileMb * 1024 * 1024) errors.push(`${rel(f)}: ${(size / 1048576).toFixed(1)} MiB (limit ${config.files.maxFileMb} MiB)`);
  if (/\.(webp|png|jpe?g|avif|gif)$/.test(f) && size > config.warn.imageKb * 1024 && !rel(f).startsWith("img/og/")) warnings.push(`${rel(f)}: image ${(size / 1024).toFixed(0)} KB`);
}
const dirMb = (d) => (existsSync(d) ? walk(d).reduce((n, f) => n + statSync(f).size, 0) / 1048576 : 0);
if (dirMb("public/img/mobs") > config.warn.mobsMb) warnings.push(`public/img/mobs ${dirMb("public/img/mobs").toFixed(1)} MB`);
if (dirMb("public/img/items") > config.warn.itemsMb) warnings.push(`public/img/items ${dirMb("public/img/items").toFixed(1)} MB`);

const codeCache = new Map();
const read = (url) => {
  if (!codeCache.has(url)) {
    const path = join(DIST, url);
    codeCache.set(url, existsSync(path) ? readFileSync(path, "utf8") : null);
  }
  return codeCache.get(url);
};
const sizeCache = new Map();
const sizeOf = (url) => {
  if (!sizeCache.has(url)) sizeCache.set(url, gzipSize(read(url) ?? ""));
  return sizeCache.get(url);
};

const pages = files.filter((f) => f.endsWith(".html")).map(rel);
const sharedPage = existsSync(join(DIST, "pl/404/index.html")) ? "pl/404/index.html" : null;
const shared = sharedPage ? closure(pageScripts(readFileSync(join(DIST, sharedPage), "utf8")).urls, read) : new Set();

const report = [];
for (const page of pages) {
  const html = readFileSync(join(DIST, page), "utf8");
  const { urls, inline } = pageScripts(html);
  const all = closure(urls, read);
  const inlineKb = inline.reduce((n, s) => n + gzipSize(s), 0) / 1024;
  const allKb = [...all].reduce((n, u) => n + sizeOf(u), 0) / 1024 + inlineKb;
  const ownFiles = [...all].filter((u) => !shared.has(u));
  const ownKb = ownFiles.reduce((n, u) => n + sizeOf(u), 0) / 1024 + inlineKb;
  const htmlKb = gzipSize(html) / 1024;
  const cssKb = [...html.matchAll(/<link\b[^>]*rel="stylesheet"[^>]*href="([^"]+\.css)"/g)].reduce((n, m) => n + (existsSync(join(DIST, m[1])) ? gzipSize(readFileSync(join(DIST, m[1]))) : 0), 0) / 1024;
  const rule = budgetFor(page, config);
  // "all" rules replace the default limit; "own" rules come on top of it.
  const checks = rule.mode === "all" ? [{ kb: rule.kb, mode: "all" }] : [{ kb: config.defaultKb, mode: "all" }, { kb: rule.kb, mode: "own" }];
  for (const c of checks) {
    const value = c.mode === "own" ? ownKb : allKb;
    if (value > c.kb) errors.push(`${page}: ${value.toFixed(1)} KB ${c.mode} JS > ${c.kb} KB (${(c.mode === "own" ? ownFiles : [...all]).join(", ")})`);
  }
  if (cssKb > config.warn.cssKb) warnings.push(`${page}: CSS ${cssKb.toFixed(1)} KB gzip`);
  if (htmlKb > config.warn.htmlKb) warnings.push(`${page}: HTML ${htmlKb.toFixed(1)} KB gzip`);
  report.push({ page, allKb: +allKb.toFixed(1), ownKb: +ownKb.toFixed(1), htmlKb: +htmlKb.toFixed(1), cssKb: +cssKb.toFixed(1), budget: rule.kb, mode: rule.mode });
}

const pagefindKb = existsSync(join(DIST, "pagefind")) ? walk(join(DIST, "pagefind")).filter((f) => f.endsWith(".js")).reduce((n, f) => n + gzipSize(readFileSync(f)), 0) / 1024 : 0;
mkdirSync(".reports", { recursive: true });
writeFileSync(".reports/budgets.json", `${JSON.stringify({ files: files.length, pagefindJsKb: +pagefindKb.toFixed(1), warnings, errors, pages: report }, null, 2)}\n`);

const heavy = [...report].sort((a, b) => b.allKb - a.allKb).slice(0, 20);
console.log(`budgets: ${pages.length} pages, ${files.length} files, Pagefind JS ${pagefindKb.toFixed(1)} KB (after a query, not counted)`);
for (const r of heavy) console.log(`  ${r.allKb.toFixed(1).padStart(5)} KB all · ${r.ownKb.toFixed(1).padStart(5)} KB own · HTML ${r.htmlKb.toFixed(1).padStart(5)} KB  ${r.page}`);
for (const w of warnings.slice(0, 30)) console.warn(`budgets: warning: ${w}`);
if (warnings.length > 30) console.warn(`budgets: … ${warnings.length - 30} more warnings in .reports/budgets.json`);
for (const e of errors) console.error(`budgets: OVER ${e}`);
process.exit(errors.length > 0 ? 1 : 0);
