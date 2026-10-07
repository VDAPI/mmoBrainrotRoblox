// Item tooltip data (S36, contract for S37–S44): what ItemTooltip draws for an item at a rarity and upgrade level.
// Stats, values and bonuses come from the export (items.json, stats.json, bonuses.json); nothing is computed with
// game formulas here. Random bonuses are shown as "◆ Random bonus" lines (never invented values).
import type { Item, RarityKey } from "../data/types";
import type { Lang } from "../i18n/routes";
import { getItem, load, rarityOf } from "./data";
import { formatNumber } from "./format";
import { name, t } from "./i18n";

export interface TooltipRow {
  label: string;
  value: string;
  unmet?: boolean;
}

export interface TooltipData {
  id: string;
  name: string;
  rarity: string; // rarity key (colour token --vw-r-<key>)
  rarityName: string;
  type: string; // "Rarity · Type" line
  up: number; // upgrade level shown (0 = no badge)
  pips: boolean; // 9 upgrade marks (equipment only)
  rows: TooltipRow[];
  bonuses: { text: string; legendary?: boolean; random?: boolean }[];
  flavor?: string;
  bind: boolean;
  glyph: string;
  color: string; // glyph colour (Data/Items icon.color)
  level: number;
}

export interface TooltipOptions {
  rarity?: string;
  upgrade?: number;
  lang: Lang;
  playerLevel?: number;
}

/** The rarity an item is shown with by default: its fixed one, otherwise the highest allowed. */
export function defaultRarity(item: Item): RarityKey {
  return item.rarities[item.rarities.length - 1];
}

// Base stat keys of items -> stat ids of stats.json ("hp" is maxHp, "physAtkPct" a % of physAtk).
const BASE_STAT: Record<string, string> = { hp: "maxHp", mana: "maxMana" };

function statLabel(key: string, lang: Lang): { label: string; pct: boolean } {
  const pctMatch = /^(.+)Pct$/.exec(key);
  const id = pctMatch ? pctMatch[1] : (BASE_STAT[key] ?? key);
  const stat = load("stats").stats.find((s) => s.id === id);
  return { label: stat ? name(stat.name, lang) : key, pct: pctMatch !== null || stat?.format === "pct" };
}

export function tooltipData(itemId: string, options: TooltipOptions): TooltipData | undefined {
  const item = getItem(itemId);
  if (!item) {
    return undefined;
  }
  const lang = options.lang;
  const rarityKey = item.rarities.includes(options.rarity as RarityKey) ? options.rarity! : defaultRarity(item);
  const rarity = rarityOf(rarityKey);
  const equipment = item.category === "equipment";
  const up = equipment ? Math.max(0, Math.min(9, Math.floor(options.upgrade ?? 0))) : 0;
  const files = load("items");
  const typeName = equipment && files.bases[item.type] ? files.bases[item.type].name : files.categories[item.category]?.name;
  const rows: TooltipRow[] = [];
  const stats = item.stats?.[rarityKey];
  if (stats?.weapon) {
    rows.push({ label: t(lang, "tooltip.dmg"), value: formatNumber(stats.weapon.dmg[up], lang) });
    if (stats.weapon.mdmg[up] > 0) {
      rows.push({ label: t(lang, "tooltip.mdmg"), value: formatNumber(stats.weapon.mdmg[up], lang) });
    }
    rows.push({ label: t(lang, "tooltip.speed"), value: formatNumber(stats.weapon.speed, lang, 2) });
  }
  for (const key of Object.keys(stats?.base ?? {}).sort()) {
    const { label, pct } = statLabel(key, lang);
    const value = stats!.base[key][up];
    rows.push({ label, value: `${formatNumber(value, lang)}${pct ? "%" : ""}` });
  }
  if (equipment || item.requiredLevel > 1) {
    const classes = load("classes").classes.filter((c) => item.classes?.includes(c.id));
    const parts = [t(lang, "tooltip.level", { level: item.requiredLevel })];
    if (classes.length > 0 && classes.length < 4) {
      parts.push(classes.map((c) => name(c.name, lang)).join(", "));
    }
    rows.push({
      label: t(lang, "tooltip.req"),
      value: parts.join(" · "),
      unmet: options.playerLevel !== undefined && options.playerLevel < item.requiredLevel,
    });
  }
  const value = item.value[rarityKey]?.[up];
  if (value !== undefined && !item.noSell) {
    rows.push({ label: t(lang, "tooltip.value"), value: formatNumber(value, lang) });
  }
  const bonuses: TooltipData["bonuses"] = [];
  if (item.fixedBonuses) {
    const defs = load("bonuses").bonuses;
    for (const b of item.fixedBonuses) {
      const def = defs.find((d) => d.id === b.stat);
      const text = def ? `+${formatNumber(b.v, lang)}${def.percent ? "%" : ""} ${name(def.name, lang)}` : b.stat;
      bonuses.push({ text, legendary: b.stat.startsWith("leg_") });
    }
  } else if (equipment && rarity) {
    for (let i = 0; i < rarity.bonusMax; i++) {
      bonuses.push({ text: t(lang, "tooltip.randomBonus"), random: true });
    }
    for (let i = 0; i < rarity.legendaryLines; i++) {
      bonuses.push({ text: t(lang, "tooltip.legendaryBonus"), random: true, legendary: true });
    }
  }
  return {
    id: item.id,
    name: name(item.name, lang),
    rarity: rarityKey,
    rarityName: rarity ? name(rarity.name, lang) : rarityKey,
    type: [rarity ? name(rarity.name, lang) : "", name(typeName, lang)].filter(Boolean).join(" · "),
    up,
    pips: equipment,
    rows,
    bonuses,
    flavor: item.desc ? name(item.desc, lang) : undefined,
    bind: item.bind,
    glyph: item.glyph,
    color: item.color,
    level: item.requiredLevel,
  };
}
