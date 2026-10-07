// Monster and boss pages (S39, build time): stat cells per level, loot rows (equipment groups, materials, quest
// items, gold), ability and attack texts from templates, places and relations. Every number comes from the export;
// this module only picks, sums and formats.
import type { Ability, Boss, BossAttack, Monster, MonsterLevel, MonsterLoot, MonsterVariant, RarityKey } from "../data/types";
import type { Lang } from "../i18n/routes";
import { bosses, getItem, load, monsters, rarities } from "./data";
import { formatChance, formatDuration, formatNumber } from "./format";
import { name, t, type Key } from "./i18n";
import { occurringVariants, placesOf, type MonsterRank } from "./bestiary";
import { sectionHref } from "./sections";
import { respawn } from "./world";
import { iconFor } from "./icons";

const range = (lang: Lang, min: number, max: number) =>
  min === max ? formatNumber(min, lang) : `${formatNumber(min, lang)}–${formatNumber(max, lang)}`;

/** Variants shown on a monster page: the occurring ones, or the normal one for a summon-only kind. */
export function pageVariants(m: Monster): MonsterRank[] {
  const list = occurringVariants(m);
  return list.length > 0 ? list : (["normal"] as MonsterRank[]).filter((v) => m.variants[v]);
}

/** Bosses that summon a monster kind. */
export function summonedBy(id: string): Boss[] {
  return bosses().filter((b) => b.summons.some((s) => s.monster === id));
}

/** Formatted stats of one level (the page script swaps them when a level chip is pressed). */
export interface LevelCells {
  level: number;
  hp: number;
  hpText: string;
  dmg: string;
  armor: string;
  mres: string;
  exp: string;
  gold: string;
  interval: string;
  range: string;
  aggro: string;
  ability?: string;
}

export function levelCells(row: MonsterLevel, lang: Lang): LevelCells {
  return {
    level: row.finalLevel,
    hp: row.hp,
    hpText: formatNumber(row.hp, lang),
    dmg: range(lang, row.dmgMin, row.dmgMax),
    armor: formatNumber(row.armor, lang),
    mres: formatNumber(row.mres, lang),
    exp: formatNumber(row.exp, lang),
    gold: range(lang, row.goldMin, row.goldMax),
    interval: formatNumber(Math.round(row.attackInterval * 100) / 100, lang),
    range: formatNumber(row.range, lang),
    aggro: formatNumber(row.aggroRange, lang),
    ability: row.abilityMin !== undefined && row.abilityMax !== undefined ? range(lang, row.abilityMin, row.abilityMax) : undefined,
  };
}

/** Respawn range of a variant over its spawns. */
export function respawnText(v: MonsterVariant, lang: Lang): string {
  if (v.spawns.length === 0) return "—";
  const min = Math.min(...v.spawns.map((s) => s.respawnMin));
  const max = Math.max(...v.spawns.map((s) => s.respawnMax));
  return respawn(min, max) || durationRange(min, max, lang);
}

/** "30–45 s", "10–20 min", "45 s–2 min". */
export function durationRange(min: number, max: number, lang: Lang): string {
  if (min === max) return formatDuration(min, lang);
  if (max < 60) return `${formatNumber(min, lang)}–${formatNumber(max, lang)} s`;
  if (min >= 60 && max < 3600 && min % 60 === 0 && max % 60 === 0) return `${formatNumber(min / 60, lang)}–${formatNumber(max / 60, lang)} min`;
  return `${formatDuration(min, lang)}–${formatDuration(max, lang)}`;
}

// ---------------------------------------------------------------- loot

export interface LootTop {
  id: string;
  name: string;
  chance: number;
  chanceText: string;
  href: string | null;
}

export interface LootRow {
  kind: "group" | "material" | "quest" | "gold";
  key: string; // unique within the variant (tooltip id)
  name: string;
  sub?: string; // second line (item level, quest note, amount)
  rarity: RarityKey | null; // frame / text colour
  rarityText: string;
  type: string;
  chance: number;
  chanceText: string;
  glyph: string;
  color: string;
  icon?: string | null; // generated icon (S40)
  item?: string; // tooltip item id
  itemRarity?: RarityKey;
  href: string | null;
  questHref?: string | null;
  top?: LootTop[];
}

