// World pages (S37): the order of the map list like the game's map window (city, then each region followed by its
// caves by level), neighbours from portals, monsters of a map from the monster spawns, quests with an objective on a
// map, links to region / area / cave pages and to the map. Build time only (reads src/data through data.ts).
import type { Area, Boss, Cave, MainQuest, MapInfo, Monster, Npc, SideQuest } from "../data/types";
import { href, type Lang } from "../i18n/routes";
import { load } from "./data";
import { serialize, type MapLink } from "./deeplink";
import { name, t } from "./i18n";

export const maps = (): MapInfo[] => load("maps").maps;
export const areas = (): Area[] => load("areas").areas;
export const caves = (): Cave[] => load("caves").caves;
export const npcs = (): Npc[] => load("npcs").npcs;
export const bosses = (): Boss[] => load("bosses").bosses;
const mapById = () => new Map(maps().map((m) => [m.id, m]));

export function getMapInfo(id: string): MapInfo | undefined {
  return mapById().get(id);
}

/** Regions in the order of the caves file (= the game's REGIONS list), each followed by its caves by level. */
export function regionOrder(): string[] {
  const out: string[] = [];
  for (const c of caves()) if (!out.includes(c.region)) out.push(c.region);
  for (const m of maps()) if (m.kind === "region" && !out.includes(m.id)) out.push(m.id);
  return out;
}

export function cavesOf(region: string): Cave[] {
  return caves()
    .filter((c) => c.region === region)
    .sort((a, b) => a.levelMin - b.levelMin || a.levelMax - b.levelMax || (a.id < b.id ? -1 : 1));
}

/** Areas of a map sorted like AreaAdvice.sorted (min level, max level, id). */
export function areasOf(mapId: string): Area[] {
  return areas()
    .filter((a) => a.map === mapId)
    .sort((a, b) => a.levelMin - b.levelMin || a.levelMax - b.levelMax || (a.id < b.id ? -1 : 1));
}

/** The map list of the game's map window: city, then region -> its caves. Dungeons are shown with their cave. */
export function mapList(): MapInfo[] {
  const byId = mapById();
  const out: MapInfo[] = [];
  const city = byId.get("city");
  if (city) out.push(city);
  for (const r of regionOrder()) {
    const region = byId.get(r);
    if (region) out.push(region);
    for (const c of cavesOf(r)) {
      const m = byId.get(c.id);
      if (m) out.push(m);
    }
  }
  return out;
}

/** Maps reachable in one step (portals on the map and portals leading to it), unique, in portal order. */
export function neighbours(mapId: string): string[] {
  const out: string[] = [];
  for (const p of load("portals").portals) {
    const other = p.map === mapId ? p.target : p.target === mapId ? p.map : null;
    if (other && other !== mapId && !out.includes(other)) out.push(other);
  }
  return out;
}

export function caveOf(id: string): Cave | undefined {
  return caves().find((c) => c.id === id);
}

export function areaOf(id: string): Area | undefined {
  return areas().find((a) => a.id === id);
}

export function bossOfCave(caveId: string): Boss | undefined {
  return bosses().find((b) => b.gateCave === caveId);
}

export type Rank = "normal" | "elite" | "elite2";

export interface MapMonster {
  monster: Monster;
  rank: Rank;
  levelMin: number;
  levelMax: number;
  groups: number;
  count: number;
  respawnMin: number;
  respawnMax: number;
  areas: string[];
}

const RANKS: Rank[] = ["elite2", "elite", "normal"];

/** Monsters living on a map (or only in one area / cave of it) with their rank and levels there. */
export function monstersOn(mapId: string, only?: { area?: string }): MapMonster[] {
  const out: MapMonster[] = [];
  for (const m of load("monsters").monsters) {
    for (const rank of RANKS) {
      const variant = m.variants[rank];
      if (!variant) continue;
      const spawns = variant.spawns.filter((s) => (s.cave ?? s.map) === mapId && (!only?.area || s.area === only.area));
      if (spawns.length === 0) continue;
      out.push({
        monster: m,
        rank,
        levelMin: Math.min(...spawns.map((s) => s.levelMin)),
        levelMax: Math.max(...spawns.map((s) => s.levelMax)),
        groups: spawns.reduce((n, s) => n + s.groups, 0),
        count: spawns.reduce((n, s) => n + s.count, 0),
        respawnMin: Math.min(...spawns.map((s) => s.respawnMin)),
        respawnMax: Math.max(...spawns.map((s) => s.respawnMax)),
        areas: [...new Set(spawns.map((s) => s.area).filter((a): a is string => !!a))],
      });
    }
  }
  return out.sort((a, b) => RANKS.indexOf(a.rank) - RANKS.indexOf(b.rank) || b.levelMax - a.levelMax || a.levelMin - b.levelMin || (a.monster.id < b.monster.id ? -1 : 1));
}

