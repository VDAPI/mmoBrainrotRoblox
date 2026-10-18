// Skill planner rules v3 (S148, DESIGN-18 §14, docs/WIKI.md "Planer v3"). Pure functions shared by the class page
// (build time), the SkillPlanner island and the tests; no import of src/data (the data comes as arguments).
// Nothing the game computes is repeated here: skill points and path points per level, rank limits (rankLevels), the
// ladder, descriptions and variants come from skills.json. The rules mirror Logic/SkillPoints.canBuy / apply and
// Logic/Paths.canBuy / canRefund / mainOf check by check (same reason keys, same order); parity is tested against
// vectors computed in Lune (wiki/test-fixtures/planner.json). Build code v3: see encodeBuild.

/** The part of a skill the rules need. */
export interface RuleSkill {
  id: string;
  order: number;
  unlock: number;
  maxLevel: number;
  passive: boolean;
  rankLevels: number[];
  hasB: { 5: boolean; 10: boolean };
  /** DESIGN-18 §4: a pool id or "common" (a direction skill has none). */
  pool?: string;
  /** DESIGN-18 §5: ladder code ("S1"…"U", "C1"…"C4"). */
  role?: string;
  /** Id of the direction that gives the skill (its "skill" node). */
  path?: string;
}

/** The part of a direction node the rules need (a SkillPathNode from skills.json fits). */
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

/** A published direction (a SkillPath from skills.json fits). */
export interface RulePath {
  id: string;
  class: string;
  order: number;
  rows: RuleRow[];
}

/** A weapon pool: its skills in the build-code order (school by the ladder, common, direction skills). */
export interface RulePool {
  id: string;
  skills: string[];
}

export interface PlanRules {
  maxLevel: number;
  skillPointsByLevel: number[];
  pathPointsByLevel: number[];
  capstonesMax: number;
  mainMinPoints: number;
  teamFullPoints: number;
  dipRows: number;
  barSlots: number;
}

/** Everything the rules of one class need. */
export interface PlanCtx {
  classId: string;
  skills: RuleSkill[];
  pools: RulePool[];
  paths: RulePath[];
  rules: PlanRules;
}

export type Option = "a" | "b";

/** One build set, like the game save: ranks per pool, the nodes, path.bp ("<skillId>:5") and a bar per pool. */
export interface PlanBuild {
  level: number;
  ranks: Record<string, Record<string, number>>;
  nodes: Record<string, number>;
  bp: Record<string, Option>;
  bars: Record<string, string[]>;
}

export const COMMON = "common";

/** Reason keys of Logic/SkillPoints.canBuy in the order it checks them. */
export const SKILL_ERRORS = [
  "error.badRequest",
  "skills.error.pool",
  "skills.error.locked",
  "skills.error.limit",
  "skills.error.points",
] as const;
/** Reason keys of Logic/Paths.canBuy in the order it checks them (S138: no main path, one capstone per set). */
export const BUY_ERRORS = [
  "paths.error.unknown",
  "paths.error.maxRank",
  "paths.error.points",
  "paths.error.level",
  "paths.error.need",
  "paths.error.choice",
  "skills.error.capstoneTaken",
  "paths.error.upgrade",
] as const;
/** Reason keys of Logic/Paths.canRefund. */
export const REFUND_ERRORS = ["paths.error.unknown", "paths.error.noRank", "paths.error.needAbove"] as const;

export type SkillError = (typeof SKILL_ERRORS)[number];
export type BuyError = (typeof BUY_ERRORS)[number];
export type RefundError = (typeof REFUND_ERRORS)[number];
export interface Result<E extends string> {
  ok: boolean;
  reason?: E;
}

/** Last part of a reason key ("paths.error.need" -> "need"), for the planner.why.* texts. */
export const reasonCode = (key: string): string => key.slice(key.lastIndexOf(".") + 1);

export const emptyBuild = (level: number): PlanBuild => ({ level, ranks: {}, nodes: {}, bp: {}, bars: {} });

const skillOf = (ctx: PlanCtx, id: string): RuleSkill | undefined => ctx.skills.find((s) => s.id === id);
const poolOf = (ctx: PlanCtx, id: string): RulePool | undefined => ctx.pools.find((p) => p.id === id);
const byLevel = (table: number[], level: number): number => {
  const clamped = Math.min(Math.max(Math.floor(level), 1), table.length);
  return table[clamped - 1] ?? 0;
};

// Ranks (Logic/SkillPoints) ---------------------------------------------------------------------------------------------

/** The highest rank that may be bought at `level` (the number of rankLevels <= level; SkillPoints.cap). */
export function rankAt(skill: { rankLevels: number[] }, level: number): number {
  let rank = 0;
  for (const at of skill.rankLevels) if (level >= at) rank++;
  return rank;
}

