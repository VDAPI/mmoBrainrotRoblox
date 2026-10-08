// Quest pages (S42): the main chain grouped by region, side quests grouped by the NPC who gives them (ordered by
// their requirements), neighbours in the chain or the arc and links of objectives. Data from quests.json only.
import type { DailyTemplate, MainQuest, QuestObjective, SideQuest } from "../data/types";
import type { Lang } from "../i18n/routes";
import { getItem, load } from "./data";
import { name } from "./i18n";
import { npcHref } from "./links";
import { sectionHref } from "./sections";
import { caveOf, getMapInfo, placeHref } from "./world";

export const mainQuests = (): MainQuest[] => [...load("quests").main].sort((a, b) => a.order - b.order);
export const sideQuests = (): SideQuest[] => load("quests").side;
export const dailyTemplates = (): DailyTemplate[] => [...load("quests").daily.templates].sort((a, b) => a.minLevel - b.minLevel || (a.id < b.id ? -1 : 1));

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

/** Where a quest happens: the region of its first placed objective outside the city, else the giver's map. */
export function questRegion(q: MainQuest | SideQuest): string {
  for (const o of q.objectives) {
    const r = regionOfMap(o.where?.cave ?? o.where?.map);
    if (r && r !== "city") return r;
  }
  return regionOfMap(npcMap(q.giver)) ?? "city";
}

/** The main chain cut into runs of the same region (the story returns to the city, so a region may repeat). */
export function mainGroups(): { region: string; quests: MainQuest[] }[] {
  const out: { region: string; quests: MainQuest[] }[] = [];
  for (const q of mainQuests()) {
    const region = questRegion(q);
    const last = out[out.length - 1];
    if (last && last.region === region) last.quests.push(q);
    else out.push({ region, quests: [q] });
  }
  return out;
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

/** Previous and next quest: in the main chain, or in the side quest's arc. */
export function neighboursOf(id: string): { prev?: MainQuest | SideQuest; next?: MainQuest | SideQuest } {
  const found = questById(id);
  if (!found) return {};
  const list: (MainQuest | SideQuest)[] = found.kind === "main" ? mainQuests() : sideOrdered().filter((q) => q.arc === found.q.arc);
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
