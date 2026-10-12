// Skill planner rules (S82, ROZWOJ 3.5, docs/WIKI.md "SkillPlanner"). Pure functions shared by the class page (build
// time), the SkillPlanner island and the tests; no import of src/data (the data comes as arguments).
// Nothing the game computes is repeated here: path points per level, rank levels, descriptions, variants and the
// row rules come from skills.json. The path rules mirror Logic/Paths.canBuy / canRefund check by check (same reason
// keys, same order); parity is tested against vectors computed in Lune (rules.vectors and
// wiki/test-fixtures/planner.json). Build code v2: see encodeBuild.

/** The part of a skill the rules need. */
export interface RuleSkill {
  id: string;
  order: number;
  unlock: number;
  maxLevel: number;
  passive: boolean;
  rankLevels: number[];
  hasB: { 5: boolean; 10: boolean };
  path?: string;
}

/** The part of a path node the rules need (a SkillPathNode from skills.json fits). */
export interface RuleNode {
  id: string;
  kind: string;
  maxRank: number;
  skill?: string;
  skillB?: number[];
  dipScale?: number;
}

export interface RuleRow {
  row: number;
  level: number;
  required: number;
  kind: string;
  choice: boolean;
  nodes: RuleNode[];
}

/** A published path (a SkillPath from skills.json fits). */
export interface RulePath {
  id: string;
  class: string;
  order: number;
  rows: RuleRow[];
}

export interface PathRules {
  maxLevel: number;
  pathPointsByLevel: number[];
  mainPathLevel: number;
  dipRows: number;
}

export type Option = "a" | "b";

/** One build set: like the game save (path.main, path.nodes, path.bp with keys "<skillId>:5"). */
export interface PlanBuild {
  level: number;
  main: string | null;
  nodes: Record<string, number>;
  bp: Record<string, Option>;
}

/** Reason keys of Logic/Paths.canBuy in the order it checks them. */
export const BUY_ERRORS = [
  "paths.error.unknown",
  "paths.error.maxRank",
  "paths.error.points",
  "paths.error.level",
  "paths.error.main",
  "paths.error.need",
  "paths.error.choice",
] as const;
/** Reason keys of Logic/Paths.canRefund. */
export const REFUND_ERRORS = ["paths.error.unknown", "paths.error.noRank", "paths.error.needAbove"] as const;

export type BuyError = (typeof BUY_ERRORS)[number];
export type RefundError = (typeof REFUND_ERRORS)[number];
export interface BuyResult {
  ok: boolean;
  reason?: BuyError;
}
export interface RefundResult {
  ok: boolean;
  reason?: RefundError;
}

/** Last part of a reason key ("paths.error.need" -> "need"), for the planner.why.* texts. */
export const reasonCode = (key: string): string => key.slice(key.lastIndexOf(".") + 1);

export const emptyBuild = (level: number): PlanBuild => ({ level, main: null, nodes: {}, bp: {} });

const rankIn = (build: PlanBuild, id: string): number => build.nodes[id] ?? 0;

// Base skills ---------------------------------------------------------------------------------------------------------

/** Rank of `skill` at character level `level` (the number of rankLevels <= level; 0 before the unlock). */
export function rankAt(skill: { rankLevels: number[] }, level: number): number {
  let rank = 0;
  for (const at of skill.rankLevels) if (level >= at) rank++;
  return rank;
}

/** Character level of the next rank, or null at the last one. */
export function nextRankLevel(skill: { rankLevels: number[] }, level: number): number | null {
  const rank = rankAt(skill, level);
  return rank < skill.rankLevels.length ? skill.rankLevels[rank] : null;
}

/** Whether the breakpoint of `rank` can be chosen at `level` (the rank is reached). */
export function bpOpen(skill: { rankLevels: number[] }, rank: number, level: number): boolean {
  const at = skill.rankLevels[rank - 1];
  return at !== undefined && level >= at;
}

export const choiceKey = (skillId: string, rank: number): string => `${skillId}:${rank}`;

/** The chosen option: "b" only with a "b" entry (a missing entry works as A, like the game). */
export function choiceAt(build: PlanBuild, skillId: string, rank: number): Option {
  return build.bp[choiceKey(skillId, rank)] === "b" ? "b" : "a";
}

