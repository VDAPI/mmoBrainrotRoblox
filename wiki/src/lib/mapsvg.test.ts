import { describe, expect, it } from "vitest";
import { cropViewBox, idsIn, inlineMap, loadMapSvg, parseViewBox } from "./mapsvg";

describe("mapsvg", () => {
  const svg = loadMapSvg("meadows");

  it("reads the viewBox of a generated map", () => {
    expect(parseViewBox(svg)).toEqual({ x: -800, y: -800, w: 1600, h: 1600 });
  });

  it("crops around bounds with padding, a minimum size and inside the map", () => {
    const full = parseViewBox(svg);
    const v = cropViewBox(full, { x1: -100, z1: -50, x2: 100, z2: 50 }, 420 / 260);
    expect(v.w / v.h).toBeCloseTo(420 / 260, 1);
    expect(v.w).toBeGreaterThanOrEqual(320);
    expect(v.x).toBeLessThanOrEqual(-100);
    expect(v.x + v.w).toBeGreaterThanOrEqual(100);
    const edge = cropViewBox(full, { x1: 760, z1: 760, x2: 790, z2: 790 }, 1);
    expect(edge.x + edge.w).toBeLessThanOrEqual(800);
    expect(edge.y + edge.h).toBeLessThanOrEqual(800);
  });

  it("highlights by id and dims the rest", () => {
    const out = inlineMap(svg, { highlight: ["area-meadows_wolfhills"] });
    expect(out).toMatch(/id="area-meadows_wolfhills"[^>]*class="m-area is-hl"/);
    expect(out).toContain("data-hl");
  });

  it("strips ids so two mini maps on one page never share one", () => {
    const a = inlineMap(svg, { highlight: ["area-meadows_wolfhills"], stripIds: true });
    const b = inlineMap(svg, { highlight: ["cave-meadows_cave"], stripIds: true });
    expect(idsIn(a + b)).toEqual([]);
    expect(a).toContain("is-hl");
    expect(b).toContain("is-hl");
  });
});
