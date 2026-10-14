// Quest pages (S42): the main chain, side quests grouped by the NPC who gives them (ordered by their requirements),
// neighbours in the chain or the arc and links of objectives. Data from quests.json only. S109: the story grouped by
// its chapters (quests.json `chapters`, the game's Main.CHAPTERS), side quests by the land of their giver, the hunting
// contracts by land, the boss quests and the weekly contracts.
import type { BossQuest, Contract, DailyTemplate, MainQuest, QuestChapter, QuestObjective, SideQuest, WeeklyTemplate } from "../data/types";
import type { Lang } from "../i18n/routes";
import { getItem, load } from "./data";
import { name } from "./i18n";
import { npcHref } from "./links";
import { sectionHref } from "./sections";
import { caveOf, getMapInfo, placeHref } from "./world";

export const mainQuests = (): MainQuest[] => [...load("quests").main].sort((a, b) => a.order - b.order);
export const sideQuests = (): SideQuest[] => load("quests").side;
export const dailyTemplates = (): DailyTemplate[] => [...load("quests").daily.templates].sort((a, b) => a.minLevel - b.minLevel || (a.id < b.id ? -1 : 1));
export const weeklyTemplates = (): WeeklyTemplate[] => [...load("quests").weekly.templates].sort((a, b) => a.minLevel - b.minLevel || (a.id < b.id ? -1 : 1));
export const bossQuests = (): BossQuest[] => [...load("quests").bossQuests].sort((a, b) => a.level - b.level || (a.id < b.id ? -1 : 1));
export const chapters = (): QuestChapter[] => [...load("quests").chapters].sort((a, b) => a.n - b.n);

/** The chapter of a main quest (S109). */
export function chapterOf(q: MainQuest): QuestChapter | undefined {
  return load("quests").chapters.find((c) => c.n === q.chapter);
}

/** The story grouped by its chapters in chapter order, every main quest once, in the game's order (S109). */
export function mainChapters(): { chapter: QuestChapter; quests: MainQuest[] }[] {
  const chain = mainQuests();
  return chapters()
    .map((chapter) => ({ chapter, quests: chain.filter((q) => q.chapter === chapter.n) }))
    .filter((g) => g.quests.length > 0);
}

/** Lands in the order of the game (the city first). */
export const LANDS = ["city", "meadows", "duskwood", "ashen", "frostpeak"];
const landRank = (land: string) => (LANDS.indexOf(land) < 0 ? LANDS.length : LANDS.indexOf(land));

/** The hunting contracts grouped by the land of their hunting ground, in land order (S109). */
export function contractsByMap(): { map: string; contracts: Contract[] }[] {
  const out: { map: string; contracts: Contract[] }[] = [];
  for (const c of [...load("quests").contracts.list].sort((a, b) => a.level - b.level)) {
    const group = out.find((g) => g.map === c.map);
    if (group) group.contracts.push(c);
    else out.push({ map: c.map, contracts: [c] });
  }
  return out.sort((a, b) => landRank(a.map) - landRank(b.map));
}

export type AnyQuest = { kind: "main"; q: MainQuest } | { kind: "side"; q: SideQuest };

export function questById(id: string): AnyQuest | undefined {
  const main = load("quests").main.find((q) => q.id === id);
  if (main) return { kind: "main", q: main };
  const side = load("quests").side.find((q) => q.id === id);
  return side ? { kind: "side", q: side } : undefined;
}

const npcMap = (id: string): string | undefined => load("npcs").npcs.find((n) => n.id === id)?.map;

/** Region (city or region map) of a map id; caves and dungeons count to their region. */
export function regionOfMap(mapId: string | undefined): string | undefined {
  if (!mapId) return undefined;
  const map = getMapInfo(mapId);
  if (map?.kind === "city" || map?.kind === "region") return mapId;
  const cave = caveOf(mapId);
  if (cave) return cave.region;
  if (map?.kind === "dungeon") {
    const gate = load("portals").portals.find((p) => p.target === mapId);
    return gate ? regionOfMap(gate.map) : undefined;
  }
  return undefined;
}

/** Where a quest happens: the region of its first placed objective outside the city, else (a main quest) its
 * chapter's land, else the giver's map. */
