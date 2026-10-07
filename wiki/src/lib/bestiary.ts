// Bestiary list (S39, build time): one entry per occurring monster variant (a variant with spawns) and one per boss,
// with what the cards, the table and the filters need. Numbers come from the export (monsters.json, bosses.json).
import type { Boss, Monster, MonsterVariant } from "../data/types";
import type { Lang } from "../i18n/routes";
import { bosses, getItem, getMap, load, monsters } from "./data";
import type { FilterEntry, Rank } from "./bestiary-filters";
import { name } from "./i18n";
import { normalize } from "./search";
import { sectionHref, searchHref } from "./sections";

export type MonsterRank = Exclude<Rank, "boss">;
export const VARIANTS: MonsterRank[] = ["normal", "elite", "elite2"];

/** A material dropped by at most this many monster kinds counts as a signature drop. */
export const SIGNATURE_MAX_KINDS = 5;

export interface Place {
  id: string; // area, cave or dungeon id
  map: string; // map id with the place (region map for areas, the cave map for caves)
  region: string; // region map id
  zone: string;
  name: string;
}

export interface BestiaryEntry extends FilterEntry {
  id: string;
  variant: Rank;
  family?: string;
  element?: string;
  damageKind: string;
  placeList: Place[];
  signature?: string; // item id
  href: string;
}

/** Variants that live in the world (have spawns), in rank order. */
export function occurringVariants(m: Monster): MonsterRank[] {
  return VARIANTS.filter((v) => (m.variants[v]?.spawns.length ?? 0) > 0);
}

/** The variant a page / share image opens with: the first occurring one, else normal. */
export function pageVariantsOrNormal(m: Monster): MonsterRank {
  return occurringVariants(m)[0] ?? "normal";
}

/** Final level range of a variant (spawn level + the variant's level bonus). */
export function finalLevels(v: MonsterVariant): [number, number] {
  const levels = v.levels.map((l) => l.finalLevel);
  return levels.length > 0 ? [Math.min(...levels), Math.max(...levels)] : [v.levelMin, v.levelMax];
}

let kindsByMaterial: Map<string, number> | null = null;

/** How many monster kinds drop each material (occurring variants only). */
export function materialKinds(): Map<string, number> {
  if (kindsByMaterial) return kindsByMaterial;
  const sets = new Map<string, Set<string>>();
  for (const m of monsters()) {
    for (const v of occurringVariants(m)) {
      for (const mat of m.variants[v].loot.materials) {
        if (!sets.has(mat.id)) sets.set(mat.id, new Set());
        sets.get(mat.id)!.add(m.id);
      }
    }
  }
  kindsByMaterial = new Map([...sets].map(([id, s]) => [id, s.size]));
  return kindsByMaterial;
}

/** The variant's material dropped by the fewest kinds (usually the monster part), if that is rare enough. */
export function signatureDrop(m: Monster, variant: MonsterRank): string | undefined {
  const kinds = materialKinds();
  const best = [...(m.variants[variant]?.loot.materials ?? [])]
    .map((mat) => ({ id: mat.id, kinds: kinds.get(mat.id) ?? 99, chance: mat.chance }))
    .sort((a, b) => a.kinds - b.kinds || a.chance - b.chance || (a.id < b.id ? -1 : 1))[0];
  return best && best.kinds <= SIGNATURE_MAX_KINDS ? best.id : undefined;
}

/** Places of a variant from its spawns (areas and caves), unique, in spawn order. */
export function placesOf(m: Monster, variant: MonsterRank, lang: Lang): Place[] {
  const out: Place[] = [];
  const areas = load("areas").areas;
  const caves = load("caves").caves;
  for (const s of m.variants[variant]?.spawns ?? []) {
    const id = s.cave ?? s.area ?? s.map;
    if (out.some((p) => p.id === id)) continue;
    if (s.cave) {
      const cave = caves.find((c) => c.id === s.cave);
      out.push({ id, map: s.cave, region: s.map, zone: getMap(s.cave)?.zone ?? "red", name: name(cave?.name, lang) || id });
    } else {
      const area = areas.find((a) => a.id === s.area);
      const map = getMap(s.map);
      out.push({ id, map: s.map, region: s.map, zone: map?.zone ?? "yellow", name: name(area?.name ?? map?.name, lang) || id });
    }
  }
  return out;
}

