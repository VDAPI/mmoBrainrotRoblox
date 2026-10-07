// Items (S40, build time): the detail of one item (src/lib/item-model.ts ItemDetail) from the export — names, stats on
// every rarity and +0..+9, upgrade steps and costs, bonus pools with ranges and chances, icons — plus the list rows,
// sources and crafting helpers of the item pages. Numbers only from wiki/src/data; nothing here repeats game formulas.
import type { Item, RarityKey } from "../data/types";
import type { Lang } from "../i18n/routes";
import { getItem, items, load, rarities } from "./data";
import { iconFor } from "./icons";
import { name, t } from "./i18n";
import {
  bonusText,
  buildTooltip,
  mainStat,
  type ItemDetail,
  type MaterialRef,
  type PoolBonus,
  type StatRow,
  type TooltipData,
  type TooltipLabels,
  type TooltipOptions,
} from "./item-model";

// Base stat keys of items -> stat ids of stats.json ("hp" is maxHp, "physAtkPct" a % of physAtk).
const BASE_STAT: Record<string, string> = { hp: "maxHp", mana: "maxMana" };

function statInfo(key: string): { label?: { pl: string; en: string }; pct: boolean; decimals?: number } {
  const pctMatch = /^(.+)Pct$/.exec(key);
  const id = pctMatch ? pctMatch[1] : (BASE_STAT[key] ?? key);
  const stat = load("stats").stats.find((s) => s.id === id);
  return { label: stat?.name, pct: pctMatch !== null || stat?.format === "pct", decimals: stat?.decimals };
}

const rarityOrder = () => rarities().map((r) => r.key);

/** Generated equipment: <type>_<tier> items with tiers and random bonuses. */
export function isGenerated(item: Item): boolean {
  return item.category === "equipment" && item.tier !== undefined && !item.fixedBonuses && item.id === `${item.type}_${item.tier}`;
}

function statRows(item: Item, rarity: string): StatRow[] {
  const s = item.stats?.[rarity];
  if (!s) return [];
  const rows: StatRow[] = [];
  if (s.weapon) {
    rows.push({ key: "dmg", values: s.weapon.dmg, pct: false });
    rows.push({ key: "mdmg", values: s.weapon.mdmg, pct: false });
    rows.push({ key: "speed", values: [s.weapon.speed], pct: false, decimals: 2 });
  }
  for (const key of Object.keys(s.base).sort()) {
    const info = statInfo(key);
    rows.push({ key, label: info.label, values: s.base[key], pct: info.pct, decimals: info.decimals });
  }
  return rows;
}

/** Upgrade cost row of the export for an item level: the highest cost tier <= level. */
export function costTier(level: number): string {
  const tiers = load("upgrade").tiers.filter((x) => x <= level);
  return String(tiers.length > 0 ? tiers[tiers.length - 1] : load("upgrade").tiers[0]);
}

function poolOf(poolId: string, tier: number, allowed: string[]): PoolBonus[] {
  const file = load("bonuses");
  const ids = file.pools[poolId] ?? [];
  const freq = file.frequency[poolId] ?? {};
  return ids
    .map((id) => file.bonuses.find((b) => b.id === id))
    .filter((b): b is NonNullable<typeof b> => b !== undefined)
    .map((b) => ({
      id: b.id,
      name: b.name,
      percent: b.percent,
      decimals: b.decimals,
      range: Object.fromEntries(allowed.filter((r) => b.ranges[String(tier)]?.[r]).map((r) => [r, b.ranges[String(tier)][r] as [number, number]])),
      chance: Object.fromEntries(allowed.map((r) => [r, freq[r]?.[b.id] ?? 0])),
    }));
}

export function materialRef(id: string): MaterialRef {
  const item = getItem(id);
  return {
    id,
    name: item?.name ?? { pl: id, en: id },
    glyph: item?.glyph ?? "◆",
    color: item?.color ?? "#9DA3AB",
    rarity: item ? item.rarities[item.rarities.length - 1] : "common",
    icon: iconFor(id),
  };
}

