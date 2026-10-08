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
  // S40: pages with Svelte islands, everything they load (layout and palette included)
  { page: "pl/przedmioty/index.html", kb: 50, all: true },
  { page: "pl/przedmioty/sword2h_35/index.html", kb: 50, all: true },
  { page: "pl/ulepszanie/index.html", kb: 50, all: true },
  // S41: skill planner island (limit from the session plan)
  { page: "pl/klasy/Mage/index.html", kb: 35, all: true },
];
const SHARED = /\/_astro\/(Base\.astro|SearchPalette|client\.svelte|render\.|class\.|input\.)/;

function chunks(file, seen, all = false) {
  if (seen.has(file)) return;
  seen.add(file);
  const code = readFileSync(join(DIST, file), "utf8");
  for (const m of code.matchAll(/(?:import|from)\s*["'](\.\/[^"']+\.js)["']/g)) {
    const next = `/_astro/${m[1].slice(2)}`;
    if (all || !SHARED.test(next)) chunks(next, seen, all);
  }
}

let failed = false;
for (const { page, kb, all = false } of BUDGETS) {
  const path = join(DIST, page);
  if (!existsSync(path)) {
    console.error(`budgets: missing ${page}`);
    failed = true;
    continue;
  }
  const html = readFileSync(path, "utf8");
  const seen = new Set();
  for (const m of html.matchAll(/<script type="module" src="(\/_astro\/[^"]+\.js)"/g)) if (all || !SHARED.test(m[1])) chunks(m[1], seen, all);
  // islands: component-url / renderer-url of <astro-island>
  if (all) for (const m of html.matchAll(/(?:component|renderer)-url="(\/_astro\/[^"]+\.js)"/g)) chunks(m[1], seen, all);
  const size = [...seen].reduce((n, f) => n + gzipSync(readFileSync(join(DIST, f))).length, 0);
  const ok = size <= kb * 1024;
  if (!ok) failed = true;
  console.log(`budgets: ${page} ${(size / 1024).toFixed(1)} KB / ${kb} KB${ok ? "" : "  OVER"}`);
}
process.exit(failed ? 1 : 0);
