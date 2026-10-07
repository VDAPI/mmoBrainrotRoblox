// Search index after `astro build` (S36): Pagefind over dist/ (pages with data-pagefind-body) plus the records of
// sections without pages from dist/wiki-records/<lang>.json, written to dist/pagefind. Also copies the language 404
// pages to /pl/404.html and /en/404.html (Cloudflare Pages serves the nearest 404.html).
import { copyFileSync, existsSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";
import * as pagefind from "pagefind";

const DIST = "dist";

const { index, errors } = await pagefind.createIndex({});
if (!index) {
  console.error("pagefind:", errors);
  process.exit(1);
}
// Only pages that mark their body are indexed (home, styleguide and 404 have none). Pagefind indexes every page
// when none has the mark, so the directory is skipped until an entity page (S37+) exists.
function* htmlFiles(dir) {
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) yield* htmlFiles(path);
    else if (entry.endsWith(".html")) yield path;
  }
}
const marked = [...htmlFiles(join(DIST, "pl")), ...htmlFiles(join(DIST, "en"))].some((file) =>
  readFileSync(file, "utf8").includes("data-pagefind-body"),
);
const added = marked ? await index.addDirectory({ path: DIST, glob: "{pl,en}/**/*.html" }) : { errors: [], page_count: 0 };
if (added.errors.length > 0) {
  console.error(added.errors);
  process.exit(1);
}
let records = 0;
for (const lang of ["pl", "en"]) {
  const file = join(DIST, "wiki-records", `${lang}.json`);
  if (!existsSync(file)) continue;
  for (const record of JSON.parse(readFileSync(file, "utf8"))) {
    const result = await index.addCustomRecord(record);
    if (result.errors.length > 0) {
      console.error(result.errors);
      process.exit(1);
    }
    records += 1;
  }
}
const written = await index.writeFiles({ outputPath: join(DIST, "pagefind") });
if (written.errors.length > 0) {
  console.error(written.errors);
  process.exit(1);
}
await pagefind.close();
rmSync(join(DIST, "wiki-records"), { recursive: true, force: true });

for (const lang of ["pl", "en"]) {
  const page = join(DIST, lang, "404", "index.html");
  if (existsSync(page)) copyFileSync(page, join(DIST, lang, "404.html"));
}
console.log(`pagefind: ${added.page_count} pages + ${records} records`);
