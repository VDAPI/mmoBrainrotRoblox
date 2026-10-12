// Skill planner rules (S82): parity with Logic/Paths (vectors computed in Lune), view models and build code v2. The
// test paths come from wiki/test-fixtures/planner.json (tests/fixtures/paths.luau, never on the wiki); the game data
// from src/data through load().
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import type { SkillPath, SkillPathVectors } from "../data/types";
import { pathsOf, ruleSkill } from "./classes";
import { load } from "./data";
import {
  BUY_ERRORS,
  REFUND_ERRORS,
  achievable,
  canBuy,
  canRefund,
  decodeBuild,
  encodeBuild,
  free,
  pathView,
  pruneChoices,
  rankAt,
  setMain,
  validate,
  variantKey,
  type CodeCtx,
  type PathRules,
  type PlanBuild,
  type RulePath,
  type RuleSkill,
} from "./skills";

const file = load("skills");
const rules: PathRules = {
  maxLevel: file.rules.maxLevel,
  pathPointsByLevel: file.rules.pathPointsByLevel,
  mainPathLevel: file.rules.mainPathLevel,
  dipRows: file.rules.dipRows,
};
const fixture = JSON.parse(readFileSync("test-fixtures/planner.json", "utf8")) as { paths: SkillPath[]; vectors: SkillPathVectors };
const classes = load("classes").classes.map((c) => c.id);

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

const plan = (level: number, main: string | null = null, nodes: Record<string, number> = {}, bp: PlanBuild["bp"] = {}): PlanBuild => ({
  level,
  main,
  nodes,
  bp,
});

function parity(paths: RulePath[], vectors: SkillPathVectors): { buy: Set<string>; refund: Set<string>; reached: Set<boolean> } {
  const buy = new Set<string>();
  const refund = new Set<string>();
  for (const state of vectors.states) {
    const own = paths.filter((p) => p.class === state.class);
    const build = plan(state.level, state.main ?? null, { ...state.nodes });
    expect(free(own, rules, build), `free at ${state.level}`).toBe(state.free);
    for (const r of state.results) {
      const b = canBuy(own, rules, build, r.node);
      const f = canRefund(own, rules, build, r.node);
      const where = `${state.class} lv ${state.level} main ${state.main ?? "-"} ${r.node}`;
      expect({ ok: b.ok, reason: b.reason ?? null }, where).toEqual({ ok: r.ok, reason: r.reason ?? null });
      expect({ ok: f.ok, reason: f.reason ?? null }, where).toEqual({ ok: r.refund, reason: r.refundReason ?? null });
      buy.add(r.reason ?? "ok");
      refund.add(r.refundReason ?? "ok");
    }
  }
  const reached = new Set<boolean>();
  for (const b of vectors.builds) {
    const own = paths.filter((p) => p.class === b.class);
    const build = plan(b.level, b.main ?? null, { ...b.nodes });
    expect(achievable(own, rules, build), `${b.class} lv ${b.level} ${JSON.stringify(b.nodes)}`).toBe(b.achievable);
    reached.add(b.achievable);
  }
  return { buy, refund, reached };
}

