import { describe, expect, it } from "vitest";
import { occurringVariants, signatureDrop } from "./bestiary";
import { getBoss, getItem, getMonster, monsters } from "./data";
import { formatNumber } from "./format";
import { levelCells, lootRarities, lootRows, pageVariants } from "./monster";

describe("monster page", () => {
  it("shows the variants that have spawns", () => {
    for (const m of monsters()) {
      const live = occurringVariants(m);
      expect(pageVariants(m)).toEqual(live.length > 0 ? live : ["normal"]);
    }
  });

  it("takes the stat cells from the export (wolf lvl 5, an Elite II, a boss for 3 players)", () => {
    const wolf = getMonster("wolf")!;
    const row = wolf.variants.normal.levels.find((l) => l.finalLevel === 5)!;
    const cells = levelCells(row, "pl");
    expect(cells.hp).toBe(row.hp);
    expect(cells.dmg).toBe(`${formatNumber(row.dmgMin, "pl")}–${formatNumber(row.dmgMax, "pl")}`);
    expect(cells.exp).toBe(formatNumber(row.exp, "pl"));
    const e2 = monsters().find((m) => occurringVariants(m).includes("elite2") && m.ability)!;
    const r2 = e2.variants.elite2.levels[0];
    const c2 = levelCells(r2, "en");
    expect(c2.armor).toBe(formatNumber(r2.armor, "en"));
    expect(c2.ability).toBe(`${formatNumber(r2.abilityMin!, "en")}–${formatNumber(r2.abilityMax!, "en")}`);
    const boss = getBoss("grimrok")!;
    expect(boss.byPlayers.find((p) => p.players === 3)!.hp).toBeGreaterThan(boss.byPlayers[0].hp);
  });

  it("sorts loot rows rarest first with the material chances of the tables", () => {
    for (const m of monsters()) {
      for (const v of occurringVariants(m)) {
        const rows = lootRows(m, v, "pl");
        const chances = rows.slice(0, -1).map((r) => r.chance);
        expect([...chances].sort((a, b) => a - b)).toEqual(chances);
        expect(rows[rows.length - 1].kind).toBe("gold");
        for (const mat of m.variants[v].loot.materials) {
          const row = rows.find((r) => r.key === `m-${mat.id}`)!;
          const twice = m.variants[v].loot.materials.filter((x) => x.id === mat.id).length > 1;
          expect(row.chance).toBe(twice ? mat.measured : mat.chance);
        }
        const top = lootRarities(m.variants[v].loot).at(-1);
        for (const g of rows.filter((r) => r.kind === "group")) expect(g.itemRarity).toBe(top);
      }
    }
  });

  it("picks a rare monster part as the signature drop", () => {
    const wolf = signatureDrop(getMonster("wolf")!, "normal");
    expect(wolf).toBe("wolf_pelt");
    expect(getItem(wolf!)?.category).toBe("material");
  });
});