export function questRegion(q: MainQuest | SideQuest): string {
  for (const o of q.objectives) {
    const r = regionOfMap(o.where?.cave ?? o.where?.map);
    if (r && r !== "city") return r;
  }
  if ("chapter" in q) {
    const land = chapterOf(q)?.map;
    if (land && land !== "city") return land;
  }
  return regionOfMap(npcMap(q.giver)) ?? "city";
}

/** Side quests ordered so that every quest comes after the ones it requires (then by level and id). */
export function sideOrdered(list: SideQuest[] = sideQuests()): SideQuest[] {
  const rest = [...list].sort((a, b) => a.level - b.level || (a.id < b.id ? -1 : 1));
  const done = new Set<string>();
  const ids = new Set(list.map((q) => q.id));
  const out: SideQuest[] = [];
  while (rest.length > 0) {
    const i = rest.findIndex((q) => q.requires.every((r) => done.has(r) || !ids.has(r)));
    const [next] = rest.splice(i < 0 ? 0 : i, 1);
    out.push(next);
    done.add(next.id);
  }
  return out;
}

/** Side quests grouped by the NPC who gives them; groups ordered by their first quest in sideOrdered. */
export function sideGroups(): { giver: string; quests: SideQuest[] }[] {
  const out: { giver: string; quests: SideQuest[] }[] = [];
  for (const q of sideOrdered()) {
    const group = out.find((g) => g.giver === q.giver);
    if (group) group.quests.push(q);
    else out.push({ giver: q.giver, quests: [q] });
  }
  return out;
}

/** The land of a side quest: the region of its giver's map (S109). */
export const sideLand = (q: SideQuest): string => regionOfMap(npcMap(q.giver)) ?? "city";

/** Side quest groups (by giver) per land of the giver, in land order (S109). */
export function sideByLand(): { land: string; groups: { giver: string; quests: SideQuest[] }[]; arcs: number; count: number }[] {
  const out: { land: string; groups: { giver: string; quests: SideQuest[] }[]; arcs: number; count: number }[] = [];
  for (const g of sideGroups()) {
    const land = sideLand(g.quests[0]);
    let entry = out.find((e) => e.land === land);
    if (!entry) {
      entry = { land, groups: [], arcs: 0, count: 0 };
      out.push(entry);
    }
    entry.groups.push(g);
  }
  for (const e of out) {
    const quests = e.groups.flatMap((g) => g.quests);
    e.count = quests.length;
    e.arcs = new Set(quests.map((q) => q.arc)).size;
  }
  return out.sort((a, b) => landRank(a.land) - landRank(b.land));
}

/** Previous and next quest: in the main chain within its chapter (S109), or in the side quest's arc. */
export function neighboursOf(id: string): { prev?: MainQuest | SideQuest; next?: MainQuest | SideQuest } {
  const found = questById(id);
  if (!found) return {};
  const list: (MainQuest | SideQuest)[] =
    found.kind === "main" ? mainQuests().filter((q) => q.chapter === found.q.chapter) : sideOrdered().filter((q) => q.arc === found.q.arc);
  const i = list.findIndex((q) => q.id === id);
  return { prev: list[i - 1], next: list[i + 1] };
}

export function arcQuests(arc: string): SideQuest[] {
  return sideOrdered().filter((q) => q.arc === arc);
}

/** Link of the thing an objective is about (monster, boss, item, NPC, place), or null. */
export function objectiveHref(lang: Lang, o: QuestObjective): string | null {
  if (o.monster) return sectionHref(lang, "bestiary", o.monster);
  if (o.boss) return sectionHref(lang, "bosses", o.boss);
  if (o.item && getItem(o.item)) return sectionHref(lang, "items", o.item);
  if (o.npc) return npcHref(lang, o.npc);
  const place = o.where?.area ?? o.where?.cave ?? o.area ?? o.map ?? o.where?.map;
  return place ? placeHref(lang, place) : null;
}

export function npcName(id: string, lang: Lang): string {
  return name(load("npcs").npcs.find((n) => n.id === id)?.name, lang) || id;
}

/** "Rola · Imię" when the name does not already start with the role's first word ("Kowal Dorgan", "Zarządca Ignacy"). */
export function npcLabel(id: string, lang: Lang): string {
  const npc = load("npcs").npcs.find((n) => n.id === id);
  if (!npc) return id;
  const own = name(npc.name, lang);
  const role = npc.role ? name(npc.role, lang) : "";
  const first = role.split(" ")[0].toLowerCase();
  return role && !own.toLowerCase().startsWith(first) ? `${role} · ${own}` : own;
}
