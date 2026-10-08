import { describe, expect, it } from "vitest";
import { load } from "./data";
import { mechanicsHref, guideHref, npcHref } from "./links";
import { arcQuests, mainGroups, mainQuests, neighboursOf, npcLabel, npcName, questRegion, sideGroups, sideOrdered } from "./quests";
import { contentEntry } from "./content";

describe("quests", () => {
  it("keeps the main chain in the game's order and groups it by region without reordering", () => {
    const chain = mainQuests();
    expect(chain.map((q) => q.order)).toEqual([...chain].map((q) => q.order).sort((a, b) => a - b));
    expect(mainGroups().flatMap((g) => g.quests.map((q) => q.id))).toEqual(chain.map((q) => q.id));
    for (const g of mainGroups()) expect(["city", "region"]).toContain(load("maps").maps.find((m) => m.id === g.region)?.kind);
  });

  it("links previous and next in the chain", () => {
    const chain = mainQuests();
    expect(neighboursOf(chain[0].id).prev).toBeUndefined();
    expect(neighboursOf(chain[0].id).next?.id).toBe(chain[1].id);
    expect(neighboursOf(chain[chain.length - 1].id).next).toBeUndefined();
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