describe("planner rules on the test paths (wiki/test-fixtures/planner.json)", () => {
  const paths: RulePath[] = fixture.paths;
  const storm = paths.find((p) => p.id === "fxStorm")!;
  const rune = paths.find((p) => p.id === "fxRune")!;

  it("canBuy, canRefund, free and achievable match Logic/Paths, with every reason key", () => {
    const seen = parity(paths, fixture.vectors);
    expect([...seen.buy].sort()).toEqual([...BUY_ERRORS, "ok"].sort());
    expect([...seen.refund].sort()).toEqual([...REFUND_ERRORS, "ok"].sort());
    expect(seen.reached).toEqual(new Set([true, false]));
  });

  it("pathView gives the reasons of closed rows, choice rows and the 1/3 strength", () => {
    expect(pathView(storm, paths, rules, plan(14)).rows[1].reason).toBe("level");
    const at40 = plan(40, "fxStorm");
    expect(pathView(rune, paths, rules, at40).rows[2].reason).toBe("main");
    const row1 = Object.fromEntries(storm.rows[0].nodes.map((n) => [n.id, n.maxRank]));
    const chosen = plan(40, "fxStorm", { ...row1, [storm.rows[2].nodes[0].id]: 1 });
    const third = pathView(storm, paths, rules, chosen).rows[2];
    expect(third.open).toBe(true);
    expect(third.nodes[1].buy).toEqual({ ok: false, reason: "paths.error.choice" });
    expect(third.nodes[1].state).toBe("locked");
    expect(third.nodes[0].state).not.toBe("locked");
    const dipNode = rune.rows.flatMap((r) => r.nodes).find((n) => n.dipScale !== undefined) ?? storm.rows.flatMap((r) => r.nodes).find((n) => n.dipScale !== undefined)!;
    const owner = dipNode.id.startsWith("fxRune") ? rune : storm;
    const notMain = plan(40, owner === storm ? "fxRune" : "fxStorm");
    const view = pathView(owner, paths, rules, notMain).rows.flatMap((r) => r.nodes).find((n) => n.id === dipNode.id)!;
    expect(view.dip).toBe(true);
    const asMain = pathView(owner, paths, rules, plan(40, owner.id)).rows.flatMap((r) => r.nodes).find((n) => n.id === dipNode.id)!;
    expect(asMain.dip).toBe(false);
  });

  it("an unreachable node is invalid and validate counts points over the level", () => {
    const build = plan(10, null, { fxStorm_focus: 3, fxStorm_beacon: 1 });
    const view = pathView(storm, paths, rules, build);
    expect(view.rows[1].nodes[0].invalid).toBe(true);
    expect(validate(paths, rules, build).unreached).toEqual(["fxStorm_beacon"]);
    expect(validate(paths, rules, plan(2, null, { fxStorm_focus: 3 })).over).toBe(2);
    expect(validate(paths, rules, plan(19, "fxStorm")).mainOk).toBe(false);
  });

  it("setMain refunds rows above dipRows of the old main path", () => {
    const nodes: Record<string, number> = { fxStorm_focus: 3, fxStorm_fxSpark: 1, fxStorm_surge: 1, fxRune_r2a: 2 };
    const moved = setMain(paths, rules, plan(40, "fxStorm", nodes), "fxRune");
    expect(moved.main).toBe("fxRune");
    expect(moved.nodes).toEqual({ fxStorm_focus: 3, fxStorm_fxSpark: 1, fxRune_r2a: 2 });
    expect(setMain(paths, rules, plan(40, "fxStorm", nodes), null).nodes.fxStorm_surge).toBeUndefined();
  });

  it("pruneChoices drops the A/B of a path skill whose node has no rank, so the code carries the whole build", () => {
    const bought = plan(40, "fxStorm", { fxStorm_fxSpark: 1 }, { "fxSpark:5": "b", "b1:5": "b" });
    expect(pruneChoices(paths, bought)).toBe(bought);
    const refunded = plan(40, "fxStorm", {}, { "fxSpark:5": "b", "b1:5": "b" });
    expect(pruneChoices(paths, refunded).bp).toEqual({ "b1:5": "b" });
  });

  const fakeBase: RuleSkill[] = [
    { id: "b1", order: 1, unlock: 1, maxLevel: 10, passive: false, rankLevels: [], hasB: { 5: true, 10: true } },
    { id: "b2", order: 2, unlock: 1, maxLevel: 10, passive: false, rankLevels: [], hasB: { 5: true, 10: false } },
    { id: "b3", order: 3, unlock: 1, maxLevel: 5, passive: true, rankLevels: [], hasB: { 5: false, 10: false } },
  ];
  const ctx: CodeCtx = { classId: "Mage", maxLevel: rules.maxLevel, skills: fakeBase, paths };

  it("build code v2 round trips 50 random builds with nodes, a main path and path skill breakpoints", () => {
    const rand = rng(82);
    const all = paths.flatMap((p) => p.rows.flatMap((r) => r.nodes));
    for (let i = 0; i < 50; i++) {
      const build = plan(1 + rand(rules.maxLevel), [null, "fxStorm", "fxRune"][rand(3)]);
      for (const n of all) {
        const rank = rand(n.maxRank + 2) - 1;
        if (rank > 0) build.nodes[n.id] = Math.min(rank, n.maxRank);
        if (n.kind === "skill" && n.skill && build.nodes[n.id] && n.skillB?.includes(5) && rand(2)) build.bp[`${n.skill}:5`] = "b";
      }
      if (rand(2)) build.bp["b1:5"] = "b";
      if (rand(2)) build.bp["b1:10"] = "b";
      if (rand(2)) build.bp["b2:5"] = "b";
      const code = encodeBuild(ctx, build);
      expect(decodeBuild(code, ctx), code).toEqual({ ok: true, build });
      expect(decodeBuild(code.toLowerCase().split("").join(" "), ctx)).toEqual({ ok: true, build });
    }
  });

  it("encodes the canonical form and decodes missing segments as zeros", () => {
    expect(encodeBuild(ctx, plan(34))).toBe("2MAGE34.0");
    expect(encodeBuild(ctx, plan(34, null, {}, { "b1:5": "b" }))).toBe("2MAGE34.0.1");
    expect(encodeBuild(ctx, plan(34, null, {}, { "b2:5": "b" }))).toBe("2MAGE34.0.01");
    expect(encodeBuild(ctx, plan(10, null, { fxRune_fxGlyph: 1 }))).toBe("2MAGE10.0...1");
    expect(decodeBuild("2MAGE34", ctx)).toEqual({ ok: true, build: plan(34) });
    expect(decodeBuild("2MAGE34.0.10.000.", ctx)).toEqual({ ok: true, build: plan(34, null, {}, { "b1:5": "b" }) });
    // fxSpark has option B only at rank 5: digit 2 (bought + B at 5) passes, 3 (also B at 10) does not
    const spark = storm.rows[0].nodes.findIndex((n) => n.skill === "fxSpark");
    expect(storm.rows[0].nodes[spark].skillB).toEqual([5]);
    const seg = (d: string): string => "0".repeat(spark) + d;
    expect(decodeBuild(`2MAGE40.1..${seg("2")}`, ctx)).toEqual({
      ok: true,
      build: plan(40, "fxStorm", { fxStorm_fxSpark: 1 }, { "fxSpark:5": "b" }),
    });
    expect(decodeBuild(`2MAGE40.1..${seg("3")}`, ctx)).toEqual({ ok: false, error: "bp" });
    expect(decodeBuild(`2MAGE40.1..${seg("5")}`, ctx)).toEqual({ ok: false, error: "rank" });
  });

  it("a code with only the order-2 path decodes the same when the planner knows only that path", () => {
    const build = plan(60, "fxRune", { fxRune_fxGlyph: 1, fxRune_mend: 2, fxRune_r2a: 1 });
    const code = encodeBuild(ctx, build);
    expect(code.split(".")[3]).toBe("");
    const only: CodeCtx = { ...ctx, paths: [rune] };
    expect(encodeBuild(only, build)).toBe(code);
    expect(decodeBuild(code, only)).toEqual({ ok: true, build });
    expect(decodeBuild(code, ctx)).toEqual({ ok: true, build });
    expect(decodeBuild("2MAGE60.0..1", only)).toEqual({ ok: false, error: "length" });
  });
});

