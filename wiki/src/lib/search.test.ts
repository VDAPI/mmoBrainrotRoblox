import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { highlight, normalize, prepare, search } from "./search";

describe("search", () => {
  it("normalizes like Logic/MapSearch", () => {
    expect(normalize("Szepczące Łąki!")).toBe("szepczace laki");
    const data = JSON.parse(readFileSync(join(process.cwd(), "src", "data", "search.json"), "utf8"));
    for (const v of data.vectors as { input: string; output: string }[]) {
      expect(normalize(v.input), JSON.stringify(v.input)).toBe(v.output);
    }
  });

  it("finds Polish names without Polish letters, in MapSearch order", () => {
    const index = prepare([
      { id: "a", texts: ["Szepczące Łąki"] },
      { id: "b", texts: ["Polana Królików", "łąki"] },
      { id: "c", texts: ["Lakier"] },
    ]);
    // "Lakier": label starts with the query (+1); ties by label: "polana..." before "szepczace...".
    expect(search(index, "laki").map((e) => e.id)).toEqual(["c", "b", "a"]);
    expect(search(index, "")).toEqual([]);
    expect(search(index, "laki xyz")).toEqual([]);
  });

  it("highlights matches in text with Polish letters", () => {
    const parts = highlight("Szepczące Łąki", "laki");
    expect(parts).toEqual([
      { text: "Szepczące ", match: false },
      { text: "Łąki", match: true },
    ]);
    expect(highlight("Popielny Kamień", "popiel")[0]).toEqual({ text: "Popiel", match: true });
  });
});
