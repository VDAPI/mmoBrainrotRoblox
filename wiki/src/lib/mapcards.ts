// Cards of map elements for the static maps of region / cave pages (S37): svg id -> { title, line, href }.
import type { Lang } from "../i18n/routes";
import { load } from "./data";
import { name, t } from "./i18n";
import { areasOf, cavesOf, getMapInfo, levels, npcs, placeHref, respawn } from "./world";

export interface Card {
  title: string;
  line: string;
  href?: string | null;
}

export function cardsFor(lang: Lang, mapId: string): Record<string, Card> {
  const out: Record<string, Card> = {};
  for (const a of areasOf(mapId)) {
    out[`area-${a.id}`] = {
      title: name(a.name, lang),
      line: [levels(lang, a.levelMin, a.levelMax), `${t(lang, "map.respawn").toLowerCase()} ${respawn(a.respawnMin, a.respawnMax)}`].join(" · "),
      href: placeHref(lang, a.id),
    };
  }
  for (const c of cavesOf(mapId)) {
    out[`cave-${c.id}`] = { title: name(c.name, lang), line: `${t(lang, "map.kind.cave")} · ${levels(lang, c.levelMin, c.levelMax)}`, href: placeHref(lang, c.id) };
  }
  for (const p of load("portals").portals.filter((x) => x.map === mapId && x.kind !== "cave")) {
    const target = getMapInfo(p.target);
    if (!target) continue;
    out[`portal-${p.id}`] = {
      title: name(target.name, lang),
      line: `${t(lang, `map.kind.${p.kind}` as Parameters<typeof t>[1])} · ${levels(lang, target.minLevel, target.maxLevel)}`,
      href: placeHref(lang, p.target),
    };
  }
  for (const b of load("bosses").bosses.filter((x) => x.gateCave === mapId)) {
    out[`boss-${b.id}`] = { title: name(b.name, lang), line: `${t(lang, "rank.boss")} · ${t(lang, "level", { level: b.level })}`, href: placeHref(lang, b.dungeon) };
  }
  const monsterNames = new Map(load("monsters").monsters.map((m) => [m.id, m]));
  for (const g of load("areas").groups[mapId] ?? []) {
    if (g.variant === "normal") continue;
    const kinds = g.kinds.map((k) => name(monsterNames.get(k)?.variants[g.variant]?.name ?? monsterNames.get(k)?.name, lang));
    out[`group-${g.id}`] = {
      title: kinds.join(" / "),
      line: [levels(lang, g.levelMin, g.levelMax), name(load("mechanics").variants[g.variant]?.name, lang), respawn(g.respawnMin, g.respawnMax)].filter(Boolean).join(" · "),
    };
  }
  const services = load("npcs").services;
  for (const n of npcs().filter((x) => x.map === mapId && !x.decoration)) {
    const role = n.role ? name(n.role, lang) : "";
    const list = n.services.filter((s) => s !== "talk" && s !== "story").map((s) => name(services[s], lang));
    out[`npc-${n.id}`] = { title: name(n.name, lang), line: [role, list.join(", ")].filter(Boolean).join(" · ") };
  }
  return out;
}

export function legendFor(lang: Lang, kind: string): { cls: string; label: string }[] {
  if (kind === "city") {
    return [
      { cls: "npc", label: t(lang, "map.legend.npc") },
      { cls: "portal", label: t(lang, "map.legend.portal") },
    ];
  }
  if (kind === "cave") {
    return [
      { cls: "group", label: t(lang, "map.legend.group") },
      { cls: "elite", label: t(lang, "map.legend.elite") },
      { cls: "boss", label: t(lang, "map.legend.boss") },
      { cls: "portal", label: t(lang, "map.legend.portal") },
    ];
  }
  return [
    { cls: "area", label: t(lang, "region.areas") },
    { cls: "cave", label: t(lang, "map.legend.cave") },
    { cls: "portal", label: t(lang, "map.legend.portal") },
    { cls: "npc", label: t(lang, "map.legend.npc") },
  ];
}
