// Skill planner v3 (S148): parity with Logic/SkillPoints and Logic/Paths (vectors computed in Lune, written to
// wiki/test-fixtures/planner.json: the test paths of tests/fixtures/paths.luau, the published directions of the game and
// skill-point states and reservations on the game data), view models and build code v3.
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import type { SkillPath } from "../data/types";
import { classes as classList, planCtxOf, ruleSkill } from "./classes";
import { load } from "./data";
import {
  BUY_ERRORS,
  REFUND_ERRORS,
  SKILL_ERRORS,
  achievable,
  addNodeRank,
  addSkillRank,
  applyPlan,
  barOf,
  bought,
  bpOrder,
  canBuyNode,
  canBuySkill,
  canRefundNode,
  canonical,
  decodeBuild,
  emptyBuild,
  encodeBuild,
  freeIn,
  leadingOf,
  pathFree,
  pathView,
  poolTree,
  rankAt,
  rankOf,
  tileView,
  toggleBar,
  validate,
  variantKey,
  type PlanBuild,
  type PlanCtx,
} from "./skills";

interface PathState {
  class: string;
  level: number;
  nodes: Record<string, number>;
  free: number;
  leading?: string;
  results: { node: string; ok: boolean; reason?: string; refund: boolean; refundReason?: string }[];
}
interface PathVectors {
  states: PathState[];
  builds: { class: string; level: number; nodes: Record<string, number>; achievable: boolean }[];
}
interface PointState {
  class: string;
  level: number;
  pool: string;
  ranks: Record<string, Record<string, number>>;
  nodes: Record<string, number>;
  free: number;
  results: { skill: string; ok: boolean; reason?: string }[];
}
interface PointPlan {
  class: string;
  level: number;
  pool: string;
  ranks: Record<string, Record<string, number>>;
  nodes: Record<string, number>;
  plan: Record<string, number>;
  ok: boolean;
  reason?: string;
}
interface Fixture {
  paths: SkillPath[];
  vectors: PathVectors;
  game: PathVectors;
  skills: { states: PointState[]; plans: PointPlan[] };
}

const file = load("skills");
const fixture = JSON.parse(readFileSync("test-fixtures/planner.json", "utf8")) as Fixture;
const classIds = classList().map((c) => c.id);
const ctxOf = new Map<string, PlanCtx>(classIds.map((id) => [id, planCtxOf(id)]));
const rules = ctxOf.get(classIds[0])!.rules;

// Deterministic pseudo-random numbers (xorshift).
function rng(seed: number): (n: number) => number {
  let x = seed;
  return (n: number): number => {
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    return Math.abs(x) % n;
  };
}

const plan = (level: number, nodes: Record<string, number> = {}, ranks: PlanBuild["ranks"] = {}, bp: PlanBuild["bp"] = {}, bars: PlanBuild["bars"] = {}): PlanBuild => ({
  level,
  ranks,
  nodes,
  bp,
  bars,
});

/** canBuy / canRefund / free / leading of every state and achievable of every build; the reasons seen. */
function pathParity(ctxFor: (classId: string) => PlanCtx, vectors: PathVectors): { buy: Set<string>; refund: Set<string>; reached: Set<boolean>; leading: Set<string> } {
  const buy = new Set<string>();
  const refund = new Set<string>();
  const leading = new Set<string>();
  for (const state of vectors.states) {
    const ctx = ctxFor(state.class);
    const build = plan(state.level, { ...state.nodes });
    expect(pathFree(ctx, build), `free at ${state.level}`).toBe(state.free);
    expect(leadingOf(ctx, build.nodes), `leading ${JSON.stringify(state.nodes)}`).toBe(state.leading ?? null);
    leading.add(state.leading ?? "-");
    for (const r of state.results) {
      const b = canBuyNode(ctx, build, r.node);
      const f = canRefundNode(ctx, build, r.node);
      const where = `${state.class} lv ${state.level} ${r.node}`;
      expect({ ok: b.ok, reason: b.reason ?? null }, where).toEqual({ ok: r.ok, reason: r.reason ?? null });
      expect({ ok: f.ok, reason: f.reason ?? null }, where).toEqual({ ok: r.refund, reason: r.refundReason ?? null });
      buy.add(r.reason ?? "ok");
      refund.add(r.refundReason ?? "ok");
    }
  }
  const reached = new Set<boolean>();
  for (const b of vectors.builds) {
    const ctx = ctxFor(b.class);
    expect(achievable(ctx, plan(b.level, { ...b.nodes })), `${b.class} lv ${b.level} ${JSON.stringify(b.nodes)}`).toBe(b.achievable);
    reached.add(b.achievable);
  }
  return { buy, refund, reached, leading };
}

