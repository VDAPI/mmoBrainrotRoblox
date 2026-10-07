// Item icons (S40, build time only): the manifest src/generated/item-icons.json written by `npm run icons`
// (scripts/item-icons.mjs). iconFor() gives the base URL of an icon ("/img/items/<file>", sizes -64.webp / -128.webp)
// or null: no atlases (S35 not done) or a missing file -> the glyph of S36.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

interface Manifest {
  version: number;
  atlasHash: string;
  files: Record<string, string>;
}

const MANIFEST = join(process.cwd(), "src", "generated", "item-icons.json");
const DIR = join(process.cwd(), "public", "img", "items");
let manifest: Manifest | null = null;

export function iconManifest(): Manifest {
  manifest ??= existsSync(MANIFEST) ? (JSON.parse(readFileSync(MANIFEST, "utf8")) as Manifest) : { version: 0, atlasHash: "", files: {} };
  return manifest;
}

/** Base URL of an item's icon (mage weapons per element), or null for the glyph. */
export function iconFor(itemId: string, element?: string): string | null {
  const files = iconManifest().files;
  const file = (element ? files[`${itemId}:${element}`] : undefined) ?? files[itemId];
  if (!file || !existsSync(join(DIR, `${file}-64.webp`))) return null;
  return `/img/items/${file}`;
}