const detailCache = new Map<string, ItemDetail>();

export function itemDetail(id: string): ItemDetail | undefined {
  const cached = detailCache.get(id);
  if (cached) return cached;
  const item = getItem(id);
  if (!item) return undefined;
  const file = load("items");
  const order = rarityOrder();
  const allowed = [...item.rarities].sort((a, b) => order.indexOf(a) - order.indexOf(b));
  const equipment = item.category === "equipment";
  const generated = isGenerated(item);
  const classes = load("classes").classes;
  const itemClasses = classes.filter((c) => item.classes?.includes(c.id));
  const typeName = equipment && file.bases[item.type] ? file.bases[item.type].name : file.categories[item.category]?.name;
  const level = item.level;
  const materials: Record<string, MaterialRef> = {};
  let upgrade: ItemDetail["upgrade"];
  if (equipment) {
    const costs = load("upgrade").costs[costTier(item.tier ?? level)] ?? {};
    upgrade = {
      steps: load("upgrade").steps,
      costs: Object.fromEntries(allowed.filter((r) => costs[r]).map((r) => [r, costs[r]])),
    };
    for (const list of Object.values(upgrade.costs)) for (const c of list) for (const m of c.materials) materials[m.id] ??= materialRef(m.id);
    materials[load("upgrade").protection] ??= materialRef(load("upgrade").protection);
  }
  for (const c of item.sources.crafting) for (const m of craftRecipe(c.recipe)?.materials ?? []) materials[m.id] ??= materialRef(m.id);
  const elements = item.elemental ? load("elements").elements.filter((e) => e.weapon) : [];
  const detail: ItemDetail = {
    id: item.id,
    name: item.name,
    nameByElement: item.nameByElement,
    category: item.category,
    categoryName: file.categories[item.category]?.name ?? { pl: item.category, en: item.category },
    type: item.type,
    typeName: typeName ?? { pl: item.type, en: item.type },
    slot: item.slot,
    slotName: item.slot ? file.slots[item.slot]?.name : undefined,
    classes: itemClasses.map((c) => ({ id: c.id, name: c.name })),
    allClasses: !item.classes || item.classes.length === 0 || item.classes.length >= classes.length,
    tier: item.tier,
    level: item.requiredLevel,
    equipment,
    generated,
    rarities: allowed.map((key) => {
      const r = rarities().find((x) => x.key === key)!;
      return { key, name: r.name, bonusMin: r.bonusMin, bonusMax: r.bonusMax, legendaryLines: r.legendaryLines };
    }),
    stats: Object.fromEntries(allowed.map((r) => [r, statRows(item, r)])),
    value: item.value,
    noSell: item.noSell,
    bind: item.bind,
    stackable: item.stackable,
    maxStack: item.maxStack,
    glyph: item.glyph,
    color: item.color,
    desc: item.desc,
    fixed: item.fixedBonuses?.map((b) => {
      const def = load("bonuses").bonuses.find((d) => d.id === b.stat);
      return {
        text: { pl: bonusText(def?.name.pl ?? b.stat, b.v, "pl", def?.decimals), en: bonusText(def?.name.en ?? b.stat, b.v, "en", def?.decimals) },
        legendary: b.stat.startsWith("leg_"),
      };
    }),
    pool: generated && item.bonusGroup ? poolOf(item.bonusGroup, item.tier!, allowed) : undefined,
    legendaryPool: generated && allowed.some((r) => (rarities().find((x) => x.key === r)?.legendaryLines ?? 0) > 0) ? poolOf("legendary", item.tier!, allowed) : undefined,
    upgrade,
    materials,
    icon: iconFor(item.id),
    iconByElement: item.elemental ? Object.fromEntries(elements.map((e) => [e.id, iconFor(item.id, e.id)])) : undefined,
    elements: elements.length > 0 ? elements.map((e) => ({ id: e.id, name: e.name })) : undefined,
  };
  detailCache.set(id, detail);
  return detail;
}

