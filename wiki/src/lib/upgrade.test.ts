import { describe, expect, it } from "vitest";
import { load } from "./data";
import { expected, firstTryChance, type Cost, type Step } from "./upgrade";

const file = load("upgrade");
const steps: Step[] = file.steps;
const costsFor = (ilvl: number, rarity: string): Cost[] => {
  const tiers = file.tiers.filter((t) => t <= ilvl);
  return file.costs[String(tiers[tiers.length - 1])][rarity];
};

describe("upgrade calculator", () => {
  it("needs exactly to − from attempts when every step is certain", () => {
    const sure = steps.map((s) => ({ ...s, chance: 1 }));
    const r = expected(sure, costsFor(30, "common"), 2, 7);
    expect(r.attempts).toBeCloseTo(5, 9);
    expect(r.scrolls).toBe(0);
  });

  it("first try chance is the product of the step chances", () => {
    expect(firstTryChance(steps, 5, 8)).toBeCloseTo(steps[5].chance * steps[6].chance * steps[7].chance, 12);
    expect(firstTryChance(steps, 3, 3)).toBe(1);
  });

  it("matches the recursion D_L = (1 + q·D_(L−1)) / p for a one-level drop", () => {
    const r = expected(steps, costsFor(30, "common"), 0, 6);
    let total = 0;
    let prev = 0;
    for (let level = 0; level < 6; level++) {
      const p = steps[level].chance;
      const d = level === 0 ? 1 / p : (1 + (1 - p) * prev) / p;
      expect(r.perStep[level].attempts).toBeCloseTo(d, 9);
      total += d;
      prev = d;
    }
    expect(r.attempts).toBeCloseTo(total, 9);
  });

  it("protection lowers the gold of the protected steps and costs one scroll per protected attempt", () => {
    const costs = costsFor(30, "legendary");
    const plain = expected(steps, costs, 5, 9);
    const guarded = expected(steps, costs, 5, 9, 7);
    expect(guarded.gold).toBeLessThan(plain.gold);
    const protectedAttempts = guarded.perStep.filter((s) => s.protected).reduce((n, s) => n + s.attempts, 0);
    expect(guarded.scrolls).toBeCloseTo(protectedAttempts, 9);
    expect(expected(steps, costs, 5, 9).gold).toBeGreaterThan(expected(steps, costs, 5, 8).gold);
  });

  it("per-step totals add up to the whole path", () => {
    const r = expected(steps, costsFor(50, "heroic"), 3, 9, 8);
    const sum = r.perStep.reduce((n, s) => n + s.gold, 0);
    expect(sum).toBeCloseTo(r.gold, 6);
  });

  it("agrees with the game's simulation vectors (Lune, Upgrade.attempt)", () => {
    for (const v of file.vectors) {
      const r = expected(steps, costsFor(v.ilvl, v.rarity), v.from, v.to, v.protectFrom ?? null);
      const near = (model: number, sim: number) => expect(Math.abs(model - sim)).toBeLessThanOrEqual(Math.max(0.02 * model, 0.05));
      near(r.attempts, v.attempts);
      near(r.gold, v.gold);
      near(r.scrolls, v.scrolls);
      for (const [id, n] of Object.entries(v.materials)) near(r.materials[id] ?? 0, n);
    }
  });
});