export function monsterHref(lang: Lang, id: string, variant: Rank = "normal"): string {
  const base = sectionHref(lang, "bestiary", id) ?? searchHref(lang, id);
  return variant === "normal" || variant === "boss" ? base : `${base}?v=${variant}`;
}

export function bossHref(lang: Lang, id: string): string {
  return sectionHref(lang, "bosses", id) ?? searchHref(lang, id);
}

function bossEntry(b: Boss, lang: Lang, order: number): BestiaryEntry {
  const dungeon = getMap(b.dungeon);
  const cave = b.gateCave ? load("caves").caves.find((c) => c.id === b.gateCave) : undefined;
  const label = name(b.name, lang);
  const places: Place[] = [{ id: b.dungeon, map: b.dungeon, region: b.region, zone: dungeon?.zone ?? "red", name: name(dungeon?.name, lang) || b.dungeon }];
  return {
    id: b.id,
    variant: "boss",
    rank: "boss",
    name: label,
    levelMin: b.level,
    levelMax: b.level,
    damageKind: b.damageKind,
    placeList: places,
    places: [b.dungeon, ...(cave ? [cave.id] : [])],
    regions: [b.region],
    signature: b.loot.named[0],
    key: normalize(`${label} ${b.id} ${name(b.name, lang === "pl" ? "en" : "pl")}`),
    href: bossHref(lang, b.id),
    order,
  };
}

/** Every bestiary entry in data order (monsters by kind, variants by rank, then bosses). */
export function bestiaryEntries(lang: Lang): BestiaryEntry[] {
  const out: BestiaryEntry[] = [];
  for (const m of monsters()) {
    for (const v of occurringVariants(m)) {
      const info = m.variants[v];
      const label = name(info.name, lang);
      const places = placesOf(m, v, lang);
      const [min, max] = finalLevels(info);
      out.push({
        id: m.id,
        variant: v,
        rank: v,
        name: label,
        levelMin: min,
        levelMax: max,
        family: m.family,
        element: m.element,
        damageKind: m.damageKind,
        placeList: places,
        places: [...new Set(places.map((p) => p.map))],
        regions: [...new Set(places.map((p) => p.region))],
        signature: signatureDrop(m, v),
        key: normalize(`${label} ${m.id}`),
        href: monsterHref(lang, m.id, v),
        order: out.length,
      });
    }
  }
  for (const b of bosses()) out.push(bossEntry(b, lang, out.length));
  return out;
}

/** Highest level in the bestiary (for the level bands). */
export function maxLevel(entries: BestiaryEntry[]): number {
  return Math.max(...entries.map((e) => e.levelMax));
}

/** Region filter rows: each region map with its level range, followed by its caves. */
export function regionTree(lang: Lang): { id: string; name: string; zone: string; min: number; max: number; cave: boolean }[] {
  const out: { id: string; name: string; zone: string; min: number; max: number; cave: boolean }[] = [];
  const caves = load("caves").caves;
  const regions: string[] = [];
  for (const c of caves) if (!regions.includes(c.region)) regions.push(c.region);
  for (const r of regions) {
    const map = getMap(r);
    if (!map) continue;
    out.push({ id: r, name: name(map.name, lang), zone: map.zone, min: map.minLevel, max: map.maxLevel, cave: false });
    for (const c of caves.filter((x) => x.region === r).sort((a, b) => a.levelMin - b.levelMin)) {
      out.push({ id: c.id, name: name(c.name, lang), zone: getMap(c.id)?.zone ?? "red", min: c.levelMin, max: c.levelMax, cave: true });
    }
  }
  return out;
}

export function itemName(id: string | undefined, lang: Lang): string {
  return id ? name(getItem(id)?.name, lang) : "";
}