export type AnyQuest = (MainQuest | SideQuest) & { side: boolean };

export function allQuests(): AnyQuest[] {
  const q = load("quests");
  return [...q.main.map((x) => ({ ...x, side: false })), ...q.side.map((x) => ({ ...x, side: true }))];
}

/** Quests with an objective on the map (or in the area / cave), plus quests handed out by NPCs of the map. */
export function questsAt(place: { map: string; area?: string; cave?: string }, withGivers = true): AnyQuest[] {
  const npcMap = new Map(npcs().map((n) => [n.id, n.map]));
  return allQuests()
    .filter((q) =>
      q.objectives.some((o) => {
        const w = o.where;
        if (!w) return false;
        if (place.area) return w.area === place.area;
        if (place.cave) return w.cave === place.cave || w.map === place.cave;
        return w.map === place.map;
      }) || (withGivers && !place.area && !place.cave && npcMap.get(q.giver) === place.map),
    )
    .sort((a, b) => a.level - b.level || (a.id < b.id ? -1 : 1));
}

/** First objective of a quest placed on the map / area / cave (for the "Poz. 31 · goal" line). */
export function objectiveAt(q: AnyQuest, place: { map: string; area?: string; cave?: string }) {
  return (
    q.objectives.find((o) => o.where && (place.area ? o.where.area === place.area : place.cave ? o.where.cave === place.cave || o.where.map === place.cave : o.where.map === place.map)) ??
    q.objectives[0]
  );
}

// Addresses -----------------------------------------------------------------------------------------------------

/** Page of a map, area, cave or dungeon (dungeons: the cave with the gate, #boss). */
export function placeHref(lang: Lang, id: string): string | null {
  const map = getMapInfo(id);
  if (map?.kind === "city" || map?.kind === "region") return href(lang, "regions", id);
  const cave = caveOf(id);
  if (cave) return href(lang, "regions", cave.region, cave.id);
  const area = areaOf(id);
  if (area) return href(lang, "regions", area.map, area.id);
  if (map?.kind === "dungeon") {
    const gate = load("portals").portals.find((p) => p.target === id && p.kind === "dungeon");
    const gateCave = gate ? caveOf(gate.map) : undefined;
    return gateCave ? `${href(lang, "regions", gateCave.region, gateCave.id)}#boss` : null;
  }
  return null;
}

export function mapHref(lang: Lang, link: MapLink = {}): string {
  return `${href(lang, "map")}${serialize(link)}`;
}

/** Map link that selects an element: the map it lies on and its id. */
export function mapLinkFor(id: string): MapLink {
  const area = areaOf(id);
  if (area) return { m: area.map, a: id };
  const cave = caveOf(id);
  if (cave) return { m: cave.region, a: id };
  const npc = npcs().find((n) => n.id === id);
  if (npc) return { m: npc.map, a: id };
  const map = getMapInfo(id);
  if (map) return map.kind === "dungeon" ? mapLinkFor(load("portals").portals.find((p) => p.target === id)?.map ?? "") : { a: id };
  return {};
}

// Texts ---------------------------------------------------------------------------------------------------------

export function levels(lang: Lang, min: number, max: number): string {
  return min === max ? t(lang, "level", { level: min }) : t(lang, "levelRangeCap", { min, max });
}

/** Respawn time: "30–45 s", "10–20 min", "90 s – 3 min". */
export function respawn(min: number, max: number): string {
  const minutes = (v: number) => v >= 120;
  const fmt = (v: number) => (minutes(v) ? `${Math.round(v / 60)} min` : `${v} s`);
  if (min === max) return fmt(min);
  if (minutes(min) === minutes(max)) return minutes(min) ? `${Math.round(min / 60)}–${Math.round(max / 60)} min` : `${min}–${max} s`;
  return `${fmt(min)} – ${fmt(max)}`;
}

/** Description of a map from data (the game has no map descriptions): levels, areas, caves, boss. */
export function mapDescription(lang: Lang, map: MapInfo): string {
  if (map.kind === "city") {
    const n = npcs().filter((x) => x.map === map.id && !x.decoration).length;
    return t(lang, "region.desc.city", { npcs: n });
  }
  if (map.kind === "region") {
    const boss = bosses().find((b) => cavesOf(map.id).some((c) => c.id === b.gateCave));
    return t(lang, boss ? "region.desc.region" : "region.desc.regionNoBoss", {
      min: map.minLevel,
      max: map.maxLevel,
      areas: areasOf(map.id).length,
      caves: cavesOf(map.id).length,
      boss: boss ? name(boss.name, lang) : "",
    });
  }
  const cave = caveOf(map.id);
  if (cave) {
    const boss = bossOfCave(cave.id);
    return t(lang, boss ? "region.desc.caveBoss" : "region.desc.cave", { min: cave.levelMin, max: cave.levelMax, boss: boss ? name(boss.name, lang) : "" });
  }
  return "";
}
