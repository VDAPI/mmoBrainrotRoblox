// JS budgets (S44), pure parts: which scripts a page loads and their gzip size, each file counted once.
// A page's JS = <script src>, <link rel="modulepreload">, the component-url / renderer-url / before-hydration-url of
// <astro-island> and their static imports (recursively), plus inline <script> bodies (not JSON data blocks).
// Dynamic import() is not followed (loaded on demand, e.g. panzoom on the map).
import { gzipSync } from "node:zlib";

/** Script URLs and inline script bodies of a page. */
export function pageScripts(html) {
  const urls = new Set();
  for (const m of html.matchAll(/<script\b[^>]*\bsrc="([^"]+\.js)"/g)) urls.add(m[1]);
  for (const m of html.matchAll(/<link\b[^>]*\brel="modulepreload"[^>]*\bhref="([^"]+)"/g)) urls.add(m[1]);
  for (const m of html.matchAll(/<link\b[^>]*\bhref="([^"]+)"[^>]*\brel="modulepreload"/g)) urls.add(m[1]);
  for (const m of html.matchAll(/\b(?:component|renderer|before-hydration)-url="([^"]+\.js)"/g)) urls.add(m[1]);
  const inline = [];
  for (const m of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/g)) {
    const attrs = m[1];
    if (/\bsrc=/.test(attrs) || /type="application\/(ld\+)?json"/.test(attrs)) continue;
    if (m[2].trim()) inline.push(m[2]);
  }
  return { urls: [...urls].filter((u) => u.startsWith("/") && !u.startsWith("/pagefind/")), inline };
}

/** Static imports of a module ("./x.js" relative to the module, resolved to a site path). */
export function staticImports(code, from) {
  const dir = from.slice(0, from.lastIndexOf("/") + 1);
  const out = [];
  for (const m of code.matchAll(/(?:\bimport|\bfrom)\s*["'](\.{1,2}\/[^"']+\.js)["']/g)) {
    const parts = (dir + m[1]).split("/");
    const stack = [];
    for (const p of parts) {
      if (p === "..") stack.pop();
      else if (p !== ".") stack.push(p);
    }
    out.push(stack.join("/"));
  }
  return out;
}

/** Every file a page loads (entry URLs and their static imports), each once. `read(url)` gives the code or null. */
export function closure(entries, read) {
  const seen = new Set();
  const stack = [...entries];
  while (stack.length > 0) {
    const url = stack.pop();
    if (seen.has(url)) continue;
    const code = read(url);
    if (code === null) continue;
    seen.add(url);
    for (const next of staticImports(code, url)) if (!seen.has(next)) stack.push(next);
  }
  return seen;
}

export const gzipSize = (text) => gzipSync(typeof text === "string" ? Buffer.from(text) : text).length;

/** Budget of a page path ("pl/mapa/index.html") from the config table: the first matching rule, else the default. */
export function budgetFor(page, config) {
  for (const rule of config.rules) if (rule.match.test(page)) return rule;
  return { kb: config.defaultKb, mode: "all", match: /.*/ };
}
