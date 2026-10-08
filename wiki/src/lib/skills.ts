// Skill planner rules (S41). Pure functions shared by the class page (build time) and the SkillPlanner island. No
// game formula is repeated here: points per level, the character level of every rank and the requirements come
// from skills.json; these functions only compare those numbers, in the order of Skills.canLearn (maxLevel ->
// noPoints -> level -> requires). Parity with the game is checked against rules.vectors (computed in Lune).

/** The part of a skill the rules need (a Skill from skills.json fits). */
export interface RuleSkill {
  id: string;
  order: number;
  unlock: number;
  maxLevel: number;
  requires: { skill: string; level: number }[];
  ranks: { requiredLevel: number }[];
}

export interface RuleSet {
  maxLevel: number;
  pointsByLevel: number[];
}

/** Learned ranks by skill id (missing = 0). */
export type Build = Record<string, number>;

export type LearnError = "maxLevel" | "noPoints" | "level" | "requires";

export interface AddResult {
  ok: boolean;
  reason?: LearnError;
  /** "level": the character level needed; "requires": the unmet requirement. */
  detail?: number | { skill: string; level: number };
}

export type NodeState = "locked" | "available" | "partial" | "max";

const rankOf = (build: Build, id: string): number => build[id] ?? 0;

/** Skill points a character of `level` has in total. */
export function pointsAt(rules: RuleSet, level: number): number {
  const clamped = Math.min(Math.max(Math.floor(level), 1), rules.pointsByLevel.length);
  return rules.pointsByLevel[clamped - 1] ?? 0;
}

export function spent(build: Build): number {
  return Object.values(build).reduce((sum, rank) => sum + rank, 0);
}

/** Points left at `level` (negative when the build spends more than the level gives). */
export function free(rules: RuleSet, build: Build, level: number): number {
  return pointsAt(rules, level) - spent(build);
}

/** Character level needed for rank n of a skill (from the export). */
export function rankLevel(skill: RuleSkill, n: number): number {
  return skill.ranks[n - 1]?.requiredLevel ?? Infinity;
}

/** Whether the next rank of `skill` can be learned now: the same answer, reason and detail as Skills.canLearn. */
export function canAdd(rules: RuleSet, build: Build, level: number, skill: RuleSkill): AddResult {
  const current = rankOf(build, skill.id);
  if (current >= skill.maxLevel) {
    return { ok: false, reason: "maxLevel" };
  }
  if (free(rules, build, level) < 1) {
    return { ok: false, reason: "noPoints" };
  }
  const needed = rankLevel(skill, current + 1);
  if (level < needed) {
    return { ok: false, reason: "level", detail: needed };
  }
  for (const req of skill.requires) {
    if (rankOf(build, req.skill) < req.level) {
      return { ok: false, reason: "requires", detail: { skill: req.skill, level: req.level } };
    }
  }
  return { ok: true };
}

/** Skills learned in `build` whose requirement on `id` would break if it lost one rank. */
export function dependents<S extends RuleSkill>(skills: S[], build: Build, id: string): S[] {
  const after = rankOf(build, id) - 1;
  return skills.filter((s) => rankOf(build, s.id) > 0 && s.requires.some((r) => r.skill === id && after < r.level));
}

/** A rank can be removed when there is one and no learned skill loses its requirement. */
export function canRemove(skills: RuleSkill[], build: Build, id: string): boolean {
  return rankOf(build, id) > 0 && dependents(skills, build, id).length === 0;
}

export interface Validation {
  ok: boolean;
  /** Points spent above what the level gives (0 when fine). */
  over: number;
  /** Skills whose rank needs a higher character level. */
  tooHigh: string[];
  /** Skills with an unmet requirement or a rank above their maximum. */
  broken: string[];
}

/** Whether `build` can exist at `level` (the game's replay through canLearn gives the same answer). */
export function validate(skills: RuleSkill[], rules: RuleSet, build: Build, level: number): Validation {
  const tooHigh: string[] = [];
  const broken: string[] = [];
  const byId = new Map(skills.map((s) => [s.id, s]));
  for (const [id, rank] of Object.entries(build)) {
    if (rank <= 0) {
      continue;
    }
    const skill = byId.get(id);
    if (!skill || rank > skill.maxLevel) {
      broken.push(id);
      continue;
    }
    if (rankLevel(skill, rank) > level) {
      tooHigh.push(id);
    }
    if (skill.requires.some((r) => rankOf(build, r.skill) < r.level)) {
      broken.push(id);
    }
  }
  const over = Math.max(0, -free(rules, build, level));
  return { ok: over === 0 && tooHigh.length === 0 && broken.length === 0, over, tooHigh, broken };
}

/** The lowest character level at which `build` is valid, or null when no level is enough. */
export function requiredCharLevel(skills: RuleSkill[], rules: RuleSet, build: Build): number | null {
  for (let level = 1; level <= rules.maxLevel; level++) {
    if (validate(skills, rules, build, level).ok) {
      return level;
    }
  }
  return null;
}