/** Character level from which the next rank may be bought, or null at the last one. */
export function nextRankLevel(skill: { rankLevels: number[] }, rank: number): number | null {
  return rank < skill.rankLevels.length ? skill.rankLevels[rank] : null;
}

/** Skill points of one pool at `level` (rules.skillPointsByLevel). */
export const skillPointsAt = (rules: PlanRules, level: number): number => byLevel(rules.skillPointsByLevel, level);
/** Direction (talent) points at `level` (rules.pathPointsByLevel). */
export const pathPointsAt = (rules: PlanRules, level: number): number => byLevel(rules.pathPointsByLevel, level);

/** The raw bought rank as a whole number >= 0 (Paths.boughtIn). */
export function bought(build: PlanBuild, poolId: string, skillId: string): number {
  const v = build.ranks[poolId]?.[skillId];
  return typeof v === "number" && v >= 1 ? Math.floor(Math.min(v, 1e6)) : 0;
}

/** Points spent in a pool (every entry of the pool's ranks, as SkillPoints.spent). */
export function spentIn(build: PlanBuild, poolId: string): number {
  return Object.keys(build.ranks[poolId] ?? {}).reduce((n, id) => n + bought(build, poolId, id), 0);
}

/** Free skill points of a pool (negative when the build has more than the level gives). */
export const freeIn = (ctx: PlanCtx, build: PlanBuild, poolId: string): number =>
  skillPointsAt(ctx.rules, build.level) - spentIn(build, poolId);

/** SkillPools.memberDef: a direction skill is in every pool, a base skill in its own pool or "common". */
export function isMember(ctx: PlanCtx, poolId: string, skill: RuleSkill | undefined): boolean {
  if (!skill || !poolOf(ctx, poolId)) return false;
  if (skill.path !== undefined) return true;
  return skill.pool === COMMON || skill.pool === poolId;
}

interface Found {
  path: RulePath;
  row: number;
  node: RuleNode;
}

/** The node, its direction and its row (1-based). */
export function findNode(paths: RulePath[], nodeId: string): Found | null {
  for (const path of paths) {
    for (const row of path.rows) {
      for (const node of row.nodes) if (node.id === nodeId) return { path, row: row.row, node };
    }
  }
  return null;
}

/** The "skill" node of a direction skill. */
export function skillNode(ctx: PlanCtx, skill: RuleSkill): Found | null {
  const path = ctx.paths.find((p) => p.id === skill.path);
  if (!path) return null;
  for (const row of path.rows) {
    for (const node of row.nodes) if (node.kind === "skill" && node.skill === skill.id) return { path, row: row.row, node };
  }
  return null;
}

/** Paths.pathSkillOpen: the skill node bought and the row's level reached. */
export function pathSkillOpen(ctx: PlanCtx, build: PlanBuild, skill: RuleSkill): boolean {
  const found = skillNode(ctx, skill);
  if (!found || (build.nodes[found.node.id] ?? 0) <= 0) return false;
  return build.level >= found.path.rows[found.row - 1].level;
}

/** Buying `n` ranks (Logic/SkillPoints.canBuy): bad request, pool, locked, limit, points. */
export function canBuySkill(ctx: PlanCtx, build: PlanBuild, poolId: string, skillId: string, n = 1): Result<SkillError> {
  if (!Number.isInteger(n) || n < 1 || n > 1000) return { ok: false, reason: "error.badRequest" };
  if (!poolOf(ctx, poolId)) return { ok: false, reason: "skills.error.pool" };
  const skill = skillOf(ctx, skillId);
  if (!skill) return { ok: false, reason: "error.badRequest" };
  if (!isMember(ctx, poolId, skill)) return { ok: false, reason: "skills.error.pool" };
  if (skill.path !== undefined && !pathSkillOpen(ctx, build, skill)) return { ok: false, reason: "skills.error.locked" };
  if (bought(build, poolId, skillId) + n > rankAt(skill, build.level)) return { ok: false, reason: "skills.error.limit" };
  if (freeIn(ctx, build, poolId) < n) return { ok: false, reason: "skills.error.points" };
  return { ok: true };
}

/** A whole reservation { skillId: +n } in one pool (SkillPoints.apply): sorted ids, each checked on top of the ones
 * before it; all or nothing (the new ranks of the pool on success). */
export function applyPlan(
  ctx: PlanCtx,
  build: PlanBuild,
  poolId: string,
  plan: Record<string, number>,
): Result<SkillError> & { ranks?: Record<string, number> } {
  if (!poolOf(ctx, poolId)) return { ok: false, reason: "skills.error.pool" };
  const ids = Object.keys(plan);
  if (ids.some((id) => !Number.isInteger(plan[id]) || plan[id] < 1 || plan[id] > 1000) || ids.length === 0 || ids.length > 32) {
    return { ok: false, reason: "error.badRequest" };
  }
  ids.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  const ranks: Record<string, number> = { ...(build.ranks[poolId] ?? {}) };
  const work: PlanBuild = { ...build, ranks: { [poolId]: ranks } };
  for (const id of ids) {
    const r = canBuySkill(ctx, work, poolId, id, plan[id]);
    if (!r.ok) return r;
    ranks[id] = bought(work, poolId, id) + plan[id];
  }
  return { ok: true, ranks };
}