const rarityIndex = (key: string) => rarities().findIndex((r) => r.key === key);
const rarityName = (key: string, lang: Lang) => name(rarities().find((r) => r.key === key)?.name, lang);

/** Rarities a variant's random items can have, low to high. */
export function lootRarities(loot: MonsterLoot): RarityKey[] {
  return (Object.keys(loot.rarities) as RarityKey[]).filter((k) => loot.rarities[k] > 0).sort((a, b) => rarityIndex(a) - rarityIndex(b));
}

export function itemHref(lang: Lang, id: string): string | null {
  return sectionHref(lang, "items", id);
}

/** Loot rows of a variant, rarest first. Materials listed twice (base + variant extra) are merged. */
export function lootRows(m: Monster, variant: MonsterRank, lang: Lang): LootRow[] {
  const info = m.variants[variant];
  const loot = info.loot;
  const allowed = lootRarities(loot);
  const top = allowed[allowed.length - 1] ?? "common";
  const slots = load("items").slots;
  const rows: LootRow[] = [];
  for (const [slot, g] of Object.entries(loot.groups)) {
    const first = g.top[0] ? getItem(g.top[0].id) : undefined;
    const slotName = name(slots[slot]?.name, lang) || slot;
    rows.push({
      kind: "group",
      key: `g-${slot}`,
      name: slotName,
      sub: t(lang, "loot.ilvl", { range: range(lang, g.ilvlMin, g.ilvlMax) }),
      rarity: top,
      rarityText: allowed.length > 1 ? `${rarityName(allowed[0], lang)}–${rarityName(top, lang)}` : rarityName(top, lang),
      type: t(lang, "loot.equipment"),
      chance: g.chance,
      chanceText: formatChance(g.chance, lang),
      glyph: first?.glyph ?? "◆",
      color: first?.color ?? "#9DA3AB",
      item: first?.id,
      icon: first ? iconFor(first.id) : null,
      itemRarity: top,
      href: null,
      top: g.top.map((x) => ({ id: x.id, name: name(getItem(x.id)?.name, lang) || x.id, chance: x.chance, chanceText: formatChance(x.chance, lang), href: itemHref(lang, x.id) })),
    });
  }
  const merged = new Map<string, { chance: number; min: number; max: number; count: number }>();
  for (const mat of loot.materials) {
    const prev = merged.get(mat.id);
    if (prev) merged.set(mat.id, { chance: mat.measured, min: Math.min(prev.min, mat.min), max: prev.max + mat.max, count: prev.count + 1 });
    else merged.set(mat.id, { chance: mat.chance, min: mat.min, max: mat.max, count: 1 });
  }
  for (const [id, mat] of merged) {
    const item = getItem(id);
    const rarity = item ? item.rarities[item.rarities.length - 1] : "common";
    rows.push({
      kind: "material",
      key: `m-${id}`,
      name: name(item?.name, lang) || id,
      sub: t(lang, "loot.amount", { range: range(lang, mat.min, mat.max) }),
      rarity,
      rarityText: rarityName(rarity, lang),
      type: name(load("items").categories[item?.category ?? "material"]?.name, lang) || t(lang, "loot.material"),
      chance: mat.chance,
      chanceText: formatChance(mat.chance, lang),
      glyph: item?.glyph ?? "◆",
      color: item?.color ?? "#9DA3AB",
      item: item ? id : undefined,
      icon: iconFor(id),
      itemRarity: rarity,
      href: itemHref(lang, id),
    });
  }
  const quests = load("quests");
  for (const q of [...quests.main, ...quests.side]) {
    for (const o of q.objectives) {
      if (o.type !== "collect" || o.monster !== m.id || o.chance === undefined) continue;
      if (o.variant && o.variant !== variant) continue;
      rows.push({
        kind: "quest",
        key: `q-${q.id}-${o.item}`,
        name: name(o.itemName, lang) || o.item || "",
        sub: t(lang, "loot.questOnly", { quest: name(q.title, lang) }),
        rarity: null,
        rarityText: "—",
        type: t(lang, "loot.questItem"),
        chance: o.chance,
        chanceText: formatChance(o.chance, lang),
        glyph: "✉",
        color: "#E8C25A",
        href: null,
        questHref: sectionHref(lang, "quests", q.id),
      });
    }
  }
  rows.sort((a, b) => a.chance - b.chance || (a.key < b.key ? -1 : 1));
  const goldMin = Math.min(...info.levels.map((l) => l.goldMin));
  const goldMax = Math.max(...info.levels.map((l) => l.goldMax));
  rows.push({
    kind: "gold",
    key: "gold",
    name: t(lang, "loot.gold"),
    sub: t(lang, "loot.goldRange", { range: range(lang, goldMin, goldMax) }),
    rarity: null,
    rarityText: "—",
    type: t(lang, "loot.currency"),
    chance: 1,
    chanceText: formatChance(1, lang),
    glyph: "●",
    color: "#E8C25A",
    href: null,
  });
  return rows;
}