/** Two letters (choice at rank 5, at rank 10) of the numbers that work at `rank`: "aa" = the rank itself, any other
 * key = ranks[rank - 1].variants[key]. A letter counts only from its rank. */
export function variantKey(build: PlanBuild, skill: { id: string }, rank: number): string {
  const five = rank >= 5 ? choiceAt(build, skill.id, 5) : "a";
  const ten = rank >= 10 ? choiceAt(build, skill.id, 10) : "a";
  return five + ten;
}

/** A new build with the option of `rank` set ("a" removes the entry: no entry works as A). */
export function setChoice(build: PlanBuild, skillId: string, rank: number, option: Option): PlanBuild {
  const bp = { ...build.bp };
  if (option === "b") bp[choiceKey(skillId, rank)] = "b";
  else delete bp[choiceKey(skillId, rank)];
  return { ...build, bp };
}

// Paths (mirror of Logic/Paths) -----------------------------------------------------------------------------------------

interface Found {
  path: RulePath;
  row: number;
  node: RuleNode;
}

/** The node, its path and its row (1-based) among `paths`. */
export function findNode(paths: RulePath[], nodeId: string): Found | null {
  for (const path of paths) {
    for (const row of path.rows) {
      for (const node of row.nodes) if (node.id === nodeId) return { path, row: row.row, node };
    }
  }
  return null;
}

/** Path points of a character of `level` (rules.pathPointsByLevel). */
export function pointsAt(rules: PathRules, level: number): number {
  const clamped = Math.min(Math.max(Math.floor(level), 1), rules.pathPointsByLevel.length);
  return rules.pathPointsByLevel[clamped - 1] ?? 0;
}

/** Sum of node ranks (only known nodes with rank > 0, as the game). */
export function spent(paths: RulePath[], build: PlanBuild): number {
  let total = 0;
  for (const [id, rank] of Object.entries(build.nodes)) {
    if (rank > 0 && findNode(paths, id)) total += rank;
  }
  return total;
}

/** Free path points (negative when the build has more than the level gives). */
export function free(paths: RulePath[], rules: PathRules, build: PlanBuild): number {
  return pointsAt(rules, build.level) - spent(paths, build);
}

const rowRanks = (nodes: Record<string, number>, path: RulePath, row: number): number =>
  (path.rows[row - 1]?.nodes ?? []).reduce((n, node) => n + (nodes[node.id] ?? 0), 0);

const ranksBelow = (nodes: Record<string, number>, path: RulePath, row: number): number => {
  let total = 0;
  for (let r = 1; r < row; r++) total += rowRanks(nodes, path, r);
  return total;
};

/** Ranks bought in a path. */
export function pathPoints(path: RulePath, build: PlanBuild): number {
  return ranksBelow(build.nodes, path, path.rows.length + 1);
}

/** Why a row of a path is closed (Logic/Paths.rowOpen order: level, main path, requirement), null when open. */
export function rowClosed(path: RulePath, rules: PathRules, build: PlanBuild, row: number): "level" | "main" | "need" | null {
  const def = path.rows[row - 1];
  if (build.level < def.level) return "level";
  if (row > rules.dipRows && build.main !== path.id) return "main";
  if (ranksBelow(build.nodes, path, row) < def.required) return "need";
  return null;
}

const ROW_ERRORS: Record<"level" | "main" | "need", BuyError> = {
  level: "paths.error.level",
  main: "paths.error.main",
  need: "paths.error.need",
};

/** Buying one rank (Logic/Paths.canBuy): unknown, maxRank, points, level, main, need, choice. */
export function canBuy(paths: RulePath[], rules: PathRules, build: PlanBuild, nodeId: string): BuyResult {
  const found = findNode(paths, nodeId);
  if (!found) return { ok: false, reason: "paths.error.unknown" };
  if (rankIn(build, nodeId) >= found.node.maxRank) return { ok: false, reason: "paths.error.maxRank" };
  if (free(paths, rules, build) < 1) return { ok: false, reason: "paths.error.points" };
  const closed = rowClosed(found.path, rules, build, found.row);
  if (closed) return { ok: false, reason: ROW_ERRORS[closed] };
  const row = found.path.rows[found.row - 1];
  if (row.choice && row.nodes.some((other) => other.id !== nodeId && rankIn(build, other.id) > 0)) {
    return { ok: false, reason: "paths.error.choice" };
  }
  return { ok: true };
}

