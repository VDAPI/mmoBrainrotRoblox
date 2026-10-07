// Builds /<lang>/map-data.json for the world map island (S37): names in one language, ids for everything else,
// links resolved here. Build time only.
import type { Lang } from "../i18n/routes";
import { load } from "./data";
import { name, t } from "./i18n";
import type { MapData, MapRank } from "./mapdata.types";
import { searchHref, sectionHref } from "./sections";
import { allQuests, bossOfCave, caves, mapDescription, mapList, maps, monstersOn, npcs, placeHref, areas } from "./world";

export function mapData(lang: Lang): MapData {
  const zones = load("mechanics").zones;
  const out: MapData = {
    maps: {},
    order: mapList().map((m) => m.id),
    areas: {},
    caves: {},
    monsters: {},
    bosses: {},
    portals: {},
    npcs: {},
    quests: [],
    zones: {},
    ranks: {},
    profiles: {},
    search: [],
    bestiary: sectionHref(lang, "bestiary"),
    limit: load("mapsearch").limit,
  };
  const withSvg = new Set(["city", ...maps().filter((m) => m.kind === "region" || m.kind === "cave").map((m) => m.id)]);
  for (const m of maps()) {
    out.maps[m.id] = {
      name: name(m.name, lang),
      kind: m.kind,
      zone: m.zone,
      min: m.minLevel,
      max: m.maxLevel,
      size: [m.size.x, m.size.z],
      region: caves().find((c) => c.id === m.id)?.region,
      href: placeHref(lang, m.id),
      desc: mapDescription(lang, m),
      route: m.route ?? [],
      mons: monstersOn(m.id).map((x): [string, MapRank, number, number] => [x.monster.id, x.rank, x.levelMin, x.levelMax]),
      svg: withSvg.has(m.id),
    };
  }
  for (const a of areas()) {
    out.areas[a.id] = {
      name: name(a.name, lang),
      map: a.map,
      min: a.levelMin,
      max: a.levelMax,
      groups: a.groups,
      count: a.monsters,
      respawn: [a.respawnMin, a.respawnMax],
      profile: a.profile,
      mons: monstersOn(a.map, { area: a.id }).map((x): [string, number, number] => [x.monster.id, x.levelMin, x.levelMax]),
      href: placeHref(lang, a.id),
    };
  }
  const gather = new Map(load("gather").nodes.map((n) => [n.id, n]));
  for (const c of caves()) {
    const boss = bossOfCave(c.id);
    out.caves[c.id] = {
      name: name(c.name, lang),
      region: c.region,
      min: c.levelMin,
      max: c.levelMax,
      normal: c.normal,
      elites: c.elites,
      elite2: c.elite2,
      ores: c.ores.map((o) => (gather.get(o) ? name(gather.get(o)!.name, lang) : o)),
      oreCount: c.oreCount,
      boss: boss?.id,
      href: placeHref(lang, c.id),
    };
  }
  for (const m of load("monsters").monsters) {
    out.monsters[m.id] = [name(m.variants.normal?.name ?? m.name, lang), name(m.variants.elite?.name, lang), name(m.variants.elite2?.name, lang)];
  }
  for (const b of load("bosses").bosses) {
    const label = name(b.name, lang);
    out.bosses[b.id] = { name: label, level: b.level, cave: b.gateCave ?? "", href: sectionHref(lang, "bosses", b.id) ?? searchHref(lang, label) };
  }
  for (const p of load("portals").portals) out.portals[p.id] = { map: p.map, target: p.target, kind: p.kind };
  const services = load("npcs").services;
  const quests = allQuests();
  for (const n of npcs()) {
    if (n.decoration) continue;
    out.npcs[n.id] = {
      name: name(n.name, lang),
      role: n.role ? name(n.role, lang) : "",
      map: n.map,
      services: n.services.filter((s) => s !== "talk" && s !== "story").map((s) => name(services[s], lang)),
      quests: quests.filter((q) => q.giver === n.id).map((q) => q.id),
    };
  }
  for (const q of quests) {
    const title = name(q.title, lang);
    const placed = q.objectives.filter((o) => o.where);
    out.quests.push({
      id: q.id,
      title,
      level: q.level,
      href: sectionHref(lang, "quests", q.id) ?? searchHref(lang, title),
      giver: q.giver,
      goal: name((placed[0] ?? q.objectives[0])?.label, lang),
      places: placed.map((o) => ({ map: o.where!.map, area: o.where!.area, cave: o.where!.cave, npc: o.where!.npc })),
    });
  }
  for (const z of Object.keys(zones)) out.zones[z] = { name: name(zones[z].name, lang), rule: name(zones[z].rule, lang) };
  const variants = load("mechanics").variants;
  out.ranks = { normal: name(variants.normal?.name, lang), elite: name(variants.elite?.name, lang), elite2: name(variants.elite2?.name, lang), boss: t(lang, "rank.boss") };
  for (const [id, p] of Object.entries(load("mechanics").areaProfiles ?? {})) out.profiles[id] = { icon: p.icon, name: name(p.name, lang), color: p.color };
  out.search = load("mapsearch")[lang].map((e) => ({ kind: e.kind, id: e.id, map: e.map, x: e.x, z: e.z, texts: e.texts }));
  return out;
}