// ---------------------------------------------------------------- abilities and attacks

const n = (v: number | undefined, lang: Lang) => formatNumber(v ?? 0, lang);

/** "krąg 7 st. wokół celu" / "a 7-stud circle around the target" from the shape fields. */
export function shapeText(a: { shape: string; radius?: number; inner?: number; angle?: number; length?: number; width?: number }, origin: string, lang: Lang): string {
  const where = t(lang, origin === "self" ? "shape.aroundSelf" : origin === "target" ? "shape.aroundTarget" : "shape.under");
  switch (a.shape) {
    case "cone":
      return t(lang, "shape.cone", { angle: n(a.angle, lang), radius: n(a.radius, lang) });
    case "line":
      return t(lang, "shape.line", { length: n(a.length, lang), width: n(a.width, lang) });
    case "ring":
      return t(lang, "shape.ring", { inner: n(a.inner, lang), radius: n(a.radius, lang), where });
    default:
      return t(lang, "shape.circle", { radius: n(a.radius, lang), where });
  }
}

function elementText(element: string | undefined, kind: string | undefined, lang: Lang): string {
  if (element) return name(load("elements").elements.find((e) => e.id === element)?.name, lang).toLowerCase();
  return t(lang, kind === "magic" ? "dmg.magic" : "dmg.phys");
}

/** Elite II ability: "After 1.2 s of warning hits … for 2.6× attack (X–Y damage), every 11 s." */
export function abilityText(a: Ability, cells: LevelCells | undefined, lang: Lang, kind: string): string {
  return t(lang, "ability.desc", {
    windup: n(a.windup, lang),
    shape: shapeText(a, a.origin, lang),
    mul: n(a.damage, lang),
    dmg: cells?.ability ?? "—",
    kind: elementText(a.element, a.damageKind ?? kind, lang),
    cd: n(a.cooldown, lang),
  });
}

/** Boss attack: shape, target and count, warning, damage, cooldown and element. */
export function attackText(a: BossAttack, lang: Lang, kind: string): string {
  const origin = a.target === "self" ? "self" : a.target === "all" ? "under" : "target";
  const target = t(lang, `target.${a.target}` as Key, { count: a.count ?? 1 });
  return t(lang, a.leap ? "attack.descLeap" : "attack.desc", {
    shape: shapeText(a, origin, lang),
    target,
    windup: n(a.windup, lang),
    dmg: range(lang, a.dmgMin, a.dmgMax),
    kind: elementText(a.element, a.damageKind ?? kind, lang),
    cd: n(a.cooldown, lang),
  });
}

/** Quests with a kill / collect objective on a monster kind. */
export function questsFor(id: string): { id: string; title: { pl: string; en: string }; type: string; level: number }[] {
  const q = load("quests");
  return [...q.main, ...q.side]
    .filter((x) => x.objectives.some((o) => (o.type === "kill" || o.type === "collect") && o.monster === id))
    .map((x) => ({ id: x.id, title: x.title, type: x.objectives.find((o) => o.monster === id)!.type, level: x.level }));
}

/** Other kinds living in the same areas / caves as a kind's occurring variants. */
export function neighboursOf(m: Monster, lang: Lang): Monster[] {
  const mine = new Set(occurringVariants(m).flatMap((v) => placesOf(m, v, lang).map((p) => p.id)));
  return monsters().filter(
    (o) => o.id !== m.id && occurringVariants(o).some((v) => placesOf(o, v, lang).some((p) => mine.has(p.id))),
  );
}