/** Refunding one rank (Logic/Paths.canRefund): every higher row with ranks keeps its requirement. */
export function canRefund(paths: RulePath[], _rules: PathRules, build: PlanBuild, nodeId: string): RefundResult {
  const found = findNode(paths, nodeId);
  if (!found) return { ok: false, reason: "paths.error.unknown" };
  const rank = rankIn(build, nodeId);
  if (rank <= 0) return { ok: false, reason: "paths.error.noRank" };
  const nodes = { ...build.nodes, [nodeId]: rank - 1 };
  for (let r = found.row + 1; r <= found.path.rows.length; r++) {
    if (rowRanks(nodes, found.path, r) > 0 && ranksBelow(nodes, found.path, r) < found.path.rows[r - 1].required) {
      return { ok: false, reason: "paths.error.needAbove" };
    }
  }
  return { ok: true };
}

/** A new build with one rank more / less (no check: call canBuy / canRefund first). */
export function addRank(build: PlanBuild, nodeId: string, delta: 1 | -1): PlanBuild {
  const nodes = { ...build.nodes };
  const rank = (nodes[nodeId] ?? 0) + delta;
  if (rank > 0) nodes[nodeId] = rank;
  else delete nodes[nodeId];
  return { ...build, nodes };
}

/** Whether a new character of the build's level may pick a main path (Logic/Paths.canChooseMain level check). */
export function canSetMain(rules: PathRules, build: PlanBuild): boolean {
  return build.level >= rules.mainPathLevel;
}

/** The ranks a new character of the build's level reaches: Skills.pathAchievable in Lune, step by step (paths by
 * order, rows ascending, nodes in row order, each `while rank < target and canBuy`, repeated while anything changes).
 * A main path the character cannot pick (unknown, below mainPathLevel) is left out. */
function replay(paths: RulePath[], rules: PathRules, build: PlanBuild): { have: Record<string, number>; mainOk: boolean } {
  const mainOk = build.main === null || (paths.some((p) => p.id === build.main) && canSetMain(rules, build));
  const probe: PlanBuild = { level: build.level, main: mainOk ? build.main : null, nodes: {}, bp: {} };
  const sorted = [...paths].sort((a, b) => a.order - b.order);
  let changed = true;
  while (changed) {
    changed = false;
    for (const path of sorted) {
      for (const row of path.rows) {
        for (const node of row.nodes) {
          const target = build.nodes[node.id] ?? 0;
          while ((probe.nodes[node.id] ?? 0) < target && canBuy(paths, rules, probe, node.id).ok) {
            probe.nodes[node.id] = (probe.nodes[node.id] ?? 0) + 1;
            changed = true;
          }
        }
      }
    }
  }
  return { have: probe.nodes, mainOk };
}

/** Whether a new character of the build's level can reach the build (Skills.pathAchievable). */
export function achievable(paths: RulePath[], rules: PathRules, build: PlanBuild): boolean {
  const { have, mainOk } = replay(paths, rules, build);
  if (!mainOk) return false;
  return Object.entries(build.nodes).every(([id, target]) => target <= 0 || (have[id] ?? 0) === target);
}

export interface Validation {
  ok: boolean;
  /** Points above what the level gives. */
  over: number;
  /** Nodes with ranks the replay does not reach on this level. */
  unreached: string[];
  /** The main path can be picked on this level. */
  mainOk: boolean;
}

export function validate(paths: RulePath[], rules: PathRules, build: PlanBuild): Validation {
  const { have, mainOk } = replay(paths, rules, build);
  const unreached = Object.entries(build.nodes)
    .filter(([id, target]) => target > 0 && (have[id] ?? 0) !== target)
    .map(([id]) => id);
  const over = Math.max(0, -free(paths, rules, build));
  return { ok: mainOk && unreached.length === 0 && over === 0, over, unreached, mainOk };
}

/** The main path changed like ChooseMainPath in the game: the ranks of rows above dipRows of the old main path go
 * back; null removes the main path and the same ranks. */
