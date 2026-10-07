// What the home page features (S36): the hero item, the legendary item and the monster of the week. Pure functions
// over the exported data; the week is taken at build time (the site is static: weekly rebuild in S44).
import type { Boss, Item, Monster, Rarity } from "../data/types";

export interface IsoWeek {
  year: number;
  week: number;
  key: string; // "2026-W01"
}

/** ISO 8601 week of a date (UTC). */
export function isoWeek(date: Date): IsoWeek {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const year = d.getUTCFullYear();
  const start = Date.UTC(year, 0, 1);
  const week = Math.ceil(((d.getTime() - start) / 86400000 + 1) / 7);
  return { year, week, key: `${year}-W${String(week).padStart(2, "0")}` };
}

/** Stable 32-bit hash of a text (FNV-1a). */
export function hash(text: string): number {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h >>> 0;
}

/** Hero item: the highest fixed rarity (items with one possible rarity), then the highest level, then the id. */
export function pickFeaturedItem(items: Item[], rarities: Rarity[]): Item | undefined {
  const rank = (key: string) => rarities.findIndex((r) => r.key === key);
  const fixed = items.filter((i) => i.category === "equipment" && i.rarities.length === 1);
  fixed.sort((a, b) => {
    const r = rank(b.rarities[0]) - rank(a.rarities[0]);
    if (r !== 0) return r;
    if (a.requiredLevel !== b.requiredLevel) return b.requiredLevel - a.requiredLevel;
    return a.id < b.id ? -1 : 1;
  });
  return fixed[0];
}

/** Legendary item of the week: equipment that can be Legendary, picked by the week; upgrade 0–9 from the same seed. */
export function pickWeeklyLegendary(items: Item[], week: string): { item: Item; upgrade: number } | undefined {
  const pool = items.filter((i) => i.category === "equipment" && i.rarities.includes("legendary")).sort((a, b) => (a.id < b.id ? -1 : 1));
  if (pool.length === 0) return undefined;
  const h = hash(`legendary:${week}`);
  return { item: pool[h % pool.length], upgrade: Math.floor(h / pool.length) % 10 };
}

/** Monster of the week: kinds whose Elite variant really spawns; level = the top of that variant's range. */
export function pickMonsterOfWeek(monsters: Monster[], week: string): { monster: Monster; level: number } | undefined {
  const pool = monsters
    .filter((m) => (m.variants.elite?.spawns.length ?? 0) > 0)
    .sort((a, b) => (a.id < b.id ? -1 : 1));
  if (pool.length === 0) return undefined;
  const monster = pool[hash(`monster:${week}`) % pool.length];
  return { monster, level: monster.variants.elite.levelMax };
}

/** Boss behind the hero (S38): the boss that drops the hero item, else the highest level, then the id. */
export function pickHeroBoss(bosses: Boss[], featuredItem: Item | undefined): Boss | undefined {
  const byRank = [...bosses].sort((a, b) => (a.level !== b.level ? b.level - a.level : a.id < b.id ? -1 : 1));
  const dropIds = new Set((featuredItem?.sources.bosses ?? []).map((s) => s.boss));
  return byRank.find((b) => dropIds.has(b.id)) ?? byRank[0];
}
