// Class pages (S41, build time only): facts of the hero, the planner props and the rows of "All skills". Everything
// comes from classes.json, skills.json, stats.json and items.json; nothing is computed here that the game computes
// (the ranks, their levels, variants and texts are exported per rank). S82: the planner with breakpoints A/B and the
// published class paths (ROZWOJ 3.5). S148 (DESIGN-18 §14): planner v3 with the weapon pools (skill points per pool,
// the ladder tree, a bar per pool) and the directions; the static sections "How a skill grows", "Directions" and the
// skills of every pool.
import type { ClassInfo, Skill, SkillPath, SkillPathWeapon, SkillPool } from "../data/types";
import type { Key } from "../i18n/pl";
import type { Lang } from "../i18n/routes";
import { artFor } from "./art";
import { getItem, load } from "./data";
import { formatNumber } from "./format";
import { name, t } from "./i18n";
import { iconFor } from "./icons";
import { sectionHref } from "./sections";
import { type PlanCtx, type PlannerData, type PlannerPath, type PlannerPool, type PlannerSkill, type RuleSkill } from "./skills";

/** Scroll of Skill Renewal (S138): the full reset of every pool's ranks and the nodes. */
export const SKILL_RESET_SCROLL = "scroll_skillreset";

export const classes = (): ClassInfo[] => [...load("classes").classes].sort((a, b) => a.order - b.order);
export const getClass = (id: string): ClassInfo | undefined => classes().find((c) => c.id === id);
export const skillsOf = (classId: string): Skill[] =>
  load("skills").skills.filter((s) => s.class === classId).sort((a, b) => a.order - b.order);
/** Published directions of a class (S82 paths; S148: all published). */
export const pathsOf = (classId: string): SkillPath[] =>
  load("skills").paths.filter((p) => p.class === classId).sort((a, b) => a.order - b.order);
/** Weapon pools of a class (S138, DESIGN-18 §4) in data order. */
export const poolsOf = (classId: string): SkillPool[] => load("skills").classPools.find((c) => c.class === classId)?.pools ?? [];
export const defaultPoolOf = (classId: string): string =>
  load("skills").classPools.find((c) => c.class === classId)?.defaultPool ?? poolsOf(classId)[0]?.id ?? "";

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
    ...(s.pool ? { pool: s.pool } : {}),
    ...(s.role ? { role: s.role } : {}),
    ...(s.path ? { path: s.path } : {}),
  };
}

