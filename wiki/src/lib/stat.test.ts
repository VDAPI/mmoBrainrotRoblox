import { describe, expect, it } from "vitest";
import { load } from "./data";
import { formatStat, resolvePath, resolveStat } from "./stat";

describe("stat paths", () => {
  it("resolves keys, records by id or key and indexes", () => {
    expect(resolveStat("mechanics.config.MaxLevel")).toBe(load("mechanics").config.MaxLevel);
    expect(resolveStat("stats.stats[critChance].cap")).toBe(load("stats").stats.find((s) => s.id === "critChance")!.cap);
    expect(resolveStat("progression.expToNext.0.exp")).toBe(load("progression").expToNext[0].exp);
    expect(resolvePath("rarities.rarities[mythic]")).toBe(load("rarities").rarities.find((r) => r.key === "mythic"));
  });

  it("throws with the path for anything missing", () => {
    expect(() => resolveStat("mechanics.config.NoSuchKey")).toThrow(/mechanics\.config\.NoSuchKey/);
    expect(() => resolveStat("nofile.x")).toThrow(/unknown data file/);
    expect(() => resolveStat("stats.stats[nope].cap")).toThrow(/no record "nope"/);
    expect(() => resolveStat("progression.expToNext.9999.exp")).toThrow(/no index/);
    expect(() => resolveStat("mechanics.zones")).toThrow(/not a number/);
  });

  it("works on any getter (no data files needed)", () => {
    const get = () => ({ list: [{ id: "a", v: 3 }] });
    expect(resolveStat("meta.list[a].v", get)).toBe(3);
  });
});

describe("stat formats", () => {
  it("formats every kind in Polish and English", () => {
    expect(formatStat(15, "pct", "pl")).toBe("15%");
    expect(formatStat(0.15, "frac", "pl")).toBe("15%");
    expect(formatStat(0.075, "frac", "en")).toBe("7.5%");
    expect(formatStat(1.5, "x", "pl")).toBe("×1,5");
    expect(formatStat(10, "s", "en")).toBe("10 s");
    expect(formatStat(180, "min", "pl")).toBe("3 min");
    expect(formatStat(3600, "h", "en")).toBe("1 h");
    expect(formatStat(12500, "gold", "pl")).toBe("12 500 złota");
    expect(formatStat(12500, "gold", "en")).toBe("12,500 gold");
    expect(formatStat(20, "lvl", "pl")).toBe("poz. 20");
    expect(formatStat(20, "lvl", "en")).toBe("level 20");
    expect(formatStat(0.3, "num", "pl")).toBe("0,3");
    expect(formatStat(2, "num", "en", 1)).toBe("2.0");
  });
});
