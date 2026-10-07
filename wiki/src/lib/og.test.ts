import { describe, expect, it } from "vitest";
import { fillConsts } from "./bossnotes";
import { bosses, monsters } from "./data";
import { ogManifest } from "./og";

describe("share images", () => {
  const list = ogManifest();

  it("has an entry for every monster and boss in both languages, with unique paths", () => {
    for (const lang of ["pl", "en"]) {
      for (const m of monsters()) expect(list.some((e) => e.out === `img/og/${lang}/monster/${m.id}.jpg`)).toBe(true);
      for (const b of bosses()) expect(list.some((e) => e.out === `img/og/${lang}/boss/${b.id}.jpg`)).toBe(true);
      expect(list.some((e) => e.out === `img/og/${lang}/bestiary.jpg`)).toBe(true);
    }
    expect(new Set(list.map((e) => e.out)).size).toBe(list.length);
    expect(list.every((e) => e.title.length > 0 && /^#[0-9A-Fa-f]{6}$/.test(e.accent))).toBe(true);
  });

  it("fills script constants and fails on a missing one", () => {
    expect(fillConsts("shrinks from {SAFE_START} to {SAFE_END} studs", { SAFE_START: 50, SAFE_END: 20 }, "en")).toBe("shrinks from 50 to 20 studs");
    expect(fillConsts("{TICK} s", { TICK: 1.5 }, "pl")).toBe("1,5 s");
    expect(() => fillConsts("{NOPE}", {}, "pl")).toThrow(/NOPE/);
    const azgor = bosses().find((b) => b.id === "azgor")!;
    expect(fillConsts("{SAFE_START}", azgor.scriptConsts, "pl")).toBe("50");
  });
});
