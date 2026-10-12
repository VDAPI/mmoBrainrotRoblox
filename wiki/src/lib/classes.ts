// Class pages (S41, build time only): facts of the hero, the planner props and the rows of "All skills". Everything
// comes from classes.json, skills.json, stats.json and items.json; nothing is computed here that the game computes
// (the ranks, their levels, variants and texts are exported per rank). S82: the planner with breakpoints A/B and the
// published class paths (ROZWOJ 3.5).
import type { ClassInfo, Skill, SkillPath, SkillPathWeapon } from "../data/types";
import type { Key } from "../i18n/pl";
import type { Lang } from "../i18n/routes";
import { getItem, load } from "./data";
import { formatNumber } from "./format";
import { name, t } from "./i18n";
import { iconFor } from "./icons";
import { sectionHref } from "./sections";
import type { PlannerData, PlannerPath, PlannerSkill, RuleSkill } from "./skills";

/** Scroll of a New Path (S57): changes the main path in the game. */
export const SKILL_RESET_SCROLL = "scroll_skillreset";

export const classes = (): ClassInfo[] => [...load("classes").classes].sort((a, b) => a.order - b.order);
export const getClass = (id: string): ClassInfo | undefined => classes().find((c) => c.id === id);
export const skillsOf = (classId: string): Skill[] =>
  load("skills").skills.filter((s) => s.class === classId).sort((a, b) => a.order - b.order);
/** Published paths of a class (S82; empty until the owner publishes one). */
export const pathsOf = (classId: string): SkillPath[] =>
  load("skills").paths.filter((p) => p.class === classId).sort((a, b) => a.order - b.order);

/** The rule view of an exported skill (lib/skills). */
export function ruleSkill(s: Skill): RuleSkill {
  const hasB = (rank: number): boolean => s.breakpoints.some((b) => b.rank === rank && b.b !== undefined);
  return {
    id: s.id,
    order: s.order,
    unlock: s.unlock,
    maxLevel: s.maxLevel,
    passive: s.passiveSkill,
    rankLevels: s.rankLevels,
    hasB: { 5: hasB(5), 10: hasB(10) },
    ...(s.path ? { path: s.path } : {}),
  };
}

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

// Planner (S82) -------------------------------------------------------------------------------------------------------

const PLANNER_KEYS = [
  "lvl", "lvlDec", "lvlInc", "slider", "points", "pointsLive", "main", "mainNone", "code", "copy",
  "copied", "reset", "warn", "over", "unreached", "mainLow", "old", "tabs", "base", "paths", "soon",
  "soonText", "pathPoints", "isMain", "setMain", "unsetMain", "mainHint", "mainFrom", "weapon", "weaponAny",
  "weaponRows", "row", "rowNeed", "rowClosed.level", "rowClosed.need", "rowClosed.main", "or", "rank",
  "nextAt", "rankMax", "current", "next", "notLearned", "maxed", "bp", "bpFrom", "bpHint", "bpNode", "bpNone",
  "modifiedBy", "modifiedNote", "dip", "dipMain", "nodeWeapon", "add", "remove", "hint", "active",
  "passive", "cost.mana", "cost.energy", "cooldown", "range", "aria", "state.available", "state.locked",
  "state.max", "state.partial", "kind.skill", "kind.passive", "kind.modify", "kind.aura", "kind.luck",
  "kind.keystone", "err.empty", "err.old", "err.class", "err.level", "err.main", "err.bp", "err.rank", "err.length",
  "why.unknown", "why.maxRank", "why.points", "why.level", "why.main", "why.need", "why.choice",
  "whyRefund.unknown", "whyRefund.noRank", "whyRefund.needAbove", "pathSkill",
] as const;

const weaponNames = (w: SkillPathWeapon | undefined, lang: Lang): { main: string[]; offhand: string[] } => ({
  main: (w?.main ?? []).map((type) => baseName(type, lang)),
  offhand: (w?.offhand ?? []).map((type) => baseName(type, lang)),
});