/** The working rank (Paths.skillRank): bought in the pool, a member, a direction skill with its node, at most the limit. */
export function rankOf(ctx: PlanCtx, build: PlanBuild, poolId: string, skillId: string): number {
  const skill = skillOf(ctx, skillId);
  if (!skill || !isMember(ctx, poolId, skill)) return 0;
  if (skill.path !== undefined && !pathSkillOpen(ctx, build, skill)) return 0;
  return Math.min(bought(build, poolId, skillId), rankAt(skill, build.level));
}

/** The best rank of a skill in any pool (Paths.bpRank: a breakpoint belongs to the set). */
export const bpRank = (ctx: PlanCtx, build: PlanBuild, skillId: string): number =>
  Math.max(0, ...ctx.pools.map((p) => rankOf(ctx, build, p.id, skillId)));

/** A new build with one bought rank more / less in a pool (no check: call canBuySkill first). A rank refunded to 0
 * leaves the pool's bar. */
export function addSkillRank(build: PlanBuild, poolId: string, skillId: string, delta: 1 | -1): PlanBuild {
  const own = { ...(build.ranks[poolId] ?? {}) };
  const rank = bought(build, poolId, skillId) + delta;
  if (rank > 0) own[skillId] = rank;
  else delete own[skillId];
  const bars = { ...build.bars };
  if (rank <= 0 && bars[poolId]) bars[poolId] = bars[poolId].filter((id) => id !== skillId);
  return { ...build, ranks: { ...build.ranks, [poolId]: own }, bars };
}

// Breakpoints ------------------------------------------------------------------------------------------------------------

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

// Directions (mirror of Logic/Paths) -----------------------------------------------------------------------------------

const rowRanks = (nodes: Record<string, number>, path: RulePath, row: number): number =>
  (path.rows[row - 1]?.nodes ?? []).reduce((n, node) => n + (nodes[node.id] ?? 0), 0);

const ranksBelow = (nodes: Record<string, number>, path: RulePath, row: number): number => {
  let total = 0;
  for (let r = 1; r < row; r++) total += rowRanks(nodes, path, r);
  return total;
};

/** Ranks bought in a direction. */
export const pathPoints = (path: RulePath, nodes: Record<string, number>): number => ranksBelow(nodes, path, path.rows.length + 1);

/** Sum of node ranks (only known nodes with rank > 0, as the game). */
export function pathSpent(paths: RulePath[], build: PlanBuild): number {
  let total = 0;
  for (const [id, rank] of Object.entries(build.nodes)) if (rank > 0 && findNode(paths, id)) total += rank;
  return total;
}

/** Free direction points (negative when the build has more than the level gives). */
export const pathFree = (ctx: PlanCtx, build: PlanBuild): number => pathPointsAt(ctx.rules, build.level) - pathSpent(ctx.paths, build);

const hasCapstone = (nodes: Record<string, number>, path: RulePath): boolean =>
  path.rows.some((row) => row.kind === "capstone" && rowRanks(nodes, path, row.row) > 0);

/** Why a row of a direction is closed (Paths.rowOpen order: level, requirement), null when open. */
export function rowClosed(path: RulePath, build: PlanBuild, row: number): "level" | "need" | null {
  const def = path.rows[row - 1];
  if (build.level < def.level) return "level";
  if (ranksBelow(build.nodes, path, row) < def.required) return "need";
  return null;
}

/** Buying one node rank (Paths.canBuy): unknown, maxRank, points, level, need, choice, capstoneTaken, upgrade. */
export function canBuyNode(ctx: PlanCtx, build: PlanBuild, nodeId: string): Result<BuyError> {
  const found = findNode(ctx.paths, nodeId);
  if (!found) return { ok: false, reason: "paths.error.unknown" };
  if ((build.nodes[nodeId] ?? 0) >= found.node.maxRank) return { ok: false, reason: "paths.error.maxRank" };
  if (pathFree(ctx, build) < 1) return { ok: false, reason: "paths.error.points" };
  const closed = rowClosed(found.path, build, found.row);
  if (closed) return { ok: false, reason: closed === "level" ? "paths.error.level" : "paths.error.need" };
  const row = found.path.rows[found.row - 1];
  if (row.choice && row.nodes.some((other) => other.id !== nodeId && (build.nodes[other.id] ?? 0) > 0)) {
    return { ok: false, reason: "paths.error.choice" };
  }
  if (row.kind === "capstone") {
    const others = ctx.paths.filter((p) => p.id !== found.path.id && hasCapstone(build.nodes, p)).length;
    if (others >= ctx.rules.capstonesMax) return { ok: false, reason: "skills.error.capstoneTaken" };
  }
  if (row.kind === "upgrade" && !hasCapstone(build.nodes, found.path)) return { ok: false, reason: "paths.error.upgrade" };
  return { ok: true };
}