describe("direction rules on the test paths (wiki/test-fixtures/planner.json)", () => {
  const paths = fixture.paths;
  const ctx: PlanCtx = { classId: "Mage", skills: [], pools: [], paths, rules };
  const storm = paths.find((p) => p.id === "fxStorm")!;

  it("canBuy, canRefund, free, mainOf and achievable match Logic/Paths, with every reason key", () => {
    const seen = pathParity((classId) => ({ ...ctx, classId, paths: paths.filter((p) => p.class === classId) }), fixture.vectors);
    expect([...seen.buy].sort()).toEqual([...BUY_ERRORS, "ok"].sort());
    expect([...seen.refund].sort()).toEqual([...REFUND_ERRORS, "ok"].sort());
    expect(seen.reached).toEqual(new Set([true, false]));
    expect(seen.leading.size).toBeGreaterThan(1);
  });

  it("pathView gives the reasons of closed rows, choice rows and the reduced strength below teamFullPoints", () => {
    expect(pathView(ctx, storm, plan(14)).rows[1].reason).toBe("level");
    const row1 = Object.fromEntries(storm.rows[0].nodes.map((n) => [n.id, n.maxRank]));
    const choiceRow = storm.rows.find((r) => r.choice)!;
    let nodes: Record<string, number> = { ...row1 };
    for (const r of storm.rows.slice(1, choiceRow.row - 1)) for (const n of r.nodes) nodes[n.id] = n.maxRank;
    nodes = { ...nodes, [choiceRow.nodes[0].id]: 1 };
    const view = pathView(ctx, storm, plan(rules.maxLevel, nodes)).rows[choiceRow.row - 1];
    expect(view.open).toBe(true);
    expect(view.nodes[1].buy).toEqual({ ok: false, reason: "paths.error.choice" });
    const dipNode = paths.flatMap((p) => p.rows.slice(0, rules.dipRows).flatMap((r) => r.nodes)).find((n) => n.dipScale !== undefined);
    if (dipNode) {
      const owner = paths.find((p) => p.rows.some((r) => r.nodes.some((n) => n.id === dipNode.id)))!;
      const low = pathView(ctx, owner, plan(40)).rows.flatMap((r) => r.nodes).find((n) => n.id === dipNode.id)!;
      expect(low.dip).toBe(true);
    }
  });

  it("an unreachable node is invalid and validate counts talent points over the level", () => {
    const build = plan(10, { fxStorm_focus: 3, fxStorm_beacon: 1 });
    expect(pathView(ctx, storm, build).rows[1].nodes[0].invalid).toBe(true);
    expect(validate(ctx, build).unreached).toEqual(["fxStorm_beacon"]);
    expect(validate(ctx, plan(2, { fxStorm_focus: 3 })).nodesOver).toBe(2);
  });
});