export function plannerData(c: ClassInfo, lang: Lang): PlannerData {
  const file = load("skills");
  const paths = pathsOf(c.id);
  const pathName = new Map(paths.map((p) => [p.id, name(p.name, lang)]));
  const skills: PlannerSkill[] = skillsOf(c.id).map((s) => ({
    ...ruleSkill(s),
    name: name(s.name, lang),
    glyph: s.glyph,
    color: skillColor(s),
    resource: s.resource ?? null,
    range: s.range ?? null,
    elementNote: s.elementNote ? name(s.elementNote, lang) : null,
    pathName: s.path ? (pathName.get(s.path) ?? null) : null,
    ranks: s.ranks.map((r) => ({
      level: r.requiredLevel,
      cost: r.cost,
      cooldown: r.cooldown,
      desc: name(r.desc, lang),
      ...(r.variants
        ? {
            variants: Object.fromEntries(
              Object.entries(r.variants).map(([k, v]) => [k, { cost: v.cost, cooldown: v.cooldown, desc: name(v.desc, lang) }]),
            ),
          }
        : {}),
    })),
    breakpoints: file.rules.breakpointsEnabled
      ? s.breakpoints.map((b) => ({ rank: b.rank, level: b.level, a: name(b.a.text, lang), b: b.b ? name(b.b.text, lang) : null }))
      : [],
  }));
  const plannerPaths: PlannerPath[] = paths.map((p) => ({
    id: p.id,
    class: p.class,
    order: p.order,
    name: name(p.name, lang),
    desc: name(p.desc, lang),
    role: p.role,
    roleName: t(lang, `planner.role.${p.role}` as Key),
    weapon: weaponNames(p.weapon, lang),
    rows: p.rows.map((row) => ({
      row: row.row,
      level: row.level,
      required: row.required,
      kind: row.kind,
      choice: row.choice,
      nodes: row.nodes.map((node) => {
        const own = node.weapon ? weaponNames(node.weapon, lang) : null;
        return {
          id: node.id,
          kind: node.kind,
          maxRank: node.maxRank,
          ...(node.skill ? { skill: node.skill } : {}),
          ...(node.skillB ? { skillB: node.skillB } : {}),
          ...(node.dipScale !== undefined ? { dipScale: node.dipScale } : {}),
          name: name(node.name, lang),
          glyph: node.glyph,
          modify: node.modify ? { ...node.modify } : null,
          weapon: own ? [...own.main, ...own.offhand].join(", ") || null : null,
          ranks: node.ranks.map((r) => ({ desc: name(r.desc, lang), dipDesc: r.dipDesc ? name(r.dipDesc, lang) : null })),
        };
      }),
    })),
  }));
  const rules = file.rules;
  const labels: Record<string, string> = Object.fromEntries(PLANNER_KEYS.map((k) => [k, t(lang, `planner.${k}` as Key)]));
  const scroll = getItem(SKILL_RESET_SCROLL);
  return {
    lang,
    classId: c.id,
    classColor: `var(--vw-class-${c.id})`,
    skills,
    paths: plannerPaths,
    rules: {
      maxLevel: rules.maxLevel,
      pathPointsByLevel: rules.pathPointsByLevel,
      mainPathLevel: rules.mainPathLevel,
      dipRows: rules.dipRows,
      pathPointsEvery: rules.pathPointsEvery,
      firstRowLevel: rules.rows[0]?.level ?? 0,
      capstoneLevel: rules.rows.find((r) => r.kind === "capstone")?.level ?? 0,
    },
    labels,
    scroll: { name: name(scroll?.name, lang) || SKILL_RESET_SCROLL, href: scroll ? sectionHref(lang, "items", SKILL_RESET_SCROLL) : null },
  };
}

export interface SkillRow {
  skill: Skill;
  name: string;
  color: string;
  /** Name of the published path of a path skill. */
  pathName: string | null;
  /** Character levels of ranks 5 and 10 (null when the skill has no such rank). */
  rank5: number | null;
  rank10: number | null;
  /** Character level of the last rank (S56: ranks grow with the level). */
  maxAt: number;
}

export function skillRows(c: ClassInfo, lang: Lang): SkillRow[] {
  const pathName = new Map(pathsOf(c.id).map((p) => [p.id, name(p.name, lang)]));
  return skillsOf(c.id).map((s) => ({
    skill: s,
    name: name(s.name, lang),
    color: skillColor(s),
    pathName: s.path ? (pathName.get(s.path) ?? null) : null,
    rank5: s.rankLevels[4] ?? null,
    rank10: s.rankLevels[9] ?? null,
    maxAt: s.rankLevels[s.rankLevels.length - 1] ?? s.unlock,
  }));
}