/** Refunding one node rank (Paths.canRefund): every higher row with ranks keeps its requirement, an upgrade its
 * capstone. */
export function canRefundNode(ctx: PlanCtx, build: PlanBuild, nodeId: string): Result<RefundError> {
  const found = findNode(ctx.paths, nodeId);
  if (!found) return { ok: false, reason: "paths.error.unknown" };
  const rank = build.nodes[nodeId] ?? 0;
  if (rank <= 0) return { ok: false, reason: "paths.error.noRank" };
  const nodes = { ...build.nodes, [nodeId]: rank - 1 };
  const path = found.path;
  for (let r = found.row + 1; r <= path.rows.length; r++) {
    const has = rowRanks(nodes, path, r) > 0;
    if (has && ranksBelow(nodes, path, r) < path.rows[r - 1].required) return { ok: false, reason: "paths.error.needAbove" };
    if (has && path.rows[r - 1].kind === "upgrade" && !hasCapstone(nodes, path)) return { ok: false, reason: "paths.error.needAbove" };
  }
  return { ok: true };
}

/** The leading direction (Paths.mainOf): the most ranks, at least mainMinPoints; a tie goes to the lower order. */
export function leadingOf(ctx: PlanCtx, nodes: Record<string, number>): string | null {
  let best: string | null = null;
  let bestRanks = ctx.rules.mainMinPoints - 1;
  for (const path of [...ctx.paths].sort((a, b) => a.order - b.order)) {
    const ranks = pathPoints(path, nodes);
    if (ranks > bestRanks) {
      best = path.id;
      bestRanks = ranks;
    }
  }
  return best;
}

/** The direction whose capstone is bought (the leading one first, Paths.capstoneOf), or null. */
export function capstoneOf(ctx: PlanCtx, nodes: Record<string, number>): string | null {
  const lead = leadingOf(ctx, nodes);
  const with_ = [...ctx.paths].sort((a, b) => a.order - b.order).filter((p) => hasCapstone(nodes, p));
  return with_.find((p) => p.id === lead)?.id ?? with_[0]?.id ?? null;
}

/** A new build with one node rank more / less (no check: call canBuyNode / canRefundNode first). A skill node refunded
 * to 0 takes its skill's ranks from every pool and every bar (Paths.cleanRanks). */
export function addNodeRank(ctx: PlanCtx, build: PlanBuild, nodeId: string, delta: 1 | -1): PlanBuild {
  const nodes = { ...build.nodes };
  const rank = (nodes[nodeId] ?? 0) + delta;
  if (rank > 0) nodes[nodeId] = rank;
  else delete nodes[nodeId];
  let next: PlanBuild = { ...build, nodes };
  const node = findNode(ctx.paths, nodeId)?.node;
  if (rank <= 0 && node?.kind === "skill" && node.skill) {
    for (const pool of ctx.pools) {
      if (bought(next, pool.id, node.skill) > 0) {
        const own = { ...next.ranks[pool.id] };
        delete own[node.skill];
        next = { ...next, ranks: { ...next.ranks, [pool.id]: own } };
      }
      const bar = next.bars[pool.id];
      if (bar?.includes(node.skill)) next = { ...next, bars: { ...next.bars, [pool.id]: bar.filter((id) => id !== node.skill) } };
    }
  }
  return next;
}

/** The ranks a new character of the build's level reaches (Skills.pathAchievable in Lune: directions by order, rows
 * ascending, nodes in row order, each `while rank < target and canBuy`, repeated while anything changes). */
function replay(ctx: PlanCtx, build: PlanBuild): Record<string, number> {
  const probe: PlanBuild = { ...emptyBuild(build.level), nodes: {} };
  const sorted = [...ctx.paths].sort((a, b) => a.order - b.order);
  let changed = true;
  while (changed) {
    changed = false;
    for (const path of sorted) {
      for (const row of path.rows) {
        for (const node of row.nodes) {
          const target = build.nodes[node.id] ?? 0;
          while ((probe.nodes[node.id] ?? 0) < target && canBuyNode(ctx, probe, node.id).ok) {
            probe.nodes[node.id] = (probe.nodes[node.id] ?? 0) + 1;
            changed = true;
          }
        }
      }
    }
  }
  return probe.nodes;
}

