// Item page model (S40): the language-neutral detail of one item (built from the export by src/lib/items.ts, served
// as /data/items/<id>.json) and pure functions on it — the tooltip, the main stat, the list rarity, bonus texts.
// No data imports: the islands use this module with the detail they fetched or got as props.
import { formatNumber } from "./format";

export type Lang = "pl" | "en";
export type Name = { pl: string; en: string };

export interface StatRow {
  key: string; // "dmg", "mdmg", "speed" (weapon) or a base stat key ("armor", "hp", "physAtkPct", ...)
  label?: Name; // base stats; weapon rows use the interface labels
  values: number[]; // +0..+9 (speed: one value)
  pct: boolean;
  decimals?: number;
}

export interface UpgradeStepInfo {
  to: number;
  chance: number;
  failTo?: number;
  protectedTo: number;
  statMultiplier: number;
}

export interface UpgradeCostInfo {
  gold: number;
  materials: { id: string; n: number }[];
}

export interface PoolBonus {
  id: string;
  name: Name; // game template "+{v}% ..."
  percent: boolean;
  decimals: number;
  range: Record<string, [number, number]>; // rarity -> value range on this item's tier
  chance: Record<string, number>; // rarity -> chance of the line (export Monte Carlo)
}

export interface RarityInfo {
  key: string;
  name: Name;
  bonusMin: number;
  bonusMax: number;
  legendaryLines: number;
}

export interface MaterialRef {
  id: string;
  name: Name;
  glyph: string;
  color: string;
  rarity: string;
  icon: string | null;
}

export interface ItemDetail {
  id: string;
  name: Name;
  nameByElement?: Record<string, Name>;
  category: string;
  categoryName: Name;
  type: string;
  typeName: Name;
  slot?: string;
  slotName?: Name;
  classes: { id: string; name: Name }[];
  allClasses: boolean;
  tier?: number;
  level: number;
  equipment: boolean;
  generated: boolean; // a <type>_<tier> item (tiers, random bonuses)
  rarities: RarityInfo[];
  stats: Record<string, StatRow[]>; // rarity -> rows
  value: Record<string, number[]>;
  noSell: boolean;
  bind: boolean;
  stackable: boolean;
  maxStack: number;
  glyph: string;
  color: string;
  desc?: Name;
  fixed?: { text: Name; legendary: boolean }[];
  pool?: PoolBonus[];
  legendaryPool?: PoolBonus[];
  upgrade?: { steps: UpgradeStepInfo[]; costs: Record<string, UpgradeCostInfo[]> };
  materials: Record<string, MaterialRef>; // upgrade / crafting materials by id
  icon: string | null; // base URL without "-64.webp" / "-128.webp"
  iconByElement?: Record<string, string | null>;
  elements?: { id: string; name: Name }[];
}

export interface TooltipLabels {
  dmg: string;
  mdmg: string;
  speed: string;
  req: string;
  level: string; // "Poz. {level}"
  value: string;
  randomBonus: string;
  legendaryBonus: string;
  stack: string; // "Stos do {n}"
}

export interface TooltipRow {
  label: string;
  value: string;
  unmet?: boolean;
}

export interface TooltipData {
  id: string;
  name: string;
  rarity: string;
  rarityName: string;
  type: string;
  up: number;
  pips: boolean;
  rows: TooltipRow[];
  bonuses: { text: string; legendary?: boolean; random?: boolean }[];
  flavor?: string;
  bind: boolean;
  glyph: string;
  color: string;
  level: number;
  icon?: string | null;
}

export interface TooltipOptions {
  rarity?: string;
  upgrade?: number;
  lang: Lang;
  element?: string;
  playerLevel?: number;
}

const fill = (text: string, args: Record<string, string | number>) => text.replace(/\{(\w+)\}/g, (w, k: string) => (k in args ? String(args[k]) : w));

/** The rarity shown by default: the fixed one, otherwise the highest allowed (S36 contract). */
export function defaultRarityOf(detail: Pick<ItemDetail, "rarities">): string {
  return detail.rarities[detail.rarities.length - 1]?.key ?? "common";
}

/** A rarity the item can have, or its default. */
export function pickRarity(detail: Pick<ItemDetail, "rarities">, rarity: string | null | undefined): string {
  return rarity && detail.rarities.some((r) => r.key === rarity) ? rarity : defaultRarityOf(detail);
}

/** "+{v}% Critical chance" with a value or a range ("3–7"). */
export function bonusText(template: string, value: number | [number, number], lang: Lang, decimals = 0): string {
  const fmt = (v: number) => formatNumber(v, lang, decimals || undefined);
  const text = Array.isArray(value) ? (value[0] === value[1] ? fmt(value[0]) : `${fmt(value[0])}–${fmt(value[1])}`) : fmt(value);
  return template.includes("{v}") ? template.replace("{v}", text) : `+${text} ${template}`;
}

