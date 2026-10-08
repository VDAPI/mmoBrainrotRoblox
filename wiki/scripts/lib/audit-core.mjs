// Audit of the built pages (S44), pure parts: HTML facts of a page, reciprocal hreflang, leak search, parsers of the
// reward codes (src/shared/Data/Codes.luau) and the administrator ids (Config.AdminUserIds).

const attr = (tag, name) => new RegExp(`\\b${name}="([^"]*)"`).exec(tag)?.[1];
/** Attribute value, "" for a bare attribute (`<img alt>`), undefined when absent. */
const attrOrBare = (tag, name) => {
  const m = new RegExp(`\\s${name}(?:="([^"]*)")?(?=[\\s>/])`).exec(tag);
  return m ? (m[1] ?? "") : undefined;
};

/** Facts of one HTML page used by the checks. */
export function pageFacts(html) {
  const head = html.slice(0, html.indexOf("</head>") + 1 || html.length);
  const tags = (re) => [...head.matchAll(re)].map((m) => m[0]);
  const meta = (key, value) => tags(/<meta\b[^>]*>/g).find((t) => attr(t, key) === value);
  const links = tags(/<link\b[^>]*>/g);
  return {
    lang: /<html\b[^>]*\blang="([^"]*)"/.exec(html)?.[1] ?? "",
    h1: [...html.matchAll(/<h1\b/g)].length,
    title: /<title>([\s\S]*?)<\/title>/.exec(head)?.[1].trim() ?? "",
    description: meta("name", "description") ? attr(meta("name", "description"), "content") : undefined,
    robots: meta("name", "robots") ? attr(meta("name", "robots"), "content") : undefined,
    canonical: attr(links.find((l) => attr(l, "rel") === "canonical") ?? "", "href"),
    hreflang: Object.fromEntries(links.filter((l) => attr(l, "rel") === "alternate" && attr(l, "hreflang")).map((l) => [attr(l, "hreflang"), attr(l, "href")])),
    ogImage: meta("property", "og:image") ? attr(meta("property", "og:image"), "content") : undefined,
    images: [...html.matchAll(/<img\b[^>]*>/g)].map((m) => ({ tag: m[0], alt: attrOrBare(m[0], "alt"), width: attr(m[0], "width"), height: attr(m[0], "height") })),
    badLinks: [...html.matchAll(/<a\b[^>]*>/g)].map((m) => m[0]).filter((a) => /\bhref=""/.test(a) || /\bhref="#"/.test(a)),
  };
}

/** Site path of a dist file ("pl/x/index.html" -> "/pl/x/", "404.html" -> "/404.html"). */
export function pathOf(file) {
  return file.endsWith("index.html") ? `/${file.slice(0, -"index.html".length)}` : `/${file}`;
}

/** Problems with the hreflang triple of one page against the others (`pages`: path -> hreflang map). */
export function hreflangProblems(path, hreflang, pages, site) {
  const out = [];
  const local = (url) => (url && url.startsWith(site) ? url.slice(site.length) || "/" : null);
  for (const key of ["pl", "en", "x-default"]) {
    const target = local(hreflang[key]);
    if (!target) {
      out.push(`hreflang ${key} missing or not absolute`);
      continue;
    }
    if (!pages.has(target)) out.push(`hreflang ${key} -> ${target} does not exist`);
  }
  const lang = path.startsWith("/en/") ? "en" : "pl";
  const other = local(hreflang[lang === "pl" ? "en" : "pl"]);
  const back = other ? pages.get(other) : undefined;
  if (other && back && local(back[lang]) !== path) out.push(`hreflang not reciprocal: ${other} points ${lang} at ${local(back[lang])}`);
  return out;
}

/** `code = "…"` values of Codes.luau. */
export function parseCodes(luau) {
  return [...luau.matchAll(/\bcode\s*=\s*"([^"]+)"/g)].map((m) => m[1]);
}

/** Numbers inside `AdminUserIds = { … }` (comments ignored). */
export function parseAdminIds(luau) {
  const block = /AdminUserIds\s*=\s*\{([^}]*)\}/.exec(luau.replace(/--[^\n]*/g, ""));
  return block ? [...block[1].matchAll(/\d+/g)].map((m) => m[0]) : [];
}

/** Leaks in a text: codes as whole case-sensitive words, admin ids as whole numbers. */
export function findLeaks(text, codes, ids) {
  const out = [];
  for (const code of codes) if (new RegExp(`(?<![A-Za-z0-9_])${code}(?![A-Za-z0-9_])`).test(text)) out.push(`code ${code}`);
  for (const id of ids) if (new RegExp(`(?<!\\d)${id}(?!\\d)`).test(text)) out.push(`admin id ${id}`);
  return out;
}