/** Whether a new character of the build's level can reach the build's nodes (Skills.pathAchievable). */
export function achievable(ctx: PlanCtx, build: PlanBuild): boolean {
  const have = replay(ctx, build);
  return Object.entries(build.nodes).every(([id, target]) => target <= 0 || (have[id] ?? 0) === target);
}

export interface Validation {
  ok: boolean;
  /** Pools whose ranks cost more than the level gives: pool id -> points over. */
  poolsOver: Record<string, number>;
  /** "<pool>:<skill>" of ranks above the limit of the level, or of a direction skill without its node. */
  ranksOver: string[];
  /** Direction points above what the level gives. */
  nodesOver: number;
  /** Nodes with ranks the replay does not reach on this level. */
  unreached: string[];
}

export function validate(ctx: PlanCtx, build: PlanBuild): Validation {
  const poolsOver: Record<string, number> = {};
  const ranksOver: string[] = [];
  for (const pool of ctx.pools) {
    const over = -freeIn(ctx, build, pool.id);
    if (over > 0) poolsOver[pool.id] = over;
    for (const id of Object.keys(build.ranks[pool.id] ?? {})) {
      if (bought(build, pool.id, id) > rankOf(ctx, build, pool.id, id)) ranksOver.push(`${pool.id}:${id}`);
    }
  }
  const have = replay(ctx, build);
  const unreached = Object.entries(build.nodes)
    .filter(([id, target]) => target > 0 && (have[id] ?? 0) !== target)
    .map(([id]) => id);
  const nodesOver = Math.max(0, -pathFree(ctx, build));
  return {
    ok: Object.keys(poolsOver).length === 0 && ranksOver.length === 0 && nodesOver === 0 && unreached.length === 0,
    poolsOver,
    ranksOver,
    nodesOver,
    unreached,
  };
}

// Bars --------------------------------------------------------------------------------------------------------------------

/** Paths.canPutOnBar: an active skill with rank > 0 in the pool. */
export function barAllowed(ctx: PlanCtx, build: PlanBuild, poolId: string, skillId: string): boolean {
  const skill = skillOf(ctx, skillId);
  return !!skill && !skill.passive && rankOf(ctx, build, poolId, skillId) > 0;
}

/** The bar of a pool as the game keeps it (Paths.validBar): allowed skills, no repeats, at most barSlots. */
export function barOf(ctx: PlanCtx, build: PlanBuild, poolId: string): string[] {
  const out: string[] = [];
  for (const id of build.bars[poolId] ?? []) {
    if (out.length < ctx.rules.barSlots && !out.includes(id) && barAllowed(ctx, build, poolId, id)) out.push(id);
  }
  return out;
}

/** A new build with the skill put on / taken off the pool's bar (a full bar refuses: null). */
export function toggleBar(ctx: PlanCtx, build: PlanBuild, poolId: string, skillId: string): PlanBuild | null {
  const bar = barOf(ctx, build, poolId);
  if (bar.includes(skillId)) return { ...build, bars: { ...build.bars, [poolId]: bar.filter((id) => id !== skillId) } };
  if (!barAllowed(ctx, build, poolId, skillId) || bar.length >= ctx.rules.barSlots) return null;
  return { ...build, bars: { ...build.bars, [poolId]: [...bar, skillId] } };
}

// View models (the island only draws them) -------------------------------------------------------------------------------

/** Ladder columns of the pool tree (PathView.COLUMNS): role letter of the ladder code; "C" = the class's common skills. */
export const COLUMNS = ["S", "A", "K", "O", "P", "U", "C"] as const;
export type Column = (typeof COLUMNS)[number];

export const columnOf = (role: string | undefined): Column | null => {
  const letter = (role ?? "")[0] as Column;
  return COLUMNS.includes(letter) ? letter : null;
};

export interface TreeRow {
  level: number;
  cells: Partial<Record<Column, string>>;
}

/** The pool tree (PathView.layout): one row per ladder level (school and common rungs), the skill of each role in its
 * column; `directions` = the direction skills of the pool, `others` = base skills without a ladder role. */
export function poolTree(ctx: PlanCtx, poolId: string): { rows: TreeRow[]; directions: string[]; others: string[] } {
  const pool = poolOf(ctx, poolId);
  const rows = new Map<number, TreeRow>();
  const directions: string[] = [];
  const others: string[] = [];
  for (const id of pool?.skills ?? []) {
    const skill = skillOf(ctx, id);
    if (!skill) continue;
    if (skill.path !== undefined) {
      directions.push(id);
      continue;
    }
    const column = columnOf(skill.role);
    if (!column) {
      others.push(id);
      continue;
    }
    const row = rows.get(skill.unlock) ?? { level: skill.unlock, cells: {} };
    row.cells[column] = id;
    rows.set(skill.unlock, row);
  }
  return { rows: [...rows.values()].sort((a, b) => a.level - b.level), directions, others };
}

