// Entries of the Ctrl+K palette (/<lang>/palette.json), built at build time from search.json: short keys keep the
// file small. Links point at the entity pages of ready sections; otherwise null (the palette opens the search page).
import type { Rarity } from "../data/types";
import type { Lang } from "../i18n/routes";
import { load } from "./data";
import { name, t } from "./i18n";
import { isReady } from "./sections";
import { href } from "../i18n/routes";

export interface PaletteEntry {
  t: string; // type: item, monster, boss, map, area, cave, npc, quest, skill, class
  id: string;
  n: string; // name
  h: string | null; // link or null (section not ready)
  m: string; // meta line
  r?: string; // rarity key (items)
}

export function entityHref(lang: Lang, type: string, id: string, map?: string, cls?: string): string | null {
  switch (type) {
    case "item":
      return isReady("items") ? href(lang, "items", id) : null;
    case "monster":
      return isReady("bestiary") ? href(lang, "bestiary", id) : null;
    case "boss":
      return isReady("bosses") ? href(lang, "bosses", id) : null;
    case "map":
      return isReady("regions") ? href(lang, "regions", id) : null;
    case "area":
    case "cave":
      return isReady("regions") && map ? href(lang, "regions", map, id) : null;
    case "quest":
      return isReady("quests") ? href(lang, "quests", id) : null;
    case "skill":
      return isReady("classes") && cls ? `${href(lang, "classes", cls)}?s=${id}#s-${id}` : null;
    case "class":
      return isReady("classes") ? href(lang, "classes", id) : null;
    default:
      return null;
  }
}

export function paletteEntries(lang: Lang): PaletteEntry[] {
  const raritiesByKey = new Map<string, Rarity>(load("rarities").rarities.map((r) => [r.key, r]));
  return load("search").entries.map((e) => {
    const parts: string[] = [];
    if (e.rarity && raritiesByKey.has(e.rarity)) parts.push(name(raritiesByKey.get(e.rarity)!.name, lang));
    if (e.level !== undefined) parts.push(t(lang, "level", { level: e.level }));
    return {
      t: e.type,
      id: e.id,
      n: name(e.name, lang),
      h: entityHref(lang, e.type, e.id, e.map, e.class),
      m: parts.join(" · "),
      r: e.type === "item" ? e.rarity : undefined,
    };
  });
}
