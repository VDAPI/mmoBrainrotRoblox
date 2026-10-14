import { describe, expect, it } from "vitest";
import { load } from "./data";
import { chapterHref, mechanicsHref, guideHref, npcHref, questHref } from "./links";
import { arcQuests, bossQuests, chapters, contractsByMap, mainChapters, mainQuests, neighboursOf, npcLabel, npcName, questRegion, sideByLand, sideGroups, sideOrdered, weeklyTemplates } from "./quests";
import { contentEntry } from "./content";

describe("quests", () => {
  it("keeps the main chain in the game's order and groups it by chapter without reordering (S109)", () => {
    const chain = mainQuests();
    expect(chain.map((q) => q.order)).toEqual([...chain].map((q) => q.order).sort((a, b) => a - b));
    const groups = mainChapters();
    expect(groups.flatMap((g) => g.quests.map((q) => q.id))).toEqual(chain.map((q) => q.id));
    expect(groups.map((g) => g.chapter.n)).toEqual(chapters().map((c) => c.n));
    expect(groups.length).toBe(load("quests").chapters.length);
    for (const g of groups) {
      expect(["city", "region"]).toContain(load("maps").maps.find((m) => m.id === g.chapter.map)?.kind);
      for (const q of g.quests) expect(q.level >= g.chapter.from && q.level <= g.chapter.to).toBe(true);
    }
    expect(chapterHref("pl", 2)).toMatch(/#chapter-2$/);
  });

  it("links previous and next in the chain within a chapter; a main quest keeps its own page", () => {
    for (const g of mainChapters()) {
      expect(neighboursOf(g.quests[0].id).prev).toBeUndefined();
      if (g.quests.length > 1) expect(neighboursOf(g.quests[0].id).next?.id).toBe(g.quests[1].id);
      expect(neighboursOf(g.quests[g.quests.length - 1].id).next).toBeUndefined();
    }
    const first = mainQuests()[0];
    expect(questHref("pl", first.id)).toBe(`/pl/zadania/${first.id}/`);
  });

  it("gives every hunting contract once, the boss quests and the weekly templates (S109)", () => {
    const contracts = contractsByMap().flatMap((g) => g.contracts);
    expect(contracts.length).toBe(load("quests").contracts.max);
    expect(new Set(contracts.map((c) => c.level)).size).toBe(contracts.length);
    expect(bossQuests().length).toBe(load("quests").bossQuests.length);
    expect(weeklyTemplates().length).toBeGreaterThan(0);
    const lands = sideByLand();
    expect(lands.reduce((n, l) => n + l.count, 0)).toBe(load("quests").side.length);
    for (const l of lands) expect(l.arcs).toBeGreaterThan(0);
  });

  it("orders side quests after their requirements and keeps arcs together", () => {
    const order = sideOrdered();
    const at = new Map(order.map((q, i) => [q.id, i]));
    for (const q of order) for (const r of q.requires) if (at.has(r)) expect(at.get(r)!).toBeLessThan(at.get(q.id)!);
    expect(sideGroups().flatMap((g) => g.quests).length).toBe(load("quests").side.length);
    for (const q of order) {
      const arc = arcQuests(q.arc);
      const i = arc.findIndex((x) => x.id === q.id);
      expect(neighboursOf(q.id).next?.id).toBe(arc[i + 1]?.id);
    }
  });

  it("names every giver and turn-in NPC and links or knowingly leaves them", () => {
    for (const q of [...load("quests").main, ...load("quests").side]) {
      for (const id of [q.giver, q.turnIn]) {
        expect(npcName(id, "pl")).not.toBe(id);
        expect(npcLabel(id, "en")).not.toBe("");
        const href = npcHref("pl", id);
        expect(href === null || href.startsWith("/pl/")).toBe(true);
      }
      expect(questRegion(q)).toBeTruthy();
    }
  });

  it("drops the role when the name already starts with it", () => {
    const npc = load("npcs").npcs.find((n) => n.role && n.name.pl.toLowerCase().startsWith(n.role.pl.split(" ")[0].toLowerCase()));
    if (npc) expect(npcLabel(npc.id, "pl")).toBe(npc.name.pl);
  });
});

describe("links", () => {
  it("gives null for a missing article key", () => {
    expect(mechanicsHref("pl", "no-such-topic")).toBeNull();
    expect(guideHref("pl", "no-such-guide")).toBeNull();
  });

  it("links a written topic by its key in each language", () => {
    const death = contentEntry("mechanics", "pl", "death");
    if (death) expect(mechanicsHref("pl", "death")).toBe(`/pl/mechaniki/${death.slug}/`);
  });

  it("sends city NPCs to the city topic once it exists, otherwise to the map", () => {
    const npc = load("npcs").npcs.find((n) => n.map === "city" && !n.decoration)!;
    const href = npcHref("pl", npc.id)!;
    if (contentEntry("mechanics", "pl", "city")) expect(href).toMatch(new RegExp(`#npc-${npc.id}$`));
    else expect(href).toMatch(/^\/pl\/mapa\/\?m=city/);
    const outside = load("npcs").npcs.find((n) => n.map !== "city")!;
    expect(npcHref("en", outside.id)).toMatch(/^\/en\/map\//);
  });
});

describe("city (S43)", () => {
  it("gives every city NPC a card on the city topic and links it there", async () => {
    const { cityNpcs } = await import("./city");
    const cards = new Set(cityNpcs().map((n) => n.id));
    const city = contentEntry("mechanics", "pl", "city");
    expect(city).toBeDefined();
    for (const n of load("npcs").npcs.filter((x) => x.map === "city" && !x.decoration)) {
      expect(cards.has(n.id)).toBe(true);
      expect(npcHref("pl", n.id)).toBe(`/pl/mechaniki/${city!.slug}/#npc-${n.id}`);
    }
  });
});
