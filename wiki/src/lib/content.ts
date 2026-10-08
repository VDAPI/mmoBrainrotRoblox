// Index of the written articles (S42): src/content/{mechanics,guides}/{pl,en}/<slug>.mdx read from disk at build time
// (and in tests, where astro:content is not available). The file name is the address in its language; PL and EN
// pages of one article share the frontmatter `key`. Rendering still goes through astro:content.
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import type { Lang } from "../i18n/routes";

export type Collection = "mechanics" | "guides";

export interface ContentEntry {
  collection: Collection;
  lang: Lang;
  slug: string;
  key: string;
  title: string;
  description: string;
  order: number;
  kicker?: string;
  levels?: [number, number];
  file: string;
}

const ROOT = join(process.cwd(), "src", "content");
const cache = new Map<Collection, ContentEntry[]>();

/** Plain `key: value` lines of a frontmatter block (strings, numbers, [a, b] pairs). */
export function frontmatter(text: string): Record<string, string> {
  const block = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text);
  const out: Record<string, string> = {};
  if (!block) return out;
  for (const line of block[1].split(/\r?\n/)) {
    const m = /^(\w+):\s*(.*)$/.exec(line);
    if (m) out[m[1]] = m[2].trim().replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1");
  }
  return out;
}

export function contentEntries(collection: Collection, root = ROOT): ContentEntry[] {
  const cached = root === ROOT ? cache.get(collection) : undefined;
  if (cached) return cached;
  const out: ContentEntry[] = [];
  for (const lang of ["pl", "en"] as Lang[]) {
    const dir = join(root, collection, lang);
    if (!existsSync(dir)) continue;
    for (const name of readdirSync(dir).filter((f) => f.endsWith(".mdx")).sort()) {
      const file = join(dir, name);
      const fm = frontmatter(readFileSync(file, "utf8"));
      const levels = /^\[\s*(\d+)\s*,\s*(\d+)\s*\]$/.exec(fm.levels ?? "");
      out.push({
        collection,
        lang,
        slug: name.replace(/\.mdx$/, ""),
        key: fm.key ?? "",
        title: fm.title ?? "",
        description: fm.description ?? "",
        order: Number(fm.order ?? 0),
        kicker: fm.kicker || undefined,
        levels: levels ? [Number(levels[1]), Number(levels[2])] : undefined,
        file,
      });
    }
  }
  out.sort((a, b) => a.order - b.order || (a.slug < b.slug ? -1 : 1));
  if (root === ROOT) cache.set(collection, out);
  return out;
}

export function contentEntry(collection: Collection, lang: Lang, key: string): ContentEntry | undefined {
  return contentEntries(collection).find((e) => e.lang === lang && e.key === key);
}

/** The other language's slug of an article (same key), or undefined. */
export function pairOf(entry: ContentEntry): ContentEntry | undefined {
  return contentEntries(entry.collection).find((e) => e.lang !== entry.lang && e.key === entry.key);
}

/** routes.alternate() helper: translated slugs of mechanics and guides, other sections keep their ids. */
export function translateSlug(key: string, from: Lang, slug: string): string | undefined {
  if (key !== "mechanics" && key !== "guides") return slug;
  const entry = contentEntries(key).find((e) => e.lang === from && e.slug === slug);
  return entry ? pairOf(entry)?.slug : undefined;
}
