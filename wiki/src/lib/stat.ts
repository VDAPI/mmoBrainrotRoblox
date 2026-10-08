// Numbers of the game in MDX texts (S42): <Stat path="mechanics.config.PvpToggleDelay" format="s" />. The path is
// "<file>.<key>…" over the exported JSON (wiki/src/data); a segment "name[id]" picks the record of an array by its
// `id` (or `key`), a number segment is an index. A path that does not resolve throws (the build fails with it), so a
// text can never show a number the game no longer has.
import type { Files } from "../data/types";
import type { Lang } from "../i18n/routes";
import { load } from "./data";
import { formatNumber } from "./format";

export type StatFormat = "num" | "pct" | "frac" | "x" | "s" | "min" | "h" | "gold" | "lvl";

const FILES = new Set<string>([
  "areas", "blessings", "bonuses", "bosses", "caves", "classes", "cosmetics", "crafting", "elements", "fish", "gather",
  "icons", "items", "maps", "mechanics", "meta", "monsters", "npcs", "portals", "progression", "quests", "rarities",
  "recipes", "shops", "skills", "stats", "titles", "upgrade",
]);

type Getter = (file: string) => unknown;

function step(value: unknown, segment: string, path: string): unknown {
  const pick = /^([^[\]]*)\[([^[\]]+)\]$/.exec(segment);
  if (pick) {
    const list = pick[1] === "" ? value : step(value, pick[1], path);
    if (!Array.isArray(list)) throw new Error(`stat "${path}": "${pick[1]}" is not a list`);
    const found = list.find((e) => e && typeof e === "object" && ((e as { id?: unknown }).id === pick[2] || (e as { key?: unknown }).key === pick[2]));
    if (found === undefined) throw new Error(`stat "${path}": no record "${pick[2]}"`);
    return found;
  }
  if (value === null || typeof value !== "object") throw new Error(`stat "${path}": nothing at "${segment}"`);
  if (Array.isArray(value) && /^\d+$/.test(segment)) {
    const v = value[Number(segment)];
    if (v === undefined) throw new Error(`stat "${path}": no index ${segment}`);
    return v;
  }
  if (!(segment in (value as Record<string, unknown>))) throw new Error(`stat "${path}": no key "${segment}"`);
  return (value as Record<string, unknown>)[segment];
}

/** Value at a data path ("mechanics.config.MaxLevel", "blessings.blessings[bless_str_5].stats.str"); throws if missing. */
export function resolvePath(path: string, get: Getter = (f) => load(f as keyof Files)): unknown {
  const parts = path.split(".");
  const file = parts.shift() ?? "";
  if (!FILES.has(file)) throw new Error(`stat "${path}": unknown data file "${file}"`);
  return parts.reduce<unknown>((value, segment) => step(value, segment, path), get(file));
}

/** A number at a data path; throws when the path is missing or the value is not a number. */
export function resolveStat(path: string, get?: Getter): number {
  const value = resolvePath(path, get);
  if (typeof value !== "number" || !Number.isFinite(value)) throw new Error(`stat "${path}": not a number (${JSON.stringify(value)})`);
  return value;
}

const UNITS: Record<Lang, { gold: string; lvl: (n: string) => string }> = {
  pl: { gold: "złota", lvl: (n) => `poz. ${n}` },
  en: { gold: "gold", lvl: (n) => `level ${n}` },
};

/** A number as text in a format: num, pct (15 → 15%), frac (0.15 → 15%), x (×1,5), s, min, h (from seconds), gold, lvl. */
export function formatStat(value: number, format: StatFormat = "num", lang: Lang, decimals?: number): string {
  const n = (v: number) => formatNumber(v, lang, decimals);
  switch (format) {
    case "pct":
      return `${n(value)}%`;
    case "frac":
      return `${n(Math.round(value * 100 * 1e6) / 1e6)}%`;
    case "x":
      return `×${n(value)}`;
    case "s":
      return `${n(value)} s`;
    case "min":
      return `${n(value / 60)} min`;
    case "h":
      return `${n(value / 3600)} h`;
    case "gold":
      return `${n(value)} ${UNITS[lang].gold}`;
    case "lvl":
      return UNITS[lang].lvl(n(value));
    default:
      return n(value);
  }
}