export type TileState = "locked" | "available" | "partial" | "max";

export interface TileView {
  id: string;
  rank: number;
  cap: number;
  max: number;
  state: TileState;
  /** Level that opens rank 1 while it is locked. */
  lockLevel: number | null;
  buy: Result<SkillError>;
  refund: boolean;
  invalid: boolean;
  onBar: number | null;
  /** Breakpoint marks of ranks 5 and 10: reached, chosen option. */
  bp: { rank: number; reached: boolean; choice: Option }[];
}

/** One tile of the pool tree (PathView.poolView). */
export function tileView(ctx: PlanCtx, build: PlanBuild, poolId: string, skill: RuleSkill): TileView {
  const has = bought(build, poolId, skill.id);
  const rank = rankOf(ctx, build, poolId, skill.id);
  const cap = rankAt(skill, build.level);
  const buy = canBuySkill(ctx, build, poolId, skill.id);
  // locked = no rank to buy at this level (the level) or a direction skill without its node; out of points it stays
  // "available" (the game's tile keeps its picture)
  const closed = cap === 0 || buy.reason === "skills.error.locked" || buy.reason === "skills.error.pool";
  const state: TileState = rank >= skill.maxLevel ? "max" : rank > 0 ? "partial" : closed ? "locked" : "available";
  const bar = barOf(ctx, build, poolId).indexOf(skill.id);
  const best = bpRank(ctx, build, skill.id);
  return {
    id: skill.id,
    rank,
    cap,
    max: skill.maxLevel,
    state,
    lockLevel: cap === 0 ? (skill.rankLevels[0] ?? skill.unlock) : null,
    buy,
    refund: has > 0,
    invalid: has > rank,
    onBar: bar >= 0 ? bar + 1 : null,
    bp: skill.passive
      ? []
      : ([5, 10] as const).filter((r) => r <= skill.maxLevel).map((r) => ({ rank: r, reached: best >= r, choice: choiceAt(build, skill.id, r) })),
  };
}

export interface NodeView {
  id: string;
  rank: number;
  max: number;
  state: TileState;
  invalid: boolean;
  buy: Result<BuyError>;
  refund: Result<RefundError>;
  /** A team node of rows 1..dipRows working at its dipScale (fewer than teamFullPoints ranks in the direction). */
  dip: boolean;
}

export interface RowView {
  row: number;
  level: number;
  required: number;
  have: number;
  open: boolean;
  reason: "level" | "need" | null;
  nodes: NodeView[];
}

export interface PathView {
  points: number;
  leading: boolean;
  capstone: boolean;
  rows: RowView[];
}

/** A direction: rows with their requirement and why they are closed, nodes with state, purchase / refund and the
 * reduced strength of team nodes (Paths.nodeScale). */
export function pathView(ctx: PlanCtx, path: RulePath, build: PlanBuild, unreached?: Set<string>): PathView {
  const missing = unreached ?? new Set(validate(ctx, build).unreached);
  const points = pathPoints(path, build.nodes);
  return {
    points,
    leading: leadingOf(ctx, build.nodes) === path.id,
    capstone: hasCapstone(build.nodes, path),
    rows: path.rows.map((row) => {
      const reason = rowClosed(path, build, row.row);
      return {
        row: row.row,
        level: row.level,
        required: row.required,
        have: ranksBelow(build.nodes, path, row.row),
        open: reason === null,
        reason,
        nodes: row.nodes.map((node) => {
          const rank = build.nodes[node.id] ?? 0;
          const buy = canBuyNode(ctx, build, node.id);
          const state: TileState = rank >= node.maxRank ? "max" : rank > 0 ? "partial" : buy.ok || buy.reason === "paths.error.points" ? "available" : "locked";
          return {
            id: node.id,
            rank,
            max: node.maxRank,
            state,
            invalid: rank > 0 && missing.has(node.id),
            buy,
            refund: canRefundNode(ctx, build, node.id),
            dip: node.dipScale !== undefined && row.row <= ctx.rules.dipRows && points < ctx.rules.teamFullPoints,
          };
        }),
      };
    }),
  };
}

// Build code v3 ----------------------------------------------------------------------------------------------------------
//
//   3<CLASS><level>.<POOL>:<ranks>[:<bar>][.<POOL>:<ranks>[:<bar>]…].<talents>.<breakpoints>
//
// "3" = version; <CLASS> = class id in capitals; one segment per pool with any rank or bar (pools in data order):
// <POOL> = pool id in capitals, <ranks> = one character per skill of the pool in skills.json `pools[].skills` order
// (the ladder, then the common skills, then the direction skills by direction order and rows), "0"-"9" or "A" = 10,
// trailing zeros cut; <bar> = the bar slots in order, each the base-36 index of the skill in the same list.
// <talents> = one group per direction in `order` (groups joined by "-"), one digit per node (rows ascending, nodes in
// row order) = its rank, trailing zeros of every group and empty groups at the end cut. <breakpoints> = one character
// 0-3 per active skill of the class (pools in data order, each pool's skills in code order, every skill once; bit 1 = B
// at rank 5, bit 2 = B at rank 10), trailing zeros cut. Empty trailing segments are left out ("3MAGE34",
// "3MAGE34.FIRE:3211", "3MAGE60.FIRE:A5.21-1.1"). Letter case and spaces do not matter. The code does not check the
// game rules (validate does). A v2 code ("2MAGE34…", planner v2, S82) or a v1 code ("MAGE34-…") is "old"; any other
// text without the "3<CLASS>" head is "format".

