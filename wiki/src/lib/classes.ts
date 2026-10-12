// Class pages (S41, build time only): facts of the hero and the rows of "All skills". Everything comes from
// classes.json, skills.json, stats.json and items.json; nothing is computed here that the game computes (the ranks,
// their levels and texts are exported per rank). S56: the planner is hidden ("coming soon") until S82.
import type { ClassInfo, Skill } from "../data/types";
import type { Lang } from "../i18n/routes";
import { getItem, load } from "./data";
import { formatNumber } from "./format";
import { name, t } from "./i18n";
import { iconFor } from "./icons";
import { sectionHref } from "./sections";
import { rankLevel } from "./skills";

export const classes = (): ClassInfo[] => [...load("classes").classes].sort((a, b) => a.order - b.order);
export const getClass = (id: string): ClassInfo | undefined => classes().find((c) => c.id === id);
export const skillsOf = (classId: string): Skill[] =>
  load("skills").skills.filter((s) => s.class === classId).sort((a, b) => a.order - b.order);

/** Glyph colour of a skill: its element, else the class colour (tokens from tokens.data.css). */
export function skillColor(skill: Skill): string {
  return skill.element ? `var(--vw-el-${skill.element})` : `var(--vw-class-${skill.class})`;
}

/** Role parts ("Obszarowe · Żywioły" -> two badges). */
export function roleParts(c: ClassInfo, lang: Lang): string[] {
  return name(c.role, lang)
    .split("·")
    .map((p) => p.trim())
    .filter(Boolean);
}

const resourceStat = (c: ClassInfo): string => (c.resource === "mana" ? "maxMana" : "maxEnergy");

export function resourceName(c: ClassInfo, lang: Lang): string {
  return name(load("stats").stats.find((s) => s.id === resourceStat(c))?.name, lang) || c.resource;
}

interface Formula {
  hpPerLevel: number;
  manaPerLevel: number;
  manaPerInt: number;
  energyBase: number;
  energyPerLevel: number;
}

const formula = (): Formula => load("stats").formula as unknown as Formula;

export function hpPerLevel(): number {
  return formula().hpPerLevel;
}

/** "+6/poz., +8 za INT" (mana) or "100 + 1/poz." (energy), from Stats.Formula. */
export function resourceLine(c: ClassInfo, lang: Lang): string {
  const f = formula();
  return c.resource === "mana"
    ? t(lang, "class.res.mana", { perLevel: formatNumber(f.manaPerLevel, lang), perInt: formatNumber(f.manaPerInt, lang) })
    : t(lang, "class.res.energy", { base: formatNumber(f.energyBase, lang), perLevel: formatNumber(f.energyPerLevel, lang) });
}

export function statName(id: string, lang: Lang): string {
  return name(load("stats").primaryNames[id], lang) || id;
}

export function baseName(type: string, lang: Lang): string {
  return name(load("items").bases[type]?.name, lang) || type;
}

/** Armor bases this class can wear (items.json bases of the armor slot listing the class). */
export function armorNames(c: ClassInfo, lang: Lang): string[] {
  const bases = load("items").bases;
  return Object.keys(bases)
    .filter((key) => bases[key].slot === "armor" && (bases[key].classes ?? []).includes(c.id))
    .sort()
    .map((key) => name(bases[key].name, lang));
}

export interface GearRef {
  id: string;
  name: string;
  glyph: string;
  color: string;
  icon: string | null;
  href: string | null;
}

export function startingGear(c: ClassInfo, lang: Lang): GearRef[] {
  return c.startingGear.map((id) => {
    const item = getItem(id);
    return {
      id,
      name: name(item?.name, lang) || id,
      glyph: item?.glyph ?? "◆",
      color: item?.color ?? "#9DA3AB",
      icon: iconFor(id),
      href: sectionHref(lang, "items", id),
    };
  });
}

export interface SkillRow {
  skill: Skill;
  name: string;
  color: string;
  /** Character level of the last rank (S56: ranks grow with the level). */
  maxAt: number;
}

export function skillRows(c: ClassInfo, lang: Lang): SkillRow[] {
  return skillsOf(c.id).map((s) => ({
    skill: s,
    name: name(s.name, lang),
    color: skillColor(s),
    maxAt: rankLevel(s, s.maxLevel),
  }));
}