/** The rule context of a class (lib/skills) straight from skills.json. */
export function planCtxOf(classId: string): PlanCtx {
  const rules = load("skills").rules;
  return {
    classId,
    skills: skillsOf(classId).map(ruleSkill),
    pools: poolsOf(classId).map((p) => ({ id: p.id, skills: [...p.skills] })),
    paths: pathsOf(classId),
    rules: {
      maxLevel: rules.maxLevel,
      skillPointsByLevel: rules.skillPointsByLevel,
      pathPointsByLevel: rules.pathPointsByLevel,
      capstonesMax: rules.capstonesMax,
      mainMinPoints: rules.mainMinPoints,
      teamFullPoints: rules.teamFullPoints,
      dipRows: rules.dipRows,
      barSlots: rules.barSlots,
    },
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


// Planner v3 (S148) ----------------------------------------------------------------------------------------------------

const PLANNER_KEYS = [
  "lvl", "lvlDec", "lvlInc", "slider", "skillPoints", "skillPointsLive", "talentPoints", "talentPointsLive", "leading",
  "leadingNone", "code", "copy", "copied", "reset", "warn", "old", "poolOver", "ranksOver", "nodesOver", "unreached",
  "tabs", "directions", "poolFree", "weapons", "col.S", "col.A", "col.K", "col.O", "col.P", "col.U", "col.C", "level",
  "fromDirections", "others", "bar", "barEmpty", "barRemove", "barHint", "rank", "rankLimit", "nextAt", "rankMax",
  "current", "next", "notLearned", "maxed", "whatItDoes", "atRanks", "rankN", "bp", "bpFrom", "bpHint", "bpLocked",
  "bpNone", "modifiedBy", "modifiedNote", "dip", "dipFull", "nodeWeapon", "add", "remove", "toBar", "fromBar",
  "barFull", "active", "passive", "cost.mana", "cost.energy", "cooldown", "range", "aria", "state.available",
  "state.locked", "state.max", "state.partial", "kind.skill", "kind.passive", "kind.modify", "kind.aura", "kind.luck",
  "kind.keystone", "err.empty", "err.old", "err.class", "err.level", "err.pool", "err.rank", "err.bar", "err.talent",
  "err.bp", "err.length", "whySkill.badRequest", "whySkill.pool", "whySkill.locked", "whySkill.limit",
  "whySkill.points", "whyNode.unknown", "whyNode.maxRank", "whyNode.points", "whyNode.level", "whyNode.need",
  "whyNode.choice", "whyNode.capstoneTaken", "whyNode.upgrade", "whyRefund.unknown", "whyRefund.noRank",
  "whyRefund.needAbove", "pathSkill", "row", "rowNeed", "rowClosed.level", "rowClosed.need", "or", "capstoneRule",
  "leadingRule", "dipRule", "refundHint", "isLeading", "hasCapstone", "pathPoints", "lockedAt", "needNode",
] as const;

const weaponNames = (w: SkillPathWeapon | undefined, lang: Lang): string[] =>
  [...(w?.main ?? []), ...(w?.offhand ?? [])].map((type) => baseName(type, lang));

/** Element name of a pool (Mage) from elements.json, or null. */
function elementName(id: string | undefined, lang: Lang): string | null {
  if (!id) return null;
  return name(load("elements").elements.find((e) => e.id === id)?.name, lang) || id;
}

export function plannerSkill(s: Skill, lang: Lang, pathName: Map<string, string>): PlannerSkill {
  const enabled = load("skills").rules.breakpointsEnabled;
  return {
    ...ruleSkill(s),
    name: name(s.name, lang),
    short: name(s.short, lang),
    glyph: s.glyph,
    pic: artFor("skill", s.id),
    color: skillColor(s),
    resource: s.resource ?? null,
    range: s.range ?? null,
    elementNote: s.elementNote ? name(s.elementNote, lang) : null,
    pathName: s.path ? (pathName.get(s.path) ?? null) : null,
    ranks: s.ranks.map((r) => ({
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
    breakpoints: enabled
      ? s.breakpoints.map((b) => ({ rank: b.rank, level: b.level, a: name(b.a.text, lang), b: b.b ? name(b.b.text, lang) : null }))
      : [],
  };
}

export function plannerPath(p: SkillPath, lang: Lang): PlannerPath {
  return {
    id: p.id,
    class: p.class,
    order: p.order,
    name: name(p.name, lang),
    desc: name(p.desc, lang),
    role: p.role,
    roleName: t(lang, `planner.role.${p.role}` as Key),
    rows: p.rows.map((row) => ({
      row: row.row,
      level: row.level,
      required: row.required,
      kind: row.kind,
      choice: row.choice,
      nodes: row.nodes.map((node) => ({
        id: node.id,
        kind: node.kind,
        maxRank: node.maxRank,
        ...(node.skill ? { skill: node.skill } : {}),
        ...(node.skillB ? { skillB: node.skillB } : {}),
        ...(node.dipScale !== undefined ? { dipScale: node.dipScale } : {}),
        name: name(node.name, lang),
        glyph: node.glyph,
        modify: node.modify ? { ...node.modify } : null,
        weapon: node.weapon ? weaponNames(node.weapon, lang).join(", ") || null : null,
        ranks: node.ranks.map((r) => ({ desc: name(r.desc, lang), dipDesc: r.dipDesc ? name(r.dipDesc, lang) : null })),
      })),
    })),
  };
}

export function plannerPools(classId: string, lang: Lang): PlannerPool[] {
  return poolsOf(classId).map((p) => ({
    id: p.id,
    skills: [...p.skills],
    name: name(p.name, lang),
    glyph: p.glyph,
    weapons: p.weapons.map((w) => baseName(w, lang)),
    element: elementName(p.element, lang),
    identity: t(lang, `class.pool.${p.id}` as Key),
  }));
}

export function plannerData(c: ClassInfo, lang: Lang): PlannerData {
  const ctx = planCtxOf(c.id);
  const paths = pathsOf(c.id);
  const pathName = new Map(paths.map((p) => [p.id, name(p.name, lang)]));
  const rules = load("skills").rules;
  const labels: Record<string, string> = Object.fromEntries(PLANNER_KEYS.map((k) => [k, t(lang, `planner.${k}` as Key)]));
  const scroll = getItem(SKILL_RESET_SCROLL);
  return {
    lang,
    classId: c.id,
    classColor: `var(--vw-class-${c.id})`,
    skills: skillsOf(c.id).map((s) => plannerSkill(s, lang, pathName)),
    pools: plannerPools(c.id, lang),
    defaultPool: defaultPoolOf(c.id),
    paths: paths.map((p) => plannerPath(p, lang)),
    rules: { ...ctx.rules, pathPointsEvery: rules.pathPointsEvery, freeRespecLevel: rules.freeRespecLevel },
    labels,
    scroll: { name: name(scroll?.name, lang) || SKILL_RESET_SCROLL, href: scroll ? sectionHref(lang, "items", SKILL_RESET_SCROLL) : null },
  };
}

// Static sections (S148) -------------------------------------------------------------------------------------------------

/** Numbers of "How a skill grows" (all from skills.json rules). */
export interface GrowthFacts {
  pointsAt: { level: number; n: number }[];
  barSlots: number;
  freeRespecLevel: number;
  pathPointsEvery: number;
  pathPointsMax: number;
  capstonesMax: number;
  mainMinPoints: number;
  teamFullPoints: number;
  dipRows: number;
  breakpointLevels: number[];
}

export function growthFacts(): GrowthFacts {
  const r = load("skills").rules;
  const at = (level: number): number => r.skillPointsByLevel[Math.min(level, r.skillPointsByLevel.length) - 1] ?? 0;
  return {
    pointsAt: [1, 20, 45, 70, r.maxLevel].map((level) => ({ level, n: at(level) })),
    barSlots: r.barSlots,
    freeRespecLevel: r.freeRespecLevel,
    pathPointsEvery: r.pathPointsEvery,
    pathPointsMax: r.pathPointsByLevel[r.pathPointsByLevel.length - 1] ?? 0,
    capstonesMax: r.capstonesMax,
    mainMinPoints: r.mainMinPoints,
    teamFullPoints: r.teamFullPoints,
    dipRows: r.dipRows,
    breakpointLevels: r.breakpointLevels,
  };
}

export interface SkillRow {
  skill: Skill;
  name: string;
  short: string;
  color: string;
  /** Ladder role code (S1…U, C1…C4) or null for a direction skill. */
  role: string | null;
  /** Name of the direction of a direction skill. */
  pathName: string | null;
  /** Ranks shown in the card: 1, 5 and 10 (as far as the skill goes) and the last one. */
  shown: number[];
  /** Levels from which ranks 5 and 10 (a passive: its last rank) can be bought. */
  rankFrom: { rank: number; level: number }[];
  /** Direction nodes that change the skill: node name and direction name. */
  modifiedBy: { node: string; path: string }[];
}

export interface SkillGroup {
  id: string;
  title: string;
  glyph: string;
  identity: string | null;
  weapons: string | null;
  rows: SkillRow[];
}

/** "All skills" by pool (S148): the school of every pool in ladder order, then the common skills, then the direction
 * skills (each skill once). */
export function skillGroups(c: ClassInfo, lang: Lang): SkillGroup[] {
  const paths = pathsOf(c.id);
  const pathName = new Map(paths.map((p) => [p.id, name(p.name, lang)]));
  const byId = new Map(skillsOf(c.id).map((s) => [s.id, s]));
  const mods = new Map<string, { node: string; path: string }[]>();
  for (const p of paths) {
    for (const node of p.rows.flatMap((r) => r.nodes)) {
      if (!node.modify) continue;
      const list = mods.get(node.modify.skill) ?? [];
      list.push({ node: name(node.name, lang), path: name(p.name, lang) });
      mods.set(node.modify.skill, list);
    }
  }
  const row = (s: Skill): SkillRow => ({
    skill: s,
    name: name(s.name, lang),
    short: name(s.short, lang),
    color: skillColor(s),
    role: s.path ? null : (s.role ?? null),
    pathName: s.path ? (pathName.get(s.path) ?? null) : null,
    shown: [...new Set([1, 5, 10, s.maxLevel].filter((r) => r <= s.maxLevel))],
    rankFrom: (s.maxLevel >= 10 ? [5, 10] : [s.maxLevel]).map((rank) => ({ rank, level: s.rankLevels[rank - 1] ?? s.unlock })),
    modifiedBy: mods.get(s.id) ?? [],
  });
  const seen = new Set<string>();
  const take = (ids: string[], keep: (s: Skill) => boolean): SkillRow[] =>
    ids
      .map((id) => byId.get(id))
      .filter((s): s is Skill => !!s && keep(s) && !seen.has(s.id))
      .map((s) => {
        seen.add(s.id);
        return row(s);
      });
  const groups: SkillGroup[] = [];
  const pools = poolsOf(c.id);
  for (const p of pools) {
    const element = elementName(p.element, lang);
    groups.push({
      id: p.id,
      title: name(p.name, lang),
      glyph: p.glyph,
      identity: t(lang, `class.pool.${p.id}` as Key),
      weapons: [p.weapons.map((w) => baseName(w, lang)).join(", "), element].filter(Boolean).join(" · "),
      rows: take(p.skills, (s) => s.pool === p.id),
    });
  }
  const all = pools.flatMap((p) => p.skills);
  const common = take(all, (s) => s.pool === "common");
  if (common.length > 0) {
    groups.push({ id: "common", title: t(lang, "class.commonSkills"), glyph: c.icon, identity: t(lang, "class.commonText"), weapons: null, rows: common });
  }
  const direction = take(all, (s) => s.path !== undefined);
  if (direction.length > 0) {
    groups.push({ id: "directions", title: t(lang, "class.directionSkills"), glyph: "✦", identity: t(lang, "class.directionText"), weapons: null, rows: direction });
  }
  const rest = take([...byId.keys()], () => true);
  if (rest.length > 0) groups.push({ id: "other", title: t(lang, "class.otherSkills"), glyph: "·", identity: null, weapons: null, rows: rest });
  return groups;
}

export interface DirectionNodeCard {
  id: string;
  name: string;
  glyph: string;
  kind: string;
  maxRank: number;
  first: string;
  last: string;
  weapon: string | null;
}

export interface DirectionCard {
  id: string;
  name: string;
  desc: string;
  roleName: string;
  rows: { row: number; level: number; required: number; kind: string; choice: boolean; nodes: DirectionNodeCard[] }[];
}

/** The static "Directions" section (S148): every published direction with its rows and nodes (rank 1 and the last). */
export function directionCards(c: ClassInfo, lang: Lang): DirectionCard[] {
  return pathsOf(c.id).map((p) => ({
    id: p.id,
    name: name(p.name, lang),
    desc: name(p.desc, lang),
    roleName: t(lang, `planner.role.${p.role}` as Key),
    rows: p.rows.map((r) => ({
      row: r.row,
      level: r.level,
      required: r.required,
      kind: r.kind,
      choice: r.choice,
      nodes: r.nodes.map((n) => ({
        id: n.id,
        name: name(n.name, lang),
        glyph: n.glyph,
        kind: n.kind,
        maxRank: n.maxRank,
        first: name(n.ranks[0]?.desc, lang),
        last: name(n.ranks[n.ranks.length - 1]?.desc, lang),
        weapon: n.weapon ? weaponNames(n.weapon, lang).join(", ") || null : null,
      })),
    })),
  }));
}
