// JS budgets of the S39 pages (gzip): the page's own module scripts and the chunks they import, without the layout
// script and the Ctrl+K palette island shared by every page. Exits 1 when a page goes over its budget.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { gzipSync } from "node:zlib";

const DIST = "dist";
const BUDGETS = [
  { page: "pl/bestiariusz/index.html", kb: 8 },
  { page: "pl/bestiariusz/wolf/index.html", kb: 5 },
  { page: "pl/bossy/grimrok/index.html", kb: 4 },
];
const SHARED = /\/_astro\/(Base\.astro|SearchPalette|client\.svelte|render\.|class\.|input\.)/;

function chunks(file, seen) {
  if (seen.has(file)) return;
  seen.add(file);
  const code = readFileSync(join(DIST, file), "utf8");
  for (const m of code.matchAll(/(?:import|from)\s*["'](\.\/[^"']+\.js)["']/g)) {
    const next = `/_astro/${m[1].slice(2)}`;
    if (!SHARED.test(next)) chunks(next, seen);
  }
}

let failed = false;
for (const { page, kb } of BUDGETS) {
  const path = join(DIST, page);
  if (!existsSync(path)) {
    console.error(`budgets: missing ${page}`);
    failed = true;
    continue;
  }
  const html = readFileSync(path, "utf8");
  const seen = new Set();
  for (const m of html.matchAll(/<script type="module" src="(\/_astro\/[^"]+\.js)"/g)) if (!SHARED.test(m[1])) chunks(m[1], seen);
  const size = [...seen].reduce((n, f) => n + gzipSync(readFileSync(join(DIST, f))).length, 0);
  const ok = size <= kb * 1024;
  if (!ok) failed = true;
  console.log(`budgets: ${page} ${(size / 1024).toFixed(1)} KB / ${kb} KB${ok ? "" : "  OVER"}`);
}
process.exit(failed ? 1 : 0);
