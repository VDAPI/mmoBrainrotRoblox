import { describe, expect, it } from "vitest";
import { href, ROUTES } from "../i18n/routes";
import { items, load } from "./data";
import { listRarity, mainStat } from "./item-model";
import { indexRows, itemDetail } from "./items";
import { DEFAULT_ITEM_FILTERS, groupTiers, itemMatches, parseItemFilters, serializeItemFilters, type ItemFilters } from "./items-filters";
import { normalize } from "./search";

const order = load("rarities").rarities.map((r) => r.key);
const rows = indexRows("pl", (id) => href("pl", "items", id), normalize);
const f = (patch: Partial<ItemFilters>): ItemFilters => ({ ...DEFAULT_ITEM_FILTERS, rarities: [], ...patch });

describe("item browser", () => {
  it("shows the highest checked rarity, else the lowest allowed", () => {
    expect(listRarity(["common", "unique", "heroic"], [], order)).toBe("common");
    expect(listRarity(["common", "unique", "heroic"], ["unique", "heroic", "mythic"], order)).toBe("heroic");
    expect(listRarity(["mythic"], ["common"], order)).toBe("mythic");
  });

  it("groups generated tiers into one row per base and picks the tier for a level range", () => {
    const groups = groupTiers(rows, null);
    const sword = groups.find((g) => g.base === "base:sword2h")!;
    expect(sword.tiers.length).toBe(items().filter((i) => i.type === "sword2h" && i.id === `sword2h_${i.tier}`).length);
    expect(sword.shown.level).toBe(Math.max(...sword.tiers.map((t) => t.level).filter((l) => l <= 100)));
    const ranged = groupTiers(rows.filter((r) => itemMatches(r, f({ lv: [30, 44] }))), [30, 44]).find((g) => g.base === "base:sword2h")!;
    expect(ranged.shown.level).toBeLessThanOrEqual(44);
    expect(ranged.shown.level).toBeGreaterThanOrEqual(30);
  });

  it("filters by rarity, slot, class, level and a name without Polish letters", () => {
    const mythic = rows.filter((r) => itemMatches(r, f({ rarities: ["mythic"] })));
    expect(mythic.every((r) => r.rarities.includes("mythic"))).toBe(true);
    expect(rows.filter((r) => itemMatches(r, f({ slot: "ring" }))).every((r) => r.slot === "ring")).toBe(true);
    expect(rows.filter((r) => itemMatches(r, f({ slot: "material" }))).every((r) => r.category === "material")).toBe(true);
    const mage = rows.filter((r) => itemMatches(r, f({ cls: "Mage" })));
    expect(mage.every((r) => r.allClasses || r.classes.includes("Mage"))).toBe(true);
    expect(mage.some((r) => r.base === "sword2h")).toBe(false);
    expect(rows.filter((r) => itemMatches(r, f({ lv: [20, 25] }))).every((r) => r.level >= 20 && r.level <= 25)).toBe(true);
    expect(rows.filter((r) => itemMatches(r, f({ q: "miecz dwureczny" }))).length).toBeGreaterThan(0);
  });

  it("parses and serializes the URL both ways", () => {
    const text = "?q=miecz&r=unique%2Cmythic&slot=weapon&cls=Warrior&lv=10-40&sort=name&sel=sword2h_35&all=1&page=2";
    const parsed = parseItemFilters(text, { rarities: order });
    expect(parsed).toEqual({ q: "miecz", rarities: ["unique", "mythic"], slot: "weapon", cls: "Warrior", lv: [10, 40], sort: "name", sel: "sword2h_35", all: true, page: 2 });
    expect(serializeItemFilters(parsed)).toBe(text);
    expect(serializeItemFilters(parseItemFilters(""))).toBe("");
    expect(parseItemFilters("?r=gold&lv=50-10&sort=up", { rarities: order })).toEqual(f({}));
  });

  it("main stat: weapon damage, armor, else the first base stat", () => {
    expect(mainStat(itemDetail("sword2h_35")!, "common", "pl")?.key).toBe("dmg");
    const armor = items().find((i) => i.slot === "armor" && i.tier === 30)!;
    expect(mainStat(itemDetail(armor.id)!, "common", "pl")?.key).toBe("armor");
  });

  it("keeps the boss items segment apart from item ids", () => {
    const ids = new Set(items().map((i) => i.id));
    expect(ids.has(ROUTES.bossItems.pl.split("/")[1])).toBe(false);
    expect(ids.has(ROUTES.bossItems.en.split("/")[1])).toBe(false);
  });
});