export function setMain(paths: RulePath[], rules: PathRules, build: PlanBuild, pathId: string | null): PlanBuild {
  if (pathId === build.main) return build;
  const nodes = { ...build.nodes };
  const old = paths.find((p) => p.id === build.main);
  if (old) {
    for (const row of old.rows) {
      if (row.row > rules.dipRows) for (const node of row.nodes) delete nodes[node.id];
    }
  }
  return { ...build, main: pathId, nodes };
}

/** A new build without the A/B choices of path skills whose skill node has no rank: the code carries them only with
 * the node (call after a refund or a main path change, so the build on screen matches its code). */
export function pruneChoices(paths: RulePath[], build: PlanBuild): PlanBuild {
  const drop = paths.flatMap((p) =>
    p.rows.flatMap((r) => r.nodes.filter((n) => n.kind === "skill" && n.skill && rankIn(build, n.id) <= 0).map((n) => n.skill!)),
  );
  const bp = { ...build.bp };
  let changed = false;
  for (const skill of drop) {
    for (const rank of [5, 10]) {
      if (choiceKey(skill, rank) in bp) {
        delete bp[choiceKey(skill, rank)];
        changed = true;
      }
    }
  }
  return changed ? { ...build, bp } : build;
}

// View models (the island only draws them)----------------------------------------------------------------------------

export type NodeState = "locked" | "available" | "partial" | "max";

export interface BaseRow {
  id: string;
  rank: number;
  max: number;
  next: number | null;
  bp: { rank: number; level: number; open: boolean; choice: Option; hasB: boolean }[];
}

/** Rows of the base list: rank from the level, next rank, breakpoints 5 and 10 (actives only). */
export function baseView(skills: RuleSkill[], build: PlanBuild): BaseRow[] {
  return skills.map((s) => ({
    id: s.id,
    rank: rankAt(s, build.level),
    max: s.maxLevel,
    next: nextRankLevel(s, build.level),
    bp: s.passive
      ? []
      : ([5, 10] as const)
          .filter((r) => r <= s.maxLevel)
          .map((r) => ({
            rank: r,
            level: s.rankLevels[r - 1],
            open: bpOpen(s, r, build.level),
            choice: choiceAt(build, s.id, r),
            hasB: s.hasB[r],
          })),
  }));
}

export interface NodeView {
  id: string;
  rank: number;
  max: number;
  state: NodeState;
  invalid: boolean;
  buy: BuyResult;
  refund: RefundResult;
  dip: boolean;
}

export interface RowView {
  row: number;
  level: number;
  required: number;
  have: number;
  open: boolean;
  reason: "level" | "need" | "main" | null;
  nodes: NodeView[];
}

export interface PathView {
  isMain: boolean;
  points: number;
  rows: RowView[];
}

/** A path tab: rows with their requirement and why they are closed, nodes with state, purchase / refund and the 1/3
 * strength of team nodes outside the main path. */
export function pathView(path: RulePath, paths: RulePath[], rules: PathRules, build: PlanBuild): PathView {
  const unreached = new Set(validate(paths, rules, build).unreached);
  const isMain = build.main === path.id;
  return {
    isMain,
    points: pathPoints(path, build),
    rows: path.rows.map((row) => {
      const reason = rowClosed(path, rules, build, row.row);
      return {
        row: row.row,
        level: row.level,
        required: row.required,
        have: ranksBelow(build.nodes, path, row.row),
        open: reason === null,
        reason,
        nodes: row.nodes.map((node) => {
          const rank = rankIn(build, node.id);
          // A choice row whose other node has ranks is "taken" (Logic/PathView): drawn locked, as the game dims it.
          const taken = row.choice && rank === 0 && rowRanks(build.nodes, path, row.row) > 0;
          const state: NodeState = rank >= node.maxRank ? "max" : rank > 0 ? "partial" : reason === null && !taken ? "available" : "locked";
          return {
            id: node.id,
            rank,
            max: node.maxRank,
            state,
            invalid: rank > 0 && unreached.has(node.id),
            buy: canBuy(paths, rules, build, node.id),
            refund: canRefund(paths, rules, build, node.id),
            dip: node.dipScale !== undefined && !isMain,
          };
        }),
      };
    }),
  };
}

