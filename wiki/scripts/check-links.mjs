// Internal links of dist/: every href / src starting with "/" must point at a file of the build (gives "Soon instead
// of 404"). S39: also the og:image of every page when it points at our own domain. Exits 1 with the list of broken
// links.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { SITE_URL } from "../src/config.ts";

const DIST = "dist";
if (!existsSync(DIST)) {
  console.error("check-links: no dist/ (run npm run build)");
  process.exit(1);
}

function* htmlFiles(dir) {
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) yield* htmlFiles(path);
    else if (entry.endsWith(".html")) yield path;
  }
}

function exists(url) {
  const path = decodeURIComponent(url.split("#")[0].split("?")[0]);
  if (path === "" || path === "/") return true;
  const file = join(DIST, path);
  if (path.endsWith("/")) return existsSync(join(file, "index.html"));
  return existsSync(file) || existsSync(join(file, "index.html"));
}

const broken = [];
let checked = 0;
for (const file of htmlFiles(DIST)) {
  const html = readFileSync(file, "utf8");
  for (const match of html.matchAll(/(?:href|src)="(\/[^"]*)"/g)) {
    const url = match[1].replaceAll("&amp;", "&");
    if (url.startsWith("//") || url.startsWith("/pagefind/")) continue;
    checked += 1;
    if (!exists(url)) broken.push(`${file}: ${url}`);
  }
  for (const match of html.matchAll(/<meta property="og:image" content="([^"]*)"/g)) {
    if (!match[1].startsWith(SITE_URL)) continue;
    checked += 1;
    const url = match[1].slice(SITE_URL.length);
    if (!exists(url)) broken.push(`${file}: og:image ${url}`);
  }
}
if (broken.length > 0) {
  console.error(`check-links: ${broken.length} broken link(s):\n  ${[...new Set(broken)].slice(0, 50).join("\n  ")}`);
  process.exit(1);
}
console.log(`check-links: ${checked} internal links OK`);
