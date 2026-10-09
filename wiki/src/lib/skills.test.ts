import { describe, expect, it } from "vitest";
import { load } from "./data";
import {
  canAdd,
  canRemove,
  decodeBuild,
  encodeBuild,
  free,
  maxReachableRank,
  nodeState,
  pointsAt,
  rankLevel,
  requiredCharLevel,
  validate,
  type Build,
} from "./skills";

const file = load("skills");
const rules = file.rules;
const skillsOf = (classId: string) => file.skills.filter((s) => s.class === classId).sort((a, b) => a.order - b.order);
const byId = new Map(file.skills.map((s) => [s.id, s]));
const classes = load("classes").classes.map((c) => c.id);

describe("skill planner parity with Skills.canLearn (rules.vectors)", () => {
  it("has vectors for every class and every reason code", () => {
    const seen = new Set<string>();
    for (const state of rules.vectors.states) {
      for (const r of state.results) {
        seen.add(r.ok ? "ok" : String(r.reason));
      }
    }
    expect([...seen].sort()).toEqual(["level", "maxLevel", "noPoints", "ok", "requires"]);
    expect(new Set(rules.vectors.states.map((s) => s.class))).toEqual(new Set(classes));
    expect(rules.vectors.builds.some((b) => b.achievable)).toBe(true);
    expect(rules.vectors.builds.some((b) => !b.achievable)).toBe(true);
  });

  it("canAdd answers like the game in every state", () => {
    for (const state of rules.vectors.states) {
      const build: Build = { ...state.skills };
      expect(free(rules, build, state.level)).toBe(state.skillPoints);
      for (const r of state.results) {
        const got = canAdd(rules, build, state.level, byId.get(r.skill)!);
        expect({ skill: r.skill, ...got }).toEqual({ skill: r.skill, ok: r.ok, reason: r.reason, detail: r.detail });
      }
    }
  });

  it("validate equals the replay of the build in Lune", () => {
    for (const b of rules.vectors.builds) {
      expect(validate(skillsOf(b.class), rules, { ...b.skills }, b.level).ok, JSON.stringify(b)).toBe(b.achievable);
    }
  });
});

describe("skill planner rules", () => {
  const mage = skillsOf("Mage");
  const firebolt = byId.get("firebolt")!;
  const fireball = byId.get("fireball")!;

  it("gives the exported points per level", () => {
    expect(pointsAt(rules, 1)).toBe(rules.pointsByLevel[0]);
    expect(pointsAt(rules, 34)).toBe(rules.pointsByLevel[33]);
    expect(pointsAt(rules, rules.maxLevel)).toBe(rules.pointsByLevel[rules.maxLevel - 1]);
  });

  it("does not remove a requirement another learned skill needs", () => {
    const build: Build = { firebolt: 3, fireball: 1 };
    expect(canRemove(mage, build, "firebolt")).toBe(false);
    expect(canRemove(mage, { firebolt: 4, fireball: 1 }, "firebolt")).toBe(true);
    expect(canRemove(mage, build, "fireball")).toBe(true);
    expect(canRemove(mage, build, "iceShard")).toBe(false);
  });

  it("requiredCharLevel is at least unlock + rank 5 requirement", () => {
    for (const skill of file.skills.filter((s) => s.maxLevel >= 5 && s.requires.length === 0)) {
      const level = requiredCharLevel(skillsOf(skill.class), rules, { [skill.id]: 5 });
      expect(level).not.toBeNull();
      expect(level!).toBeGreaterThanOrEqual(skill.unlock + 12);
      expect(level!).toBe(Math.max(rankLevel(skill, 5), rules.pointsByLevel.findIndex((p) => p >= 5) + 1));
    }
    expect(requiredCharLevel(mage, rules, { fireball: 1 })).toBeNull();
  });

  it("maxReachableRank is below maxLevel exactly for ranks needing a level above the maximum", () => {
    for (const skill of file.skills) {
      const unreachable = skill.ranks.some((r) => r.requiredLevel > rules.maxLevel);
      expect(maxReachableRank(skill, rules.maxLevel) < skill.maxLevel).toBe(unreachable);
    }
  });

  it("locks fireball until firebolt has rank 3", () => {
    expect(nodeState({ firebolt: 2 }, 34, fireball).state).toBe("locked");
    expect(nodeState({ firebolt: 3 }, 34, fireball).state).toBe("available");
    expect(nodeState({ firebolt: 3 }, 34, firebolt).state).toBe("partial");
    expect(nodeState({ firebolt: 10 }, 27, firebolt)).toEqual({ state: "max", invalid: true });
    expect(nodeState({ firebolt: 3 }, 9, fireball).state).toBe("locked");
  });
});