// Build code v2 -------------------------------------------------------------------------------------------------------
//
//   2<CLASS><level>.<main>.<breakpoints>.<path order 1>.<path order 2>[.<path order 3>]
//
// "2" = version; <CLASS> = class id in capitals; <main> = order of the published main path or 0; <breakpoints> = one
// character 0-3 per active base skill (no path) in `order` (bit 1 = B at rank 5, bit 2 = B at rank 10); path segments
// are positional (segment k = the path with order k; a path the planner does not know has an empty segment), one
// digit per node (rows ascending, nodes in row order): a normal node 0..maxRank, a skill node 0 or 1 + the breakpoint
// bits of its skill (allowed by skillB). Canonical: <main> always, trailing zeros of every later segment cut and empty
// segments at the end left out ("2MAGE34.0", "2MAGE34.0.1", "2MAGE60.1..1333"). Letter case and spaces do not matter.
// The code does not check the game rules (validate does).

export type CodeError = "empty" | "old" | "class" | "level" | "main" | "bp" | "rank" | "length";

export interface CodeCtx {
  classId: string;
  maxLevel: number;
  /** Skills of the class (base and published paths); the code uses the active base ones in `order`. */
  skills: RuleSkill[];
  /** Published paths of the class. */
  paths: RulePath[];
}

const baseActives = (ctx: CodeCtx): RuleSkill[] =>
  ctx.skills.filter((s) => !s.path && !s.passive).sort((a, b) => a.order - b.order);

const pathsByOrder = (ctx: CodeCtx): (RulePath | undefined)[] => {
  const top = Math.max(0, ...ctx.paths.map((p) => p.order));
  return Array.from({ length: top }, (_, i) => ctx.paths.find((p) => p.order === i + 1));
};

function bits(build: PlanBuild, skillId: string, has5: boolean, has10: boolean): number {
  return (has5 && choiceAt(build, skillId, 5) === "b" ? 1 : 0) | (has10 && choiceAt(build, skillId, 10) === "b" ? 2 : 0);
}

const trimZeros = (segment: string): string => segment.replace(/0+$/, "");

export function encodeBuild(ctx: CodeCtx, build: PlanBuild): string {
  const main = ctx.paths.find((p) => p.id === build.main)?.order ?? 0;
  const parts = [trimZeros(baseActives(ctx).map((s) => String(bits(build, s.id, s.hasB[5], s.hasB[10]))).join(""))];
  for (const path of pathsByOrder(ctx)) {
    if (!path) {
      parts.push("");
      continue;
    }
    const digits = path.rows.flatMap((row) =>
      row.nodes.map((node) => {
        const rank = Math.min(rankIn(build, node.id), node.maxRank);
        if (node.kind === "skill" && node.skill) {
          const b = node.skillB ?? [];
          return rank > 0 ? String(1 + bits(build, node.skill, b.includes(5), b.includes(10))) : "0";
        }
        return String(rank);
      }),
    );
    parts.push(trimZeros(digits.join("")));
  }
  while (parts.length > 0 && parts[parts.length - 1] === "") parts.pop();
  return `2${ctx.classId.toUpperCase()}${build.level}.${main}${parts.map((p) => `.${p}`).join("")}`;
}

export type Decoded = { ok: true; build: PlanBuild } | { ok: false; error: CodeError };