describe("planner v3 on the game data", () => {
  const ctxFor = (classId: string): PlanCtx => ctxOf.get(classId)!;

  it("matches Logic/Paths on the published directions of the game", () => {
    const seen = pathParity(ctxFor, fixture.game);
    expect(seen.buy.has("ok") && seen.buy.has("paths.error.level")).toBe(true);
    expect(seen.leading.size).toBeGreaterThan(1);
  });

  it("matches SkillPoints.canBuy and free in every state, with every reason key", () => {
    const seen = new Set<string>();
    for (const state of fixture.skills.states) {
      const ctx = ctxFor(state.class);
      const build = plan(state.level, { ...state.nodes }, structuredClone(state.ranks));
      expect(freeIn(ctx, build, state.pool), `${state.class} ${state.pool} lv ${state.level}`).toBe(state.free);
      for (const r of state.results) {
        const got = canBuySkill(ctx, build, state.pool, r.skill);
        expect({ ok: got.ok, reason: got.reason ?? null }, `${state.class} ${state.pool} lv ${state.level} ${r.skill}`).toEqual({ ok: r.ok, reason: r.reason ?? null });
        seen.add(r.reason ?? "ok");
      }
    }
    expect([...seen].sort()).toEqual([...SKILL_ERRORS, "ok"].sort());
  });

  it("matches SkillPoints.apply on every reservation", () => {
    const seen = new Set<string>();
    for (const p of fixture.skills.plans) {
      const ctx = ctxFor(p.class);
      const got = applyPlan(ctx, plan(p.level, { ...p.nodes }, structuredClone(p.ranks)), p.pool, p.plan);
      expect({ ok: got.ok, reason: got.reason ?? null }, `${p.class} ${p.pool} lv ${p.level} ${JSON.stringify(p.plan)}`).toEqual({ ok: p.ok, reason: p.reason ?? null });
      seen.add(p.reason ?? "ok");
    }
    expect(seen.has("ok") && seen.size > 2).toBe(true);
  });

  it("rankAt inverts rankLevels and rank variants are where a skill has option B", () => {
    for (const s of file.skills) {
      expect(s.rankLevels.length).toBe(s.maxLevel);
      for (let r = 1; r <= s.maxLevel; r++) {
        expect(rankAt(s, s.rankLevels[r - 1])).toBe(r);
        expect(rankAt(s, s.rankLevels[r - 1] - 1)).toBe(r - 1);
      }
      const rule = ruleSkill(s);
      s.ranks.forEach((rank, i) => {
        const r = i + 1;
        const want = [r >= 5 && rule.hasB[5] ? "ba" : null, r >= 10 && rule.hasB[10] ? "ab" : null, r >= 10 && rule.hasB[5] && rule.hasB[10] ? "bb" : null]
          .filter(Boolean)
          .sort();
        expect(Object.keys(rank.variants ?? {}).sort(), `${s.id} ${r}`).toEqual(want);
      });
      const b = plan(100, {}, {}, { [`${s.id}:5`]: "b" });
      expect(variantKey(b, s, 4)).toBe("aa");
      expect(variantKey(b, s, 5)).toBe("ba");
    }
  });

  it("budget per pool, the rank limit of the level and the bar of 8", () => {
    for (const classId of classIds) {
      const ctx = ctxFor(classId);
      const [first, second] = ctx.pools;
      const s1 = ctx.skills.find((s) => s.pool === first.id && s.role === "S1")!;
      // level 1: one rank of S1, never two (the limit), the second pool keeps its own points
      let build = emptyBuild(1);
      expect(canBuySkill(ctx, build, first.id, s1.id).ok).toBe(true);
      build = addSkillRank(build, first.id, s1.id, 1);
      expect(canBuySkill(ctx, build, first.id, s1.id)).toEqual({ ok: false, reason: "skills.error.limit" });
      if (second) expect(freeIn(ctx, build, second.id)).toBe(freeIn(ctx, emptyBuild(1), second.id));
      // a school skill of another pool is not in this pool
      if (second) {
        const other = ctx.skills.find((s) => s.pool === second.id)!;
        expect(canBuySkill(ctx, build, first.id, other.id)).toEqual({ ok: false, reason: "skills.error.pool" });
      }
      // spend every point at level 20 in tree order: nothing more to buy, free = 0 or every limit reached
      let full = emptyBuild(20);
      for (const id of first.skills) while (canBuySkill(ctx, full, first.id, id).ok) full = addSkillRank(full, first.id, id, 1);
      expect(first.skills.every((id) => !canBuySkill(ctx, full, first.id, id).ok)).toBe(true);
      expect(freeIn(ctx, full, first.id)).toBeGreaterThanOrEqual(0);
      // the bar: actives with a rank, at most barSlots, a full bar refuses
      let bar = full;
      for (const id of first.skills) bar = toggleBar(ctx, bar, first.id, id) ?? bar;
      const kept = barOf(ctx, bar, first.id);
      expect(kept.length).toBeLessThanOrEqual(ctx.rules.barSlots);
      expect(kept.every((id) => rankOf(ctx, bar, first.id, id) > 0 && !ctx.skills.find((s) => s.id === id)!.passive)).toBe(true);
      // a lower level puts ranks over the limit and points over the budget
      const low = { ...full, level: 9 };
      const v = validate(ctx, low);
      expect(v.ok).toBe(false);
      expect(Object.keys(v.poolsOver)).toContain(first.id);
      // a base skill bought over the limit of the level is invalid, and S1 (bought first at level 20) is one
      const base = first.skills.map((id) => ctx.skills.find((s) => s.id === id)!).filter((s) => s.path === undefined);
      for (const s of base) expect(tileView(ctx, low, first.id, s).invalid, s.id).toBe(bought(low, first.id, s.id) > rankAt(s, 9));
      expect(tileView(ctx, low, first.id, s1).invalid).toBe(true);
    }
  });

  it("one capstone per set, the upgrade only with its capstone, a refunded skill node takes its ranks", () => {
    for (const classId of classIds) {
      const ctx = ctxFor(classId);
      if (ctx.paths.length < 2) continue;
      const [p1, p2] = ctx.paths;
      const cap = p1.rows.findIndex((r) => r.kind === "capstone") + 1;
      // rows below the capstone with exactly its requirement (a choice row: its first node), as the Lune vectors
      const minimal = (nodes: Record<string, number>, path: (typeof ctx.paths)[number]): void => {
        let left = path.rows[cap - 1].required;
        for (const row of path.rows.slice(0, cap - 1)) {
          for (const n of row.choice ? row.nodes.slice(0, 1) : row.nodes) {
            const add = Math.min(n.maxRank, left);
            if (add > 0) nodes[n.id] = add;
            left -= add;
          }
        }
      };
      const nodes: Record<string, number> = {};
      minimal(nodes, p1);
      minimal(nodes, p2);
      const build = plan(rules.maxLevel, nodes);
      const cap1 = p1.rows[cap - 1].nodes[0].id;
      const cap2 = p2.rows[cap - 1].nodes[0].id;
      expect(canBuyNode(ctx, build, cap1)).toEqual({ ok: true });
      const one = addNodeRank(ctx, build, cap1, 1);
      expect(canBuyNode(ctx, one, cap2)).toEqual({ ok: false, reason: "skills.error.capstoneTaken" });
      const up1 = p1.rows.find((r) => r.kind === "upgrade")?.nodes[0].id;
      const up2 = p2.rows.find((r) => r.kind === "upgrade")?.nodes[0].id;
      if (up2) expect(canBuyNode(ctx, one, up2).reason).not.toBe(undefined);
      if (up1) expect(canBuyNode(ctx, build, up1).ok).toBe(false);
      // the upgrade row open (level, requirement) without its capstone: refused for the upgrade rule
      if (up2) {
        const below: Record<string, number> = {};
        for (const row of p2.rows) {
          if (row.kind === "capstone" || row.kind === "upgrade") continue;
          for (const n of row.choice ? row.nodes.slice(0, 1) : row.nodes) below[n.id] = n.maxRank;
        }
        expect(canBuyNode(ctx, plan(rules.maxLevel, below), up2)).toEqual({ ok: false, reason: "paths.error.upgrade" });
      }
      // a skill node: buy its skill in a pool, refund the node, the ranks go
      const skillNode = p1.rows.flatMap((r) => r.nodes).find((n) => n.kind === "skill" && n.skill);
      if (skillNode?.skill) {
        const pool = ctx.pools[0].id;
        let b = plan(rules.maxLevel, { ...nodes, [skillNode.id]: 1 });
        expect(canBuySkill(ctx, b, pool, skillNode.skill).ok).toBe(true);
        b = addSkillRank(b, pool, skillNode.skill, 1);
        expect(rankOf(ctx, b, pool, skillNode.skill)).toBe(1);
        expect(addNodeRank(ctx, b, skillNode.id, -1).ranks[pool][skillNode.skill]).toBeUndefined();
        const without = { ...nodes };
        delete without[skillNode.id];
        expect(canBuySkill(ctx, plan(rules.maxLevel, without), pool, skillNode.skill)).toEqual({ ok: false, reason: "skills.error.locked" });
      }
    }
  });

  it("the pool tree puts every school skill on its ladder row and column", () => {
    const ladder = new Map(file.rules.ladder.map((r) => [r.code, r.level]));
    for (const classId of classIds) {
      const ctx = ctxFor(classId);
      for (const pool of ctx.pools) {
        const tree = poolTree(ctx, pool.id);
        expect(tree.others).toEqual([]);
        for (const row of tree.rows) {
          for (const id of Object.values(row.cells)) {
            const s = ctx.skills.find((x) => x.id === id)!;
            expect(ladder.get(s.role!), `${id}`).toBe(row.level);
          }
        }
        const placed = tree.rows.flatMap((r) => Object.values(r.cells)).length + tree.directions.length;
        expect(placed).toBe(pool.skills.length);
      }
    }
  });

  it("build code v3 round trips 50 random builds of every class", () => {
    const rand = rng(8282);
    for (const classId of classIds) {
      const ctx = ctxFor(classId);
      const actives = bpOrder(ctx);
      for (let i = 0; i < 50; i++) {
        const build = emptyBuild(1 + rand(rules.maxLevel));
        for (const pool of ctx.pools) {
          if (rand(3) === 0) continue;
          const own: Record<string, number> = {};
          for (const id of pool.skills) {
            const s = ctx.skills.find((x) => x.id === id)!;
            const r = rand(s.maxLevel + 1);
            if (r > 0) own[id] = r;
          }
          if (Object.keys(own).length > 0) build.ranks[pool.id] = own;
          const bar = pool.skills.filter((id) => !ctx.skills.find((x) => x.id === id)!.passive && rand(2) === 0).slice(0, rules.barSlots);
          if (bar.length > 0) build.bars[pool.id] = bar;
        }
        for (const p of ctx.paths) for (const n of p.rows.flatMap((r) => r.nodes)) if (rand(2)) build.nodes[n.id] = 1 + rand(n.maxRank);
        for (const s of actives) {
          if (s.hasB[5] && rand(2)) build.bp[`${s.id}:5`] = "b";
          if (s.hasB[10] && rand(2)) build.bp[`${s.id}:10`] = "b";
        }
        const code = encodeBuild(ctx, build);
        expect(decodeBuild(code, ctx), code).toEqual({ ok: true, build });
        expect(decodeBuild(code.toLowerCase().split("").join(" "), ctx)).toEqual({ ok: true, build });
        expect(canonical(ctx, build)).toEqual(build);
      }
    }
  });

  it("encodes the canonical form, rejects broken codes with a reason and opens a v2 code as old", () => {
    const ctx = ctxFor("Mage");
    const fire = ctx.pools.find((p) => p.id === "fire")!;
    const firstFire = fire.skills[0];
    expect(encodeBuild(ctx, emptyBuild(34))).toBe("3MAGE34");
    expect(encodeBuild(ctx, plan(34, {}, { fire: { [firstFire]: 3 } }))).toBe("3MAGE34.FIRE:3");
    expect(encodeBuild(ctx, plan(60, {}, { fire: { [firstFire]: 10 } }, {}, { fire: [firstFire] }))).toBe("3MAGE60.FIRE:A:0");
    const p1 = ctx.paths.find((p) => p.order === 1)!;
    const first = p1.rows[0].nodes[0];
    expect(first.maxRank).toBeGreaterThanOrEqual(2);
    expect(encodeBuild(ctx, plan(20, { [first.id]: 2 }))).toBe("3MAGE20.2");
    const s0 = bpOrder(ctx)[0];
    expect(s0.hasB[5]).toBe(true);
    expect(encodeBuild(ctx, plan(34, {}, {}, { [`${s0.id}:5`]: "b" }))).toBe("3MAGE34..1");
    expect(decodeBuild("3MAGE34..1", ctx)).toEqual({ ok: true, build: plan(34, {}, {}, { [`${s0.id}:5`]: "b" }) });
    expect(decodeBuild("3MAGE60.FIRE:A5.21-1.1", ctx).ok).toBe(true); // the docs/WIKI.md example
    const err = (code: unknown) => decodeBuild(code, ctx);
    expect(err("2MAGE34.0.1")).toEqual({ ok: false, error: "old" });
    expect(err("MAGE34-a035030-0000000")).toEqual({ ok: false, error: "old" });
    for (const text of ["hello", "3", "334", "X3MAGE34", "2", "MAGE34"]) expect(err(text), text).toEqual({ ok: false, error: "format" });
    expect(err("")).toEqual({ ok: false, error: "empty" });
    expect(err(undefined)).toEqual({ ok: false, error: "empty" });
    expect(err("3HUNTER34")).toEqual({ ok: false, error: "class" });
    expect(err("3MAGE0")).toEqual({ ok: false, error: "level" });
    expect(err(`3MAGE${rules.maxLevel + 1}`)).toEqual({ ok: false, error: "level" });
    expect(err("3MAGE34X")).toEqual({ ok: false, error: "level" });
    expect(err("3MAGE34.NOPE:1")).toEqual({ ok: false, error: "pool" });
    expect(err("3MAGE34.FIRE:1.FIRE:1")).toEqual({ ok: false, error: "pool" });
    expect(err("3MAGE34.FIRE:B")).toEqual({ ok: false, error: "rank" });
    expect(err(`3MAGE34.FIRE:${"1".repeat(fire.skills.length + 1)}`)).toEqual({ ok: false, error: "length" });
    expect(err("3MAGE34.FIRE:1:00")).toEqual({ ok: false, error: "bar" });
    expect(err(`3MAGE34.FIRE:1:${"012345678"}`)).toEqual({ ok: false, error: "bar" });
    expect(err("3MAGE34.9")).toEqual({ ok: false, error: "talent" });
    expect(err(`3MAGE34.${"-".repeat(ctx.paths.length)}1`)).toEqual({ ok: false, error: "length" });
    expect(err("3MAGE34..9")).toEqual({ ok: false, error: "bp" });
    expect(err("3MAGE34.1.1.1")).toEqual({ ok: false, error: "length" });
  });

  it("every class has pools, a ladder tree and directions to plan", () => {
    for (const classId of classIds) {
      const ctx = ctxFor(classId);
      expect(ctx.pools.length).toBeGreaterThan(0);
      expect(ctx.paths.length).toBeGreaterThan(0);
      expect(ctx.rules.barSlots).toBe(8);
      expect(pathView(ctx, ctx.paths[0], emptyBuild(rules.maxLevel)).rows.length).toBe(ctx.paths[0].rows.length);
    }
  });
});
