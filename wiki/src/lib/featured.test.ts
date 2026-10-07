import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import type { Files } from "../data/types";
import { isoWeek, pickFeaturedItem, pickMonsterOfWeek, pickWeeklyLegendary } from "./featured";

const load = <K extends keyof Files>(name: K): Files[K] =>
  JSON.parse(readFileSync(join(process.cwd(), "src", "data", `${name}.json`), "utf8"));

describe("featured", () => {
  it("computes ISO weeks", () => {
    expect(isoWeek(new Date("2026-01-01T12:00:00Z")).key).toBe("2026-W01");
    expect(isoWeek(new Date("2027-01-01T12:00:00Z")).key).toBe("2026-W53");
    expect(isoWeek(new Date("2026-10-07T12:00:00Z")).week).toBe(41);
  });

  it("picks deterministically from the data", () => {
    const items = load("items").items;
    const hero = pickFeaturedItem(items, load("rarities").rarities)!;
    expect(hero.rarities.length).toBe(1);
    expect(pickFeaturedItem(items, load("rarities").rarities)!.id).toBe(hero.id);
    const a = pickWeeklyLegendary(items, "2026-W41")!;
    const b = pickWeeklyLegendary(items, "2026-W41")!;
    expect(a.item.id).toBe(b.item.id);
    expect(a.item.rarities).toContain("legendary");
    expect(a.upgrade).toBeGreaterThanOrEqual(0);
    expect(a.upgrade).toBeLessThanOrEqual(9);
  });

  it("the monster of the week always has spawning elites", () => {
    const monsters = load("monsters").monsters;
    for (let w = 1; w <= 53; w++) {
      const pick = pickMonsterOfWeek(monsters, `2026-W${String(w).padStart(2, "0")}`)!;
      expect(pick.monster.variants.elite.spawns.length).toBeGreaterThan(0);
      expect(pick.level).toBe(pick.monster.variants.elite.levelMax);
    }
  });
});
