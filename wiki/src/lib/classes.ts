// Class pages (S41, build time only): facts of the hero, the rows of "All skills" and the props of the SkillPlanner
// island. Everything comes from classes.json, skills.json, stats.json and items.json; nothing is computed here that
// the game computes (the ranks, their levels and texts are exported per rank).
import type { ClassInfo, Skill } from "../data/types";
import type { Lang } from "../i18n/routes";
import { getItem, load } from "./data";
import { formatNumber } from "./format";
import { name, t, type Key } from "./i18n";
import { iconFor } from "./icons";
import { sectionHref } from "./sections";
import { maxReachableRank, type PlannerData, type PlannerSkill } from "./skills";

export const SKILL_RESET_SCROLL = "scroll_skillreset";

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

/** Lowest unlock level of every tree row (1..rows). */
export function rowLevels(skills: { row: number; unlock: number }[]): number[] {
  const rows = Math.max(...skills.map((s) => s.row));
  return Array.from({ length: rows }, (_, i) => Math.min(...skills.filter((s) => s.row === i + 1).map((s) => s.unlock)));
}

const PLANNER_KEYS = [
  "lvl", "lvlShort", "lvlDec", "lvlInc", "points", "ptsFree", "live", "active", "passive", "sumActive", "sumPassive",
  "required", "requiredNone", "code", "copy", "copied", "reset", "err.empty", "err.class", "err.length", "err.rank",
  "err.level", "over", "tooHigh", "rowStart", "rowLevel", "rowFrom", "tree", "rank", "current", "next", "notLearned",
  "maxed", "reachable", "breakpoints", "bp", "req", "reqLevel", "reqSkill", "reqFree", "add", "remove",
  "why.maxLevel", "why.noPoints", "why.level", "why.requires", "why.empty", "why.needed", "hint", "cost.mana",
  "cost.energy", "cooldown", "range", "lockLv", "aria", "state.available", "state.locked", "state.max",
  "state.unavailable", "state.invalid",
] as const;

export function plannerData(c: ClassInfo, lang: Lang): PlannerData {
  const file = load("skills");
  const skills: PlannerSkill[] = skillsOf(c.id).map((s) => ({
    id: s.id,
    order: s.order,
    unlock: s.unlock,
    maxLevel: s.maxLevel,
    requires: s.requires.map((r) => ({ skill: r.skill, level: r.level })),
    name: name(s.name, lang),
    glyph: s.glyph,
    color: skillColor(s),
    passive: s.passiveSkill,
    col: s.col,
    row: s.row,
    resource: s.resource ?? null,
    range: s.range ?? null,
    elementNote: s.elementNote ? name(s.elementNote, lang) : null,
    ranks: s.ranks.map((r) => ({ requiredLevel: r.requiredLevel, cost: r.cost, cooldown: r.cooldown, desc: name(r.desc, lang) })),
    breakpoints: file.rules.breakpointsEnabled ? s.breakpoints.map((b) => ({ level: b.level, text: name(b.text, lang) })) : [],
  }));
  const labels: Record<string, string> = Object.fromEntries(PLANNER_KEYS.map((k) => [k, t(lang, `planner.${k}` as Key)]));
  labels.warn = t(lang, "callout.warn");
  const scroll = getItem(SKILL_RESET_SCROLL);
  return {
    lang,
    classId: c.id,
    classColor: `var(--vw-class-${c.id})`,
    skills,
    rules: { maxLevel: file.rules.maxLevel, pointsByLevel: file.rules.pointsByLevel },
    labels,
    scroll: { name: name(scroll?.name, lang) || SKILL_RESET_SCROLL, href: scroll ? sectionHref(lang, "items", SKILL_RESET_SCROLL) : null },
  };
}

export interface SkillRow {
  skill: Skill;
  name: string;
  color: string;
  reachable: number;
  requires: { name: string; level: number }[];
}

export function skillRows(c: ClassInfo, lang: Lang): SkillRow[] {
  const all = load("skills");
  return skillsOf(c.id).map((s) => ({
    skill: s,
    name: name(s.name, lang),
    color: skillColor(s),
    reachable: maxReachableRank(s, all.rules.maxLevel),
    requires: s.requires.map((r) => ({ name: name(all.skills.find((x) => x.id === r.skill)?.name, lang) || r.skill, level: r.level })),
  }));
}
