import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { prepare, search } from "./search";

// The same results in the same order as Logic/MapSearch (vectors from tools/WikiData/Places.luau).
const KIND_RANK: Record<string, number> = { npc: 1, map: 2, cave: 3, area: 4, boss: 5, monster: 6, node: 7 };

describe("map search", () => {
  const data = JSON.parse(readFileSync(join(process.cwd(), "src", "data", "mapsearch.json"), "utf8"));
  for (const v of data.vectors as { lang: "pl" | "en"; query: string; results: string[] }[]) {
    it(`${v.lang}: ${v.query}`, () => {
      const index = prepare(
        (data[v.lang] as { kind: string; id: string; texts: string[] }[]).map((e) => ({ ...e, id: e.id, rank: KIND_RANK[e.kind] ?? 9 })),
      );
      const got = search(index, v.query, data.limit).map((e) => `${e.kind}:${e.id}`);
      expect(got).toEqual(v.results);
    });
  }
});