export type CodeError = "empty" | "old" | "format" | "class" | "level" | "pool" | "rank" | "bar" | "talent" | "bp" | "length";

const DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const trimZeros = (segment: string): string => segment.replace(/0+$/, "");

const pathsByOrder = (ctx: PlanCtx): (RulePath | undefined)[] => {
  const top = Math.max(0, ...ctx.paths.map((p) => p.order));
  return Array.from({ length: top }, (_, i) => ctx.paths.find((p) => p.order === i + 1));
};

/** Active skills of the class in the breakpoint order of the code. */
export function bpOrder(ctx: PlanCtx): RuleSkill[] {
  const out: RuleSkill[] = [];
  for (const pool of ctx.pools) {
    for (const id of pool.skills) {
      const skill = skillOf(ctx, id);
      if (skill && !skill.passive && !out.includes(skill)) out.push(skill);
    }
  }
  return out;
}

function bits(build: PlanBuild, skill: RuleSkill): number {
  return (skill.hasB[5] && choiceAt(build, skill.id, 5) === "b" ? 1 : 0) | (skill.hasB[10] && choiceAt(build, skill.id, 10) === "b" ? 2 : 0);
}

export function encodeBuild(ctx: PlanCtx, build: PlanBuild): string {
  const parts: string[] = [];
  for (const pool of ctx.pools) {
    const ranks = trimZeros(pool.skills.map((id) => DIGITS[Math.min(bought(build, pool.id, id), 35)]).join(""));
    const bar = (build.bars[pool.id] ?? [])
      .map((id) => pool.skills.indexOf(id))
      .filter((i) => i >= 0)
      .map((i) => DIGITS[i])
      .join("");
    if (ranks === "" && bar === "") continue;
    parts.push(`${pool.id.toUpperCase()}:${ranks}${bar ? `:${bar}` : ""}`);
  }
  const groups = pathsByOrder(ctx).map((path) =>
    path ? trimZeros(path.rows.flatMap((row) => row.nodes.map((n) => String(Math.min(build.nodes[n.id] ?? 0, n.maxRank)))).join("")) : "",
  );
  while (groups.length > 0 && groups[groups.length - 1] === "") groups.pop();
  const tail = [groups.join("-"), trimZeros(bpOrder(ctx).map((s) => String(bits(build, s))).join(""))];
  while (tail.length > 0 && tail[tail.length - 1] === "") tail.pop();
  return `3${ctx.classId.toUpperCase()}${build.level}${[...parts, ...tail].map((p) => `.${p}`).join("")}`;
}

export type Decoded = { ok: true; build: PlanBuild } | { ok: false; error: CodeError };

