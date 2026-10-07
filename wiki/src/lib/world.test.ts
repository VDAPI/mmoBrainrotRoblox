import { describe, expect, it } from "vitest";
import { load } from "./data";
import { cavesOf, mapList, neighbours, regionOrder } from "./world";

describe("world", () => {
  it("lists maps like the game's map window: city, then each region followed by its caves by level", () => {
    const list = mapList().map((m) => m.id);
    expect(list[0]).toBe("city");
    const regions = regionOrder();
    expect(regions).toEqual(["meadows", "duskwood", "ashen", "frostpeak"]);
    for (const r of regions) {
      const at = list.indexOf(r);
      const caves = cavesOf(r).map((c) => c.id);
      expect(list.slice(at + 1, at + 1 + caves.length)).toEqual(caves);
      const levels = cavesOf(r).map((c) => c.levelMin);
      expect([...levels].sort((a, b) => a - b)).toEqual(levels);
    }
    expect(list.some((id) => id.startsWith("dungeon_"))).toBe(false);
  });

  it("neighbours come from portals in both directions", () => {
    for (const m of load("maps").maps) {
      for (const n of neighbours(m.id)) expect(neighbours(n)).toContain(m.id);
    }
    expect(neighbours("meadows")).toContain("city");
  });
});
