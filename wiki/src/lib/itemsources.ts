// Where an item comes from and what it is used for (S40, build time): source cards of the item page (monsters with
// the chance of this exact item, bosses, shops with the price and NPC, alchemy, quests, fishing, gathering) and the
// "used for" lists of materials. Numbers from items.json sources; links through sectionHref (pages not ready = text).
import type { Item } from "../data/types";
import type { Lang } from "../i18n/routes";
import { bossHref, finalLevels, monsterHref, placesOf } from "./bestiary";
import { getBoss, getItem, getMonster, load } from "./data";
import { formatChance, formatNumber } from "./format";
import { name, t } from "./i18n";
import { mapHref, mapLinkFor } from "./world";
import { sectionHref } from "./sections";

export interface SourceCard {
  kind: "monster" | "boss" | "shop" | "alchemy" | "quest" | "fishing" | "chest" | "gathering" | "crafting";
  title: string;
  href: string | null;
  line: string;
  chance?: string;
  sort: number; // higher first
  monster?: { id: string; variant: "normal" | "elite" | "elite2" | "boss" };
  item?: string; // icon of a related item (alchemy result, gathered node loot)
}

export function itemSources(item: Item, lang: Lang): SourceCard[] {
  const out: SourceCard[] = [];
  const s = item.sources;
  const variants = load("mechanics").variants;
  for (const src of s.monsters) {
    const m = getMonster(src.monster);
    if (!m) continue;
    const v = (src.variant as "normal" | "elite" | "elite2") ?? "normal";
    const info = m.variants[v];
    if (!info) continue;
    const [min, max] = finalLevels(info);
    const place = placesOf(m, v, lang)[0]?.name ?? "";
    out.push({
      kind: "monster",
      title: name(info.name, lang),
      href: monsterHref(lang, m.id, v),
      line: [name(variants[v]?.name, lang), min === max ? t(lang, "level", { level: min }) : t(lang, "levelRangeCap", { min, max }), place].filter(Boolean).join(" · "),
      chance: formatChance(src.chance, lang),
      sort: src.chance,
      monster: { id: m.id, variant: v },
    });
  }
  for (const src of s.bosses) {
    const b = getBoss(src.boss);
    if (!b) continue;
    out.push({
      kind: "boss",
      title: name(b.name, lang),
      href: bossHref(lang, b.id),
      line: `${t(lang, "rank.boss")} · ${t(lang, "level", { level: b.level })}${src.personal ? ` · ${t(lang, "item.src.personal")}` : ""}`,
      chance: src.personal ? undefined : formatChance(src.chance, lang),
      sort: src.personal ? 2 : src.chance + 1,
      monster: { id: b.id, variant: "boss" },
    });
  }
  const shops = load("shops").shops;
  const npcs = load("npcs").npcs;
  for (const src of s.shops) {
    const shop = shops.find((x) => x.id === src.shop);
    const npc = npcs.find((n) => shop?.npcs.includes(n.id));
    out.push({
      kind: "shop",
      title: npc ? name(npc.name, lang) : src.shop,
      href: npc ? mapHref(lang, mapLinkFor(npc.id)) : null,
      line: `${t(lang, "item.src.shop")} · ${formatNumber(src.gold, lang)} ${t(lang, "item.gold")}`,
      sort: 3,
    });
  }
  const recipes = load("recipes").recipes;
  for (const id of s.alchemy) {
    const r = recipes.find((x) => x.id === id);
    if (!r) continue;
    out.push({
      kind: "alchemy",
      title: t(lang, "item.src.alchemy"),
      href: sectionHref(lang, "crafting") ? `${sectionHref(lang, "crafting")}#alchemy` : null,
      line: r.ingredients.map((i) => `${name(getItem(i.id)?.name, lang)} ×${i.n}`).join(", "),
      sort: 2.5,
    });
  }
  const quests = load("quests");
  for (const q of s.quests) {
    const quest = [...quests.main, ...quests.side].find((x) => x.id === q.quest);
    out.push({
      kind: "quest",
      title: quest ? name(quest.title, lang) : q.quest,
      href: sectionHref(lang, "quests", q.quest),
      line: `${t(lang, "item.src.quest")} · ×${q.n}`,
      sort: 2.4,
    });
  }
  const nodes = load("gather").nodes;
  for (const g of s.gathering) {
    const node = nodes.find((n) => n.id === g.node);
    out.push({
      kind: "gathering",
      title: node ? name(node.name, lang) : g.node,
      href: sectionHref(lang, "crafting") ? `${sectionHref(lang, "crafting")}#gathering` : null,
      line: `${t(lang, "item.src.gathering")} · ${g.min === g.max ? g.min : `${g.min}–${g.max}`}`,
      chance: formatChance(g.chance, lang),
      sort: 1 + g.chance,
    });
  }
  for (const f of s.fishing) {
    const map = load("maps").maps.find((m) => m.id === f.spot);
    out.push({
      kind: "fishing",
      title: map ? name(map.name, lang) : f.spot,
      href: sectionHref(lang, "crafting") ? `${sectionHref(lang, "crafting")}#fishing` : null,
      line: t(lang, "item.src.fishing"),
      chance: formatChance(f.chance, lang),
      sort: 1 + f.chance,
    });
  }
  if (s.fishingChest) {
    out.push({ kind: "chest", title: t(lang, "item.src.chest"), href: sectionHref(lang, "crafting") ? `${sectionHref(lang, "crafting")}#fishing` : null, line: t(lang, "item.src.fishing"), sort: 0.5 });
  }
  return out.sort((a, b) => b.sort - a.sort);
}

/** Alchemy recipes that use an item and their results. */
export function usedInAlchemy(item: Item): { recipe: string; result: string; n: number }[] {
  const recipes = load("recipes").recipes;
  return (item.usedFor?.alchemy ?? [])
    .map((id) => recipes.find((r) => r.id === id))
    .filter((r): r is NonNullable<typeof r> => r !== undefined)
    .map((r) => ({ recipe: r.id, result: r.result.id, n: r.result.n }));
}