/** Never throws; a v2 code ("2MAGE34…") or a v1 code ("MAGE34-…") gives "old", other text without "3<CLASS>" "format". */
export function decodeBuild(text: unknown, ctx: PlanCtx): Decoded {
  const fail = (error: CodeError): Decoded => ({ ok: false, error });
  if (typeof text !== "string") return fail("empty");
  const s = text.replace(/\s+/g, "").toUpperCase();
  if (s === "") return fail("empty");
  const head = /^3([A-Z]+)(.*)$/.exec(s);
  if (!head) return fail(/^2[A-Z]+\d/.test(s) || /^[A-Z]+\d+-/.test(s) ? "old" : "format");
  if (head[1] !== ctx.classId.toUpperCase()) return fail("class");
  const lv = /^(\d+)(.*)$/.exec(head[2]);
  if (!lv) return fail("level");
  const level = Number(lv[1]);
  if (!Number.isInteger(level) || level < 1 || level > ctx.rules.maxLevel) return fail("level");
  const rest = lv[2];
  if (rest !== "" && rest[0] !== ".") return fail("level");
  const segs = rest === "" ? [] : rest.slice(1).split(".");
  const build = emptyBuild(level);

  let i = 0;
  for (; i < segs.length && segs[i].includes(":"); i++) {
    const [poolCode, ranks, bar, extra] = segs[i].split(":");
    const pool = ctx.pools.find((p) => p.id.toUpperCase() === poolCode);
    if (!pool || build.ranks[pool.id] || extra !== undefined) return fail("pool");
    if (ranks.length > pool.skills.length) return fail("length");
    const own: Record<string, number> = {};
    for (let k = 0; k < ranks.length; k++) {
      const n = DIGITS.indexOf(ranks[k]);
      const skill = skillOf(ctx, pool.skills[k]);
      if (n < 0 || !skill || n > skill.maxLevel) return fail("rank");
      if (n > 0) own[skill.id] = n;
    }
    build.ranks[pool.id] = own;
    if (bar !== undefined && bar !== "") {
      if (bar.length > ctx.rules.barSlots) return fail("bar");
      const list: string[] = [];
      for (const ch of bar) {
        const id = pool.skills[DIGITS.indexOf(ch)];
        if (id === undefined || list.includes(id) || skillOf(ctx, id)?.passive) return fail("bar");
        list.push(id);
      }
      build.bars[pool.id] = list;
    }
  }
  const tail = segs.slice(i);
  if (tail.length > 2) return fail("length");
  if (tail.some((t) => t.includes(":"))) return fail("pool");

  const talents = tail[0] ?? "";
  if (talents !== "") {
    const byOrder = pathsByOrder(ctx);
    const groups = talents.split("-");
    if (groups.length > byOrder.length) return fail("length");
    for (let g = 0; g < groups.length; g++) {
      const seg = groups[g];
      if (seg === "") continue;
      const path = byOrder[g];
      if (!path) return fail("length");
      const nodes = path.rows.flatMap((row) => row.nodes);
      if (seg.length > nodes.length) return fail("length");
      for (let k = 0; k < seg.length; k++) {
        if (!/\d/.test(seg[k])) return fail("talent");
        const d = Number(seg[k]);
        if (d > nodes[k].maxRank) return fail("talent");
        if (d > 0) build.nodes[nodes[k].id] = d;
      }
    }
  }

  const bp = tail[1] ?? "";
  const actives = bpOrder(ctx);
  if (bp.length > actives.length) return fail("length");
  for (let k = 0; k < bp.length; k++) {
    if (!/[0-3]/.test(bp[k])) return fail("bp");
    const b = Number(bp[k]);
    const skill = actives[k];
    if ((b & 1 && !skill.hasB[5]) || (b & 2 && !skill.hasB[10])) return fail("bp");
    if (b & 1) build.bp[choiceKey(skill.id, 5)] = "b";
    if (b & 2) build.bp[choiceKey(skill.id, 10)] = "b";
  }
  // empty pools are not part of the build (the code leaves them out)
  for (const [id, own] of Object.entries(build.ranks)) if (Object.keys(own).length === 0) delete build.ranks[id];
  return { ok: true, build };
}

/** The canonical build (what decode(encode(build)) gives): no empty pools, bars as the code keeps them. */
export function canonical(ctx: PlanCtx, build: PlanBuild): PlanBuild {
  const r = decodeBuild(encodeBuild(ctx, build), ctx);
  return r.ok ? r.build : build;
}

// Texts ------------------------------------------------------------------------------------------------------------------

/** "{n} many" with the placeholders filled. */
export function fill(text: string, args: Record<string, string | number>): string {
  return text.replace(/\{(\w+)\}/g, (whole, key: string) => (key in args ? String(args[key]) : whole));
}

// Island props (built by plannerData in classes.ts, one class, one language) -----------------------------------------------

export interface PlannerRank {
  cost: number;
  cooldown: number;
  desc: string;
  variants?: Record<string, { cost: number; cooldown: number; desc: string }>;
}

export interface PlannerSkill extends RuleSkill {
  name: string;
  short: string;
  glyph: string;
  /** WIKI-GRAFIKA: base URL of the owner's skill picture (files -64 / -128), or null for the glyph. */
  pic: string | null;
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
  rows: (RuleRow & { nodes: PlannerNode[] })[];
}

export interface PlannerPool extends RulePool {
  name: string;
  glyph: string;
  /** Weapon base type names that select the pool. */
  weapons: string[];
  element: string | null;
  identity: string;
}

export interface PlannerRules extends PlanRules {
  pathPointsEvery: number;
  freeRespecLevel: number;
}

export interface PlannerData {
  lang: string;
  classId: string;
  classColor: string;
  skills: PlannerSkill[];
  pools: PlannerPool[];
  defaultPool: string;
  paths: PlannerPath[];
  rules: PlannerRules;
  labels: Record<string, string>;
  scroll: { name: string; href: string | null };
}

/** The rule context of the island's props. */
export const planCtx = (data: Pick<PlannerData, "classId" | "skills" | "pools" | "paths" | "rules">): PlanCtx => ({
  classId: data.classId,
  skills: data.skills,
  pools: data.pools,
  paths: data.paths,
  rules: data.rules,
});