export function statValue(row: StatRow, up: number, lang: Lang): string {
  const v = row.values[Math.min(up, row.values.length - 1)];
  return `${formatNumber(v, lang, row.key === "speed" ? 2 : row.decimals || undefined)}${row.pct ? "%" : ""}`;
}

function statLabel(row: StatRow, lang: Lang, L: TooltipLabels): string {
  if (row.key === "dmg") return L.dmg;
  if (row.key === "mdmg") return L.mdmg;
  if (row.key === "speed") return L.speed;
  return row.label?.[lang] ?? row.key;
}

/** Tooltip lines of an item at a rarity, upgrade level and (mage weapons) element. */
export function buildTooltip(detail: ItemDetail, options: TooltipOptions, L: TooltipLabels): TooltipData {
  const { lang } = options;
  const rarityKey = pickRarity(detail, options.rarity);
  const rarity = detail.rarities.find((r) => r.key === rarityKey);
  const up = detail.equipment ? Math.max(0, Math.min(9, Math.floor(options.upgrade ?? 0))) : 0;
  const rows: TooltipRow[] = [];
  for (const row of detail.stats[rarityKey] ?? []) {
    if (row.key === "mdmg" && row.values.every((v) => v === 0)) continue;
    rows.push({ label: statLabel(row, lang, L), value: statValue(row, up, lang) });
  }
  if (detail.equipment || detail.level > 1) {
    const parts = [fill(L.level, { level: detail.level })];
    if (!detail.allClasses && detail.classes.length > 0) parts.push(detail.classes.map((c) => c.name[lang]).join(", "));
    rows.push({ label: L.req, value: parts.join(" · "), unmet: options.playerLevel !== undefined && options.playerLevel < detail.level });
  }
  const value = detail.value[rarityKey]?.[up];
  if (value !== undefined && !detail.noSell) rows.push({ label: L.value, value: formatNumber(value, lang) });
  if (detail.stackable && detail.maxStack > 1) rows.push({ label: fill(L.stack, { n: detail.maxStack }), value: "" });
  const bonuses: TooltipData["bonuses"] = [];
  if (detail.fixed) {
    for (const b of detail.fixed) bonuses.push({ text: b.text[lang], legendary: b.legendary });
  } else if (detail.equipment && rarity) {
    for (let i = 0; i < rarity.bonusMax; i++) bonuses.push({ text: L.randomBonus, random: true });
    for (let i = 0; i < rarity.legendaryLines; i++) bonuses.push({ text: L.legendaryBonus, random: true, legendary: true });
  }
  const element = options.element && detail.nameByElement?.[options.element] ? options.element : undefined;
  const name = element ? detail.nameByElement![element][lang] : detail.name[lang];
  const rarityName = rarity ? rarity.name[lang] : rarityKey;
  return {
    id: detail.id,
    name,
    rarity: rarityKey,
    rarityName,
    type: [rarityName, detail.typeName[lang]].filter(Boolean).join(" · "),
    up,
    pips: detail.equipment,
    rows,
    bonuses,
    flavor: detail.desc?.[lang],
    bind: detail.bind,
    glyph: detail.glyph,
    color: detail.color,
    level: detail.level,
    icon: (element ? detail.iconByElement?.[element] : undefined) ?? detail.icon,
  };
}

/** The main stat of the list: weapon damage (or magic damage), armor, otherwise the first base stat. */
export function mainStat(detail: Pick<ItemDetail, "stats">, rarity: string, lang: Lang): { label?: Name; key: string; text: string } | null {
  const rows = detail.stats[rarity] ?? [];
  const pick =
    rows.find((r) => r.key === "dmg" && r.values[0] > 0) ??
    rows.find((r) => r.key === "mdmg" && r.values[0] > 0) ??
    rows.find((r) => r.key === "armor") ??
    rows.find((r) => r.key !== "speed" && r.key !== "dmg" && r.key !== "mdmg");
  return pick ? { key: pick.key, label: pick.label, text: statValue(pick, 0, lang) } : null;
}

/** Rarity a list row shows: the highest allowed one checked in the filter, else the lowest allowed (common). */
export function listRarity(allowed: string[], checked: string[], order: string[]): string {
  const hits = allowed.filter((r) => checked.includes(r)).sort((a, b) => order.indexOf(a) - order.indexOf(b));
  if (hits.length > 0) return hits[hits.length - 1];
  return [...allowed].sort((a, b) => order.indexOf(a) - order.indexOf(b))[0] ?? "common";
}

/** Icon <img> attributes for a size in CSS px from the base URL of an icon. */
export function iconSources(base: string | null | undefined, size: number): { src: string; srcset?: string } | null {
  if (!base) return null;
  return size <= 64 ? { src: `${base}-64.webp`, srcset: `${base}-64.webp 1x, ${base}-128.webp 2x` } : { src: `${base}-128.webp` };
}
