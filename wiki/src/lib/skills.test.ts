import { describe, expect, it } from "vitest";
import { load } from "./data";
import { rankAt, rankLevel } from "./skills";

const file = load("skills");
const byId = (id: string) => file.skills.find((s) => s.id === id)!;

describe("skill ranks from the level (S56)", () => {
  it("every skill has one level per rank, from the unlock up to the cap", () => {
    for (const s of file.skills) {
      expect(s.rankLevels.length).toBe(s.maxLevel);
      expect(s.rankLevels[0]).toBe(s.unlock);
      for (let i = 1; i < s.rankLevels.length; i++) expect(s.rankLevels[i]).toBeGreaterThan(s.rankLevels[i - 1]);
      expect(s.rankLevels[s.rankLevels.length - 1]).toBeLessThanOrEqual(file.rules.ranks.capLevel);
      s.ranks.forEach((rank, i) => expect(rank.requiredLevel).toBe(s.rankLevels[i]));
    }
  });

  it("rankAt inverts rankLevel", () => {
    for (const s of file.skills) {
      for (let r = 1; r <= s.maxLevel; r++) expect(rankAt(s, rankLevel(s, r))).toBe(r);
      expect(rankAt(s, s.unlock - 1)).toBe(0);
    }
  });

  it("matches the game's control values", () => {
    expect(byId("bloodlust").rankLevels).toEqual([18, 22, 26, 30, 34, 38, 42, 46, 50, 54]);
    expect(byId("steelSkin").rankLevels).toEqual([14, 23, 32, 41, 50]);
    // S81: Elemental Fury moved to a path (hidden on the wiki); Thunderstorm is the latest base skill
    expect(rankAt(byId("firewall"), 81)).toBe(10);
    expect(rankAt(byId("firewall"), 80)).toBe(9);
    expect(file.rules.ranks).toEqual({ step: 4, capLevel: 95 });
  });
});
