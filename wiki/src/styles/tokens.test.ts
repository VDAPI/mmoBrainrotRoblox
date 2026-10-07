import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

// tokens.css / components.css are 1:1 with wiki/design/vaelthorn.css (S36), except the mock-up rarity and element
// tokens and modifiers that tokens.data.css (game data) replaces.
const design = readFileSync(join(process.cwd(), "design", "vaelthorn.css"), "utf8");
const tokens = readFileSync(join(process.cwd(), "src", "styles", "tokens.css"), "utf8");
const components = readFileSync(join(process.cwd(), "src", "styles", "components.css"), "utf8");
const dataTokens = readFileSync(join(process.cwd(), "src", "styles", "tokens.data.css"), "utf8");

const MOCKUP_ONLY = /^--vw-(r-(common|uncommon|rare|epic|legendary|mythic)|glow-(common|uncommon|rare|epic|legendary|mythic)|el-(fire|frost|shadow|nature))$/;

// Declarations per block: ":root", "[data-theme=\"light\"]" and media blocks, keyed by their header.
function declarations(css: string): Map<string, string> {
  const out = new Map<string, string>();
  const re = /(--vw-[\w-]+)\s*:\s*([^;]+);/g;
  let block = "";
  let depth = 0;
  for (const line of css.split("\n")) {
    if (depth === 0 && line.includes("{")) block = line.split("{")[0].trim();
    for (const m of line.matchAll(re)) out.set(`${block.replace(':root, [data-theme="dark"]', ":root")}|${m[1]}`, m[2].trim());
    depth += (line.match(/{/g) ?? []).length - (line.match(/}/g) ?? []).length;
    if (depth === 0) block = depth === 0 && !line.includes("{") ? block : block;
  }
  return out;
}

describe("design tokens", () => {
  const ours = declarations(tokens);
  const defined = new Set([...dataTokens.matchAll(/(--vw-[\w-]+)\s*:/g)].map((m) => m[1]));

  it("every token of the design system exists with the same value", () => {
    const sectionOne = design.split("/* ---------- 2. BAZA")[0];
    for (const [key, value] of declarations(sectionOne)) {
      const name = key.split("|")[1];
      if (MOCKUP_ONLY.test(name)) continue;
      expect(ours.get(key), key).toBe(value);
    }
  });

  it("game data defines the rarity and element colours", () => {
    for (const name of ["--vw-r-common", "--vw-r-mythic", "--vw-glow-legendary", "--vw-el-fire", "--vw-zone-red"]) {
      expect(defined.has(name), name).toBe(true);
    }
    expect(dataTokens).toContain(':root, [data-theme="dark"]');
    expect(dataTokens).toContain('[data-theme="light"]');
  });

  it("keeps the radius tokens --vw-r-0/1/2/pill", () => {
    for (const name of ["--vw-r-0", "--vw-r-1", "--vw-r-2", "--vw-r-pill"]) expect(tokens).toContain(`${name}:`);
  });

  it("every component class of the design system is in components.css", () => {
    const classes = new Set([...design.matchAll(/\.(vw-[\w-]+)/g)].map((m) => m[1]));
    const removed = /^vw-rarity--(uncommon|rare|epic|legendary|mythic)$/;
    for (const cls of classes) {
      if (removed.test(cls)) continue;
      expect(components.includes(`.${cls}`), cls).toBe(true);
    }
  });
});