/** The highest rank reachable at the maximum character level (lower than maxLevel for late capstones). */
export function maxReachableRank(skill: RuleSkill, maxLevel: number): number {
  let best = 0;
  for (let n = 1; n <= skill.maxLevel; n++) {
    if (rankLevel(skill, n) <= maxLevel) {
      best = n;
    }
  }
  return best;
}

/**
 * Look of a node: locked (not learned and its unlock level or a requirement is not met), available, partial, max;
 * `invalid` when the learned rank needs a higher character level than the chosen one.
 */
export function nodeState(build: Build, level: number, skill: RuleSkill): { state: NodeState; invalid: boolean } {
  const rank = rankOf(build, skill.id);
  const invalid = rank > 0 && rankLevel(skill, rank) > level;
  if (rank >= skill.maxLevel) {
    return { state: "max", invalid };
  }
  if (rank > 0) {
    return { state: "partial", invalid };
  }
  const unmet = skill.unlock > level || skill.requires.some((r) => rankOf(build, r.skill) < r.level);
  return { state: unmet ? "locked" : "available", invalid };
}

// Build code ---------------------------------------------------------------------------------------------------------

const GROUP = 7;

export type DecodeError = "empty" | "class" | "length" | "rank" | "level";

export type Decoded =
  | { ok: true; classId: string; level: number; build: Build }
  | { ok: false; error: DecodeError };

const rankChar = (rank: number): string => (rank >= 10 ? "a" : String(Math.max(0, rank)));

/** `<CLASSID><level>-<ranks>`: one character per skill in `order` (0–9, a = 10), a dash every 7 characters. */
export function encodeBuild(classId: string, level: number, skills: RuleSkill[], build: Build): string {
  const ranks = [...skills]
    .sort((a, b) => a.order - b.order)
    .map((s) => rankChar(rankOf(build, s.id)))
    .join("");
  const groups: string[] = [];
  for (let i = 0; i < ranks.length; i += GROUP) {
    groups.push(ranks.slice(i, i + GROUP));
  }
  return [`${classId.toUpperCase()}${level}`, ...groups].join("-");
}

/** Reads a build code of one class; dashes, spaces and letter case do not matter. Never throws. */
export function decodeBuild(code: string, classId: string, skills: RuleSkill[], rules: RuleSet): Decoded {
  const raw = String(code ?? "").replace(/\s/g, "").toUpperCase();
  const text = raw.replace(/-/g, "");
  if (text === "") {
    return { ok: false, error: "empty" };
  }
  const prefix = classId.toUpperCase();
  const head = /^[A-Z]+/.exec(text)?.[0] ?? "";
  if (head !== prefix) {
    return { ok: false, error: "class" };
  }
  const ordered = [...skills].sort((a, b) => a.order - b.order);
  // With dashes the header ends at the first one; without them the ranks are the last characters.
  const dash = raw.indexOf("-");
  const headerLength = dash > 0 ? dash : text.length - ordered.length;
  const levelText = text.slice(prefix.length, headerLength);
  const ranksText = text.slice(headerLength);
  if (ranksText.length !== ordered.length || headerLength <= prefix.length) {
    return { ok: false, error: "length" };
  }
  if (!/^\d{1,3}$/.test(levelText)) {
    return { ok: false, error: "level" };
  }
  const level = Number(levelText);
  if (level < 1 || level > rules.maxLevel) {
    return { ok: false, error: "level" };
  }
  const build: Build = {};
  for (let i = 0; i < ordered.length; i++) {
    const ch = ranksText[i];
    const rank = ch === "A" ? 10 : /\d/.test(ch) ? Number(ch) : NaN;
    if (Number.isNaN(rank) || rank > ordered[i].maxLevel) {
      return { ok: false, error: "rank" };
    }
    if (rank > 0) {
      build[ordered[i].id] = rank;
    }
  }
  return { ok: true, classId, level, build };
}

// Planner props (S41): the slice of one class in one language the island gets (it never imports src/data).

export interface PlannerSkill extends RuleSkill {
  name: string;
  glyph: string;
  /** CSS colour of the glyph: the element, else the class. */
  color: string;
  passive: boolean;
  col: number;
  row: number;
  resource: string | null;
  range: number | null;
  elementNote: string | null;
  ranks: { requiredLevel: number; cost: number; cooldown: number; desc: string }[];
  breakpoints: { level: number; text: string }[];
}

export interface PlannerData {
  lang: "pl" | "en";
  classId: string;
  classColor: string;
  skills: PlannerSkill[];
  rules: RuleSet;
  /** Interface texts with {placeholders} (planner.* keys without the prefix). */
  labels: Record<string, string>;
  scroll: { name: string; href: string | null };
}

/** "{n} many" with the placeholders filled. */
export function fill(text: string, args: Record<string, string | number>): string {
  return text.replace(/\{(\w+)\}/g, (whole, key: string) => (key in args ? String(args[key]) : whole));
}