describe("planner on the game data", () => {
  const skillsOf = (classId: string) =>
    file.skills.filter((s) => s.class === classId).sort((a, b) => a.order - b.order);

  it("rankAt inverts rankLevels", () => {
    for (const s of file.skills) {
      expect(s.rankLevels.length).toBe(s.maxLevel);
      s.ranks.forEach((rank, i) => expect(rank.requiredLevel).toBe(s.rankLevels[i]));
      for (let r = 1; r <= s.maxLevel; r++) {
        expect(rankAt(s, s.rankLevels[r - 1])).toBe(r);
        expect(rankAt(s, s.rankLevels[r - 1] - 1)).toBe(r - 1);
      }
    }
  });

  it("has rank variants exactly where a skill has option B", () => {
    for (const s of file.skills) {
      const rule = ruleSkill(s);
      s.ranks.forEach((rank, i) => {
        const r = i + 1;
        const want = [r >= 5 && rule.hasB[5] ? "ba" : null, r >= 10 && rule.hasB[10] ? "ab" : null, r >= 10 && rule.hasB[5] && rule.hasB[10] ? "bb" : null]
          .filter(Boolean)
          .sort();
        expect(Object.keys(rank.variants ?? {}).sort(), `${s.id} ${r}`).toEqual(want);
      });
      const b = { level: 100, main: null, nodes: {}, bp: { [`${s.id}:5`]: "b" as const } };
      expect(variantKey(b, s, 4)).toBe("aa");
      expect(variantKey(b, s, 5)).toBe("ba");
    }
  });

  it("build code v2 round trips 50 random builds of every class", () => {
    const rand = rng(8282);
    for (const classId of classes) {
      const skills = skillsOf(classId).map(ruleSkill);
      const paths = pathsOf(classId);
      const ctx: CodeCtx = { classId, maxLevel: rules.maxLevel, skills, paths };
      for (let i = 0; i < 50; i++) {
        const build = plan(1 + rand(rules.maxLevel), paths.length > 0 && rand(2) ? paths[rand(paths.length)].id : null);
        for (const s of skills.filter((x) => !x.path && !x.passive)) {
          if (s.hasB[5] && rand(2)) build.bp[`${s.id}:5`] = "b";
          if (s.hasB[10] && rand(2)) build.bp[`${s.id}:10`] = "b";
        }
        for (const p of paths) {
          for (const n of p.rows.flatMap((r) => r.nodes)) {
            const rank = rand(n.maxRank + 1);
            if (rank > 0) build.nodes[n.id] = rank;
          }
        }
        expect(decodeBuild(encodeBuild(ctx, build), ctx)).toEqual({ ok: true, build });
      }
    }
  });

  it("decodes every error without throwing, and the example Mage build at level 34", () => {
    const skills = skillsOf("Mage").map(ruleSkill);
    const ctx: CodeCtx = { classId: "Mage", maxLevel: rules.maxLevel, skills, paths: pathsOf("Mage") };
    const err = (code: unknown) => decodeBuild(code, ctx);
    expect(err("MAGE34-a035030-0000000")).toEqual({ ok: false, error: "old" });
    expect(err("")).toEqual({ ok: false, error: "empty" });
    expect(err(undefined)).toEqual({ ok: false, error: "empty" });
    expect(err("2MAGE34.x")).toEqual({ ok: false, error: "main" });
    expect(err("2MAGE34.0.9")).toEqual({ ok: false, error: "bp" });
    expect(err("2MAGE34X")).toEqual({ ok: false, error: "level" });
    expect(err("2HUNTER34.0")).toEqual({ ok: false, error: "class" });
    expect(err("2MAGE0.0")).toEqual({ ok: false, error: "level" });
    expect(err(`2MAGE${rules.maxLevel + 1}.0`)).toEqual({ ok: false, error: "level" });
    expect(err("2MAGE34.9")).toEqual({ ok: false, error: "main" });
    expect(err(`2MAGE34.0.${"0".repeat(skills.filter((s) => !s.path && !s.passive).length + 1)}`)).toEqual({ ok: false, error: "length" });
    // a non-empty segment beyond the largest published path order
    const top = Math.max(0, ...ctx.paths.map((p) => p.order));
    expect(err(`2MAGE34.0.0${".".repeat(top)}.1`)).toEqual({ ok: false, error: "length" });
    // a made-up skill without B at rank 10 (after S81 every active of the game has both)
    const noB10: CodeCtx = {
      ...ctx,
      skills: [{ id: "x", order: 1, unlock: 1, maxLevel: 10, passive: false, rankLevels: [], hasB: { 5: true, 10: false } }],
    };
    expect(decodeBuild("2MAGE34.0.2", noB10)).toEqual({ ok: false, error: "bp" });
    expect(decodeBuild("2MAGE34.0.1", noB10).ok).toBe(true);
    // the screenshots' example: B at rank 5 of the first Mage active
    const first = skills.filter((s) => !s.path && !s.passive)[0];
    expect(first.hasB[5]).toBe(true);
    expect(encodeBuild(ctx, plan(34, null, {}, { [`${first.id}:5`]: "b" }))).toBe("2MAGE34.0.1");
    expect(decodeBuild("2MAGE34.0.1", ctx)).toEqual({ ok: true, build: plan(34, null, {}, { [`${first.id}:5`]: "b" }) });
  });

  it.skipIf(file.rules.vectors.states.length === 0)("matches the game vectors of the published paths", () => {
    const seen = parity(file.paths, file.rules.vectors);
    expect(seen.buy.size).toBeGreaterThan(1);
  });
});