/** Never throws; a v1 code (or anything not starting with "2" and a letter) gives "old". */
export function decodeBuild(text: unknown, ctx: CodeCtx): Decoded {
  const fail = (error: CodeError): Decoded => ({ ok: false, error });
  if (typeof text !== "string") return fail("empty");
  const s = text.replace(/\s+/g, "").toUpperCase();
  if (s === "") return fail("empty");
  const head = /^2([A-Z]+)(.*)$/.exec(s);
  if (!head) return fail("old");
  if (head[1] !== ctx.classId.toUpperCase()) return fail("class");
  const lv = /^(\d+)(.*)$/.exec(head[2]);
  if (!lv) return fail("level");
  const level = Number(lv[1]);
  if (!Number.isInteger(level) || level < 1 || level > ctx.maxLevel) return fail("level");
  const rest = lv[2];
  if (rest !== "" && rest[0] !== ".") return fail("level");
  const segs = rest === "" ? [] : rest.slice(1).split(".");
  const build: PlanBuild = { level, main: null, nodes: {}, bp: {} };

  const mainSeg = segs[0] ?? "";
  if (mainSeg !== "") {
    if (!/^\d+$/.test(mainSeg)) return fail("main");
    const order = Number(mainSeg);
    if (order !== 0) {
      const path = ctx.paths.find((p) => p.order === order);
      if (!path) return fail("main");
      build.main = path.id;
    }
  }

  const actives = baseActives(ctx);
  const bpSeg = segs[1] ?? "";
  if (bpSeg.length > actives.length) return fail("length");
  for (let i = 0; i < bpSeg.length; i++) {
    if (!/[0-3]/.test(bpSeg[i])) return fail("bp");
    const b = Number(bpSeg[i]);
    const skill = actives[i];
    if ((b & 1 && !skill.hasB[5]) || (b & 2 && !skill.hasB[10])) return fail("bp");
    if (b & 1) build.bp[choiceKey(skill.id, 5)] = "b";
    if (b & 2) build.bp[choiceKey(skill.id, 10)] = "b";
  }

  const byOrder = pathsByOrder(ctx);
  const pathSegs = segs.slice(2);
  for (let k = 0; k < pathSegs.length; k++) {
    const seg = pathSegs[k];
    if (seg === "") continue;
    const path = byOrder[k];
    if (!path) return fail("length");
    const nodes = path.rows.flatMap((row) => row.nodes);
    if (seg.length > nodes.length) return fail("length");
    for (let i = 0; i < seg.length; i++) {
      if (!/\d/.test(seg[i])) return fail("rank");
      const d = Number(seg[i]);
      const node = nodes[i];
      if (node.kind === "skill" && node.skill) {
        if (d > 4) return fail("rank");
        if (d === 0) continue;
        const b = d - 1;
        const allowed = node.skillB ?? [];
        if ((b & 1 && !allowed.includes(5)) || (b & 2 && !allowed.includes(10))) return fail("bp");
        build.nodes[node.id] = 1;
        if (b & 1) build.bp[choiceKey(node.skill, 5)] = "b";
        if (b & 2) build.bp[choiceKey(node.skill, 10)] = "b";
      } else {
        if (d > node.maxRank) return fail("rank");
        if (d > 0) build.nodes[node.id] = d;
      }
    }
  }
  return { ok: true, build };
}

// Texts ---------------------------------------------------------------------------------------------------------------

/** "{n} many" with the placeholders filled. */
export function fill(text: string, args: Record<string, string | number>): string {
  return text.replace(/\{(\w+)\}/g, (whole, key: string) => (key in args ? String(args[key]) : whole));
}

// Island props (built by plannerData in classes.ts, one class, one language) -------------------------------------------

export interface PlannerRank {
  level: number;
  cost: number;
  cooldown: number;
  desc: string;
  variants?: Record<string, { cost: number; cooldown: number; desc: string }>;
}

export interface PlannerSkill extends RuleSkill {
  name: string;
  glyph: string;
  color: string;
  resource: string | null;
  range: number | null;
  elementNote: string | null;
  pathName: string | null;
  ranks: PlannerRank[];
  breakpoints: { rank: number; level: number; a: string; b: string | null }[];
}

export interface PlannerNode extends RuleNode {
  name: string;
  glyph: string;
  modify: { skill: string; at?: number; option?: string } | null;
  /** Own weapon requirement as base type names, or null. */
  weapon: string | null;
  ranks: { desc: string; dipDesc: string | null }[];
}

export interface PlannerPath extends RulePath {
  name: string;
  desc: string;
  role: string;
  roleName: string;
  /** Path weapon as base type names (empty: any weapon of the class). */
  weapon: { main: string[]; offhand: string[] };
  rows: (RuleRow & { nodes: PlannerNode[] })[];
}

export interface PlannerRules extends PathRules {
  pathPointsEvery: number;
  firstRowLevel: number;
  capstoneLevel: number;
}

export interface PlannerData {
  lang: string;
  classId: string;
  classColor: string;
  skills: PlannerSkill[];
  paths: PlannerPath[];
  rules: PlannerRules;
  labels: Record<string, string>;
  scroll: { name: string; href: string | null };
}
