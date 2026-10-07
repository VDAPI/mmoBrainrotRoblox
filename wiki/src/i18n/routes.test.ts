import { describe, expect, it } from "vitest";
import { alternate, href, ROUTES, type RouteKey } from "./routes";

// docs/WIKI.md §4
const TABLE: Record<string, [string, string]> = {
  home: ["/pl/", "/en/"],
  items: ["/pl/przedmioty/", "/en/items/"],
  bestiary: ["/pl/bestiariusz/", "/en/bestiary/"],
  bosses: ["/pl/bossy/", "/en/bosses/"],
  classes: ["/pl/klasy/", "/en/classes/"],
  map: ["/pl/mapa/", "/en/map/"],
  regions: ["/pl/krainy/", "/en/regions/"],
  upgrading: ["/pl/ulepszanie/", "/en/upgrading/"],
  crafting: ["/pl/rzemioslo/", "/en/crafting/"],
  quests: ["/pl/zadania/", "/en/quests/"],
  mechanics: ["/pl/mechaniki/", "/en/mechanics/"],
  guides: ["/pl/poradniki/", "/en/guides/"],
  search: ["/pl/szukaj/", "/en/search/"],
  updates: ["/pl/aktualizacje/", "/en/updates/"],
  styleguide: ["/pl/styleguide/", "/en/styleguide/"],
};

describe("routes", () => {
  it("builds the addresses of the table for every key", () => {
    for (const key of Object.keys(ROUTES) as RouteKey[]) {
      const [pl, en] = TABLE[key];
      expect(href("pl", key)).toBe(pl);
      expect(href("en", key)).toBe(en);
      expect(alternate(pl)).toBe(en);
      expect(alternate(en)).toBe(pl);
    }
  });

  it("keeps ids (also their case) and maps nested paths", () => {
    expect(href("pl", "classes", "Mage")).toBe("/pl/klasy/Mage/");
    expect(href("en", "regions", "meadows", "meadows_wolfhills")).toBe("/en/regions/meadows/meadows_wolfhills/");
    expect(alternate("/pl/krainy/meadows/meadows_wolfhills/")).toBe("/en/regions/meadows/meadows_wolfhills/");
    expect(alternate("/pl/nie-ma/")).toBe("/en/");
    expect(alternate("/en/404/")).toBe("/pl/404/");
  });
});
