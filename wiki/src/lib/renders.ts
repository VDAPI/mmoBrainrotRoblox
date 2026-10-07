// Monster, boss and pet renders (S38, tools/wiki-renders): build-time lookup of public/img/mobs (node:fs, never in
// islands). Files: <id>[-elite|-elite2].webp (512), -128.webp (thumbnail), bosses also -1024.webp and -p2/-p3.webp.
import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

export type RenderVariant = "normal" | "elite" | "elite2" | "boss" | "pet";
export type RenderSize = "thumb" | "full" | "hero";

export const MOBS_DIR = join(process.cwd(), "public", "img", "mobs");

let cache: Set<string> | null = null;

function list(dir: string): Set<string> {
  return new Set(existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith(".webp")) : []);
}

/** Names of the render files (the default folder is read once per build). */
export function renderFiles(dir = MOBS_DIR): Set<string> {
  if (dir !== MOBS_DIR) return list(dir);
  cache ??= list(MOBS_DIR);
  return cache;
}

function baseName(id: string, variant: RenderVariant): string {
  return variant === "elite" || variant === "elite2" ? `${id}-${variant}` : id;
}

/**
 * URL of a render or null (placeholder). A missing variant falls back to the normal look; a missing thumbnail or hero
 * size falls back to the 512 file.
 */
export function renderSrc(id: string, variant: RenderVariant = "normal", size: RenderSize = "full", files = renderFiles()): string | null {
  for (const base of variant === "elite" || variant === "elite2" ? [baseName(id, variant), id] : [id]) {
    const suffix = size === "thumb" ? "-128" : size === "hero" ? "-1024" : "";
    if (suffix && files.has(`${base}${suffix}.webp`)) return `/img/mobs/${base}${suffix}.webp`;
    if (files.has(`${base}.webp`)) return `/img/mobs/${base}.webp`;
  }
  return null;
}