export function tooltipLabels(lang: Lang): TooltipLabels {
  return {
    dmg: t(lang, "tooltip.dmg"),
    mdmg: t(lang, "tooltip.mdmg"),
    speed: t(lang, "tooltip.speed"),
    req: t(lang, "tooltip.req"),
    level: t(lang, "tooltip.level"),
    value: t(lang, "tooltip.value"),
    randomBonus: t(lang, "tooltip.randomBonus"),
    legendaryBonus: t(lang, "tooltip.legendaryBonus"),
    stack: t(lang, "tooltip.stack"),
  };
}

/** Tooltip of an item (build time): buildTooltip on its detail. */
export function itemTooltip(id: string, options: TooltipOptions): TooltipData | undefined {
  const detail = itemDetail(id);
  return detail ? buildTooltip(detail, options, tooltipLabels(options.lang)) : undefined;
}

/** Blacksmith recipe of an item from crafting.json (rows are grouped by level, gold and materials). */
export function craftRecipe(recipe: string): { gold: number; level: number; materials: { id: string; n: number }[] } | undefined {
  for (const row of load("crafting").rows) {
    if (row.items.some((i) => i.recipe === recipe || i.item === recipe)) return { gold: row.gold, level: row.level, materials: row.materials };
  }
  return undefined;
}

// ------------------------------------------------------------------ list index

export interface IndexRow {
  id: string;
  base: string; // type for generated equipment (tier group), else the id
  name: string;
  type: string;
  slot: string; // slot or category (filter chips)
  category: string;
  classes: string[];
  allClasses: boolean;
  level: number;
  tier: number | null;
  rarities: string[];
  stats: Record<string, string>; // rarity -> main stat text
  statNum: Record<string, number>; // rarity -> main stat value at +0 (sorting)
  statLabel: string;
  sources: string[];
  glyph: string;
  color: string;
  icon: string | null;
  href: string;
  key: string; // normalized search text (name + id)
}

export function sourceKinds(item: Item): string[] {
  const s = item.sources;
  const out: string[] = [];
  if (s.monsters.some((m) => m.variant === "normal")) out.push("monsters");
  if (s.monsters.some((m) => m.variant !== "normal")) out.push("elites");
  if (s.bosses.length > 0) out.push("bosses");
  if (s.shops.length > 0) out.push("shops");
  if (s.crafting.length > 0) out.push("crafting");
  if (s.alchemy.length > 0) out.push("alchemy");
  if (s.gathering.length > 0 || s.fishing.length > 0 || s.fishingChest) out.push("gathering");
  if (s.quests.length > 0) out.push("quests");
  return out;
}

export function indexRows(lang: Lang, hrefOf: (id: string) => string, normalize: (s: string) => string): IndexRow[] {
  return items().map((item) => {
    const d = itemDetail(item.id)!;
    const stats: Record<string, string> = {};
    const statNum: Record<string, number> = {};
    let statLabel = "";
    for (const r of d.rarities) {
      const m = mainStat(d, r.key, lang);
      if (m) {
        stats[r.key] = m.text;
        statNum[r.key] = d.stats[r.key].find((x) => x.key === m.key)?.values[0] ?? 0;
        statLabel ||= m.key === "dmg" ? t(lang, "tooltip.dmg") : m.key === "mdmg" ? t(lang, "tooltip.mdmg") : (m.label?.[lang] ?? "");
      }
    }
    const label = name(item.name, lang);
    return {
      id: item.id,
      base: d.generated ? item.type : item.id,
      name: label,
      type: d.typeName[lang],
      slot: item.slot ?? item.category,
      category: item.category,
      classes: d.classes.map((c) => c.id),
      allClasses: d.allClasses,
      level: d.level,
      tier: d.generated ? (item.tier ?? null) : null,
      rarities: d.rarities.map((r) => r.key),
      stats,
      statNum,
      statLabel,
      sources: sourceKinds(item),
      glyph: item.glyph,
      color: item.color,
      icon: d.icon,
      href: hrefOf(item.id),
      key: normalize(`${label} ${item.id}`),
    };
  });
}

export type { RarityKey };
