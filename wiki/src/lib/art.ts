// Owner's pictures (WIKI-GRAFIKA, build time only): the manifest src/generated/art.json written by `npm run art`
// (scripts/art.mjs; mapping rules in scripts/lib/art-core.mjs). Files: public/img/art/<kind>/<id>-<width>.webp. A kind
// without a picture for an id gives null and the page keeps its glyph. Item icons themselves come from
// src/lib/icons.ts (atlases, like the game); here only their 256 px file for 2x screens of the item page.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

export type ArtKind = "class" | "portrait" | "skill" | "element" | "guild" | "profile" | "quest" | "service" | "keybind" | "pass" | "item";

export interface ArtEntry {
  file: string;
  sizes: number[];
  hash: string;
  mask?: boolean;
}

export interface ArtManifest {
  version: number;
  entries: Record<string, ArtEntry>;
}

export const ART_MANIFEST = join(process.cwd(), "src", "generated", "art.json");
export const ART_DIR = join(process.cwd(), "public", "img", "art");
let manifest: ArtManifest | null = null;

export function artManifest(): ArtManifest {
  manifest ??= existsSync(ART_MANIFEST) ? (JSON.parse(readFileSync(ART_MANIFEST, "utf8")) as ArtManifest) : { version: 0, entries: {} };
  return manifest;
}

function entryOf(kind: ArtKind, id: string | null | undefined): ArtEntry | null {
  if (!id) return null;
  const e = artManifest().entries[`${kind}/${id}`];
  return e && existsSync(join(ART_DIR, `${e.file}-${e.sizes[0]}.webp`)) ? e : null;
}

/** Base URL ("/img/art/skill/fireball") of a picture with files -64.webp / -128.webp (ItemIcon, SkillNode), or null. */
export function artFor(kind: ArtKind, id: string | null | undefined): string | null {
  const e = entryOf(kind, id);
  return e ? `/img/art/${e.file}` : null;
}

/** 256 px file of an item picture (icon key, e.g. "eq/sword1h@20") for 2x screens of the 128 px item icon, or null. */
export function itemHd(iconKey: string | null | undefined): string | null {
  const e = entryOf("item", iconKey);
  return e && e.sizes.includes(256) ? `/img/art/${e.file}-256.webp` : null;
}

export interface ArtImg {
  src: string;
  srcset: string;
  sizes: string;
  width: number;
  height: number;
}

/**
 * <img> attributes of a picture shown at `size` CSS px (`mobile` px up to 767 px wide): every width as a `w`
 * candidate, so the browser takes the smallest sharp one for the screen. null without a picture.
 */
export function artImg(kind: ArtKind, id: string | null | undefined, size: number, mobile?: number): ArtImg | null {
  const e = entryOf(kind, id);
  if (!e) return null;
  const base = `/img/art/${e.file}`;
  const first = e.sizes.find((w) => w >= size) ?? e.sizes[e.sizes.length - 1];
  return {
    src: `${base}-${first}.webp`,
    srcset: e.sizes.map((w) => `${base}-${w}.webp ${w}w`).join(", "),
    sizes: mobile !== undefined ? `(max-width: 767px) ${mobile}px, ${size}px` : `${size}px`,
    width: size,
    height: size,
  };
}

/** URL of a white sign drawn as a CSS mask in the text colour (kinds with `mask`), or null. */
export function artMask(kind: ArtKind, id: string | null | undefined): string | null {
  const e = entryOf(kind, id);
  return e?.mask ? `/img/art/${e.file}-${e.sizes[0]}.webp` : null;
}