describe("build code", () => {
  // Deterministic pseudo-random builds (xorshift).
  let seed = 41;
  const rand = (n: number): number => {
    seed ^= seed << 13;
    seed ^= seed >>> 17;
    seed ^= seed << 5;
    return Math.abs(seed) % n;
  };

  it("round-trips random builds of every class", () => {
    for (const classId of classes) {
      const list = skillsOf(classId);
      for (let i = 0; i < 50; i++) {
        const build: Build = {};
        for (const s of list) {
          const rank = rand(s.maxLevel + 1);
          if (rank > 0) {
            build[s.id] = rank;
          }
        }
        const level = 1 + rand(rules.maxLevel);
        const code = encodeBuild(classId, level, list, build);
        expect(decodeBuild(code, classId, list, rules)).toEqual({ ok: true, classId, level, build });
        expect(decodeBuild(code.toLowerCase().replace(/-/g, ""), classId, list, rules)).toEqual({ ok: true, classId, level, build });
      }
    }
  });

  it("formats like MAGE34-a035030-0000000", () => {
    const code = encodeBuild("Mage", 34, mageList(), { firebolt: 10, blink: 3, fireball: 5, chainLightning: 3 });
    expect(code).toBe("MAGE34-a035030-0000000");
  });

  it("reads the level-34 sample build of the shots (33 points, 3 left, fireball needs firebolt 3)", () => {
    const list = mageList();
    const r = decodeBuild("MAGE34-a535230-2000000", "Mage", list, rules);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(pointsAt(rules, 34)).toBe(33);
    expect(free(rules, r.build, r.level)).toBe(3);
    expect(validate(list, rules, r.build, r.level).ok).toBe(true);
    expect(canRemove(list, r.build, "firebolt")).toBe(true);
    expect(canRemove(list, { ...r.build, firebolt: 3 }, "firebolt")).toBe(false);
    expect(maxReachableRank(byId.get("meteorStorm")!, rules.maxLevel)).toBe(10);
  });

  it("rejects bad codes with a reason, never throws", () => {
    const list = mageList();
    const good = encodeBuild("Mage", 34, list, { firebolt: 2 });
    expect(decodeBuild("", "Mage", list, rules)).toEqual({ ok: false, error: "empty" });
    expect(decodeBuild(good.replace("MAGE", "CLERIC"), "Mage", list, rules)).toEqual({ ok: false, error: "class" });
    expect(decodeBuild(good + "0", "Mage", list, rules)).toEqual({ ok: false, error: "length" });
    expect(decodeBuild(good.slice(0, -1), "Mage", list, rules)).toEqual({ ok: false, error: "length" });
    expect(decodeBuild(good.replace("34", "0"), "Mage", list, rules)).toEqual({ ok: false, error: "level" });
    expect(decodeBuild(good.replace("34", "101"), "Mage", list, rules)).toEqual({ ok: false, error: "level" });
    // focus (order 5) is passive: max 5.
    expect(decodeBuild("MAGE34-2000600-0000000", "Mage", list, rules)).toEqual({ ok: false, error: "rank" });
    expect(decodeBuild("MAGE34-20?0000-0000000", "Mage", list, rules)).toEqual({ ok: false, error: "rank" });
    expect(() => decodeBuild(undefined as unknown as string, "Mage", list, rules)).not.toThrow();
  });

  function mageList() {
    return skillsOf("Mage");
  }
});
