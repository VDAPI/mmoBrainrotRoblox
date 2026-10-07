import { describe, expect, it } from "vitest";
import { en } from "../i18n/en";
import { pl } from "../i18n/pl";
import { bestiaryEntries, occurringVariants, regionTree } from "./bestiary";
import { DEFAULT_FILTERS, levelBands, matches, parseFilters, serializeFilters, sortEntries, type Filters } from "./bestiary-filters";
import { bosses, load, monsters } from "./data";

const entries = bestiaryEntries("pl");
const f = (patch: Partial<Filters>): Filters => ({ ...DEFAULT_FILTERS, types: [], ...patch });

describe("bestiary", () => {
  it("has one entry per occurring variant and one per boss", () => {
    const variants = monsters().reduce((n, m) => n + occurringVariants(m).length, 0);
    expect(entries.length).toBe(variants + bosses().length);
    expect(new Set(entries.map((e) => `${e.id}:${e.variant}`)).size).toBe(entries.length);
  });

  it("parses and serializes the filters both ways and ignores junk", () => {
    const text = "?region=meadows_cave&lv=21-40&type=elite%2Celite2&q=wilk&sort=-level&view=table&page=2";
    const parsed = parseFilters(text);
    expect(parsed).toEqual({ region: "meadows_cave", lv: [21, 40], types: ["elite", "elite2"], q: "wilk", sort: "-level", view: "table", page: 2 });
    expect(serializeFilters(parsed)).toBe(text);
    expect(parseFilters(serializeFilters(parsed))).toEqual(parsed);
    expect(serializeFilters(parseFilters(""))).toBe("");
    const junk = parseFilters("?region=<x>&lv=40-21&type=dragon,boss&sort=up&view=grid&page=-3", { regions: ["meadows"] });
    expect(junk).toEqual({ ...DEFAULT_FILTERS, types: ["boss"] });
    expect(parseFilters("?region=nowhere", { regions: ["meadows"] }).region).toBeNull();
  });

  it("a region includes its caves, a cave only itself", () => {
    const inMeadows = entries.filter((e) => matches(e, f({ region: "meadows" })));
    const inCave = entries.filter((e) => matches(e, f({ region: "meadows_cave" })));
    expect(inCave.length).toBeGreaterThan(0);
    expect(inCave.every((e) => inMeadows.includes(e))).toBe(true);
    expect(inMeadows.length).toBeGreaterThan(inCave.length);
    expect(inMeadows.some((e) => e.id === "grimrok")).toBe(true);
    expect(regionTree("pl").filter((r) => r.cave).some((r) => r.id === "meadows_cave")).toBe(true);
  });

  it("matches level bands by overlap", () => {
    const e = entries.find((x) => x.levelMin < 20 && x.levelMax > 20)!;
    expect(matches(e, f({ lv: [1, 20] }))).toBe(true);
    expect(matches(e, f({ lv: [21, 40] }))).toBe(true);
    expect(matches(e, f({ lv: [41, 60] }))).toBe(false);
    expect(levelBands(100)).toEqual([[1, 20], [21, 40], [41, 60], [61, 80], [81, 100]]);
  });

  it("finds names without Polish letters", () => {
    expect(entries.filter((e) => matches(e, f({ q: "wilk" }))).some((e) => e.id === "wolf")).toBe(true);
    expect(entries.filter((e) => matches(e, f({ q: "krolik" }))).some((e) => e.id === "rabbit")).toBe(true);
    expect(entries.filter((e) => matches(e, f({ q: "KRÓLIK" }))).some((e) => e.id === "rabbit")).toBe(true);
  });

  it("sorts stably by level, reverse level and name", () => {
    const up = sortEntries(entries, "level", "pl");
    for (let i = 1; i < up.length; i++) expect(up[i].levelMin).toBeGreaterThanOrEqual(up[i - 1].levelMin);
    const down = sortEntries(entries, "-level", "pl");
    expect(down[0].levelMax).toBe(Math.max(...entries.map((e) => e.levelMax)));
    const byName = sortEntries(entries, "name", "pl");
    expect(sortEntries(byName, "name", "pl")).toEqual(byName);
    const collator = new Intl.Collator("pl");
    for (let i = 1; i < byName.length; i++) expect(collator.compare(byName[i - 1].name, byName[i].name)).toBeLessThanOrEqual(0);
  });

  it("gives every family a Polish and English label", () => {
    for (const m of load("monsters").monsters) {
      if (!m.family) continue;
      expect(pl[`family.${m.family}` as keyof typeof pl]).toBeTruthy();
      expect(en[`family.${m.family}` as keyof typeof en]).toBeTruthy();
    }
  });
});
