import { describe, expect, it } from "vitest";
import { getItem, load } from "./data";
import { buildTooltip, statValue } from "./item-model";
import { itemDetail, tooltipLabels } from "./items";

describe("item detail", () => {
  it("sword1h_30 has 10 levels on every allowed rarity and 9 steps from upgrade.json", () => {
    const d = itemDetail("sword1h_30")!;
    const item = getItem("sword1h_30")!;
    expect(d.rarities.map((r) => r.key).sort()).toEqual([...item.rarities].sort());
    for (const r of d.rarities) {
      expect(d.stats[r.key].find((x) => x.key === "dmg")!.values.length).toBe(10);
      expect(d.upgrade!.costs[r.key].length).toBe(9);
    }
    expect(d.upgrade!.steps.map((s) => s.chance)).toEqual(load("upgrade").steps.map((s) => s.chance));
  });

  it("the tooltip on +7 shows the exported stats", () => {
    const d = itemDetail("sword1h_30")!;
    const tip = buildTooltip(d, { rarity: "heroic", upgrade: 7, lang: "pl" }, tooltipLabels("pl"));
    const dmg = getItem("sword1h_30")!.stats!.heroic.weapon!.dmg[7];
    expect(tip.up).toBe(7);
    expect(tip.rows[0].value).toBe(statValue(d.stats.heroic.find((x) => x.key === "dmg")!, 7, "pl"));
    expect(tip.rows[0].value.replace(/\s/g, "")).toBe(String(dmg));
  });

  it("a boss item has fixed bonuses with values and its boss in the sources", () => {
    const d = itemDetail("unique_grimrok_cleaver")!;
    expect(d.fixed!.length).toBeGreaterThan(0);
    expect(d.fixed!.every((b) => !b.text.pl.includes("{v}") && !b.text.en.includes("{v}"))).toBe(true);
    expect(d.pool).toBeUndefined();
    expect(getItem("unique_grimrok_cleaver")!.sources.bosses.some((b) => b.boss === "grimrok")).toBe(true);
  });

  it("a material has no upgrades and says what it is used for", () => {
    const d = itemDetail("essence_shard")!;
    expect(d.upgrade).toBeUndefined();
    const used = getItem("essence_shard")!.usedFor!;
    expect(used.upgrade.length + used.alchemy.length + used.crafting).toBeGreaterThan(0);
  });

  it("generated equipment has a bonus pool with ranges on its tier", () => {
    const d = itemDetail("sword2h_35")!;
    const b = d.pool!.find((x) => x.id === "critChance")!;
    expect(b.range.heroic).toEqual(load("bonuses").bonuses.find((x) => x.id === "critChance")!.ranges["35"].heroic);
  });
});
