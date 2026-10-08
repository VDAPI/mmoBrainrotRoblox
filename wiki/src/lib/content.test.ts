// Written articles (S42/S43): PL/EN pairs, every MDX reference resolves, no game numbers typed by hand in prose.
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { ROUTES } from "../i18n/routes";
import { contentEntries, contentEntry, frontmatter, translateSlug, type Collection } from "./content";
import { getBoss, getItem, getMonster, load, rarityOf } from "./data";
import { questById } from "./quests";
import { resolveStat } from "./stat";
import { areaOf, caveOf, getMapInfo } from "./world";

const COLLECTIONS: Collection[] = ["mechanics", "guides"];
/** Keys allowed to exist in one language only (none today; list them in docs/WIKI.md "Niedokończone"). */
const SINGLE_LANGUAGE: string[] = [];

function body(file: string): string {
  return readFileSync(file, "utf8").replace(/^---[\s\S]*?---/, "");
}

const attrs = (src: string, tag: string, attr: string): string[] =>
  [...src.matchAll(new RegExp(`<${tag}\\b[^>]*?\\b${attr}="([^"]+)"`, "g"))].map((m) => m[1]);

/** Prose without headings, list numbers, components (with their attributes) and upgrade level names (+7). */
export function proseOf(src: string): string {
  return src
    .split(/\r?\n/)
    .filter((line) => !/^\s*#/.test(line))
    .map((line) => line.replace(/^\s*\d+\.\s/, ""))
    .join("\n")
    .replace(/<[^>]*>/g, " ")
    .replace(/\+\d+/g, " ");
}

describe("content", () => {
  it("parses frontmatter lines", () => {
    expect(frontmatter('---\ntitle: "A: b"\nkey: x\norder: 2\n---\nbody')).toEqual({ title: "A: b", key: "x", order: "2" });
  });

  for (const collection of COLLECTIONS) {
    const entries = contentEntries(collection);
    it(`${collection}: every article has a PL/EN pair with the same key`, () => {
      for (const e of entries) {
        if (SINGLE_LANGUAGE.includes(e.key)) continue;
        expect(e.key, e.file).not.toBe("");
        const other = contentEntry(collection, e.lang === "pl" ? "en" : "pl", e.key);
        expect(other, `${e.file}: no pair for key "${e.key}"`).toBeDefined();
        expect(translateSlug(collection, e.lang, e.slug)).toBe(other!.slug);
      }
      expect(new Set(entries.map((e) => `${e.lang}:${e.key}`)).size).toBe(entries.length);
    });

    it(`${collection}: every MDX reference resolves`, () => {
      const keybinds = new Set(load("mechanics").keybinds.map((k) => k.id));
      const npcs = new Set(load("npcs").npcs.map((n) => n.id));
      for (const e of entries) {
        const src = body(e.file);
        for (const p of attrs(src, "Stat", "path")) expect(() => resolveStat(p), `${e.file}: ${p}`).not.toThrow();
        for (const id of attrs(src, "Item", "id")) expect(getItem(id), `${e.file}: item ${id}`).toBeDefined();
        for (const id of attrs(src, "Monster", "id")) expect(getMonster(id) ?? getBoss(id), `${e.file}: monster ${id}`).toBeDefined();
        for (const id of attrs(src, "Quest", "id")) expect(questById(id), `${e.file}: quest ${id}`).toBeDefined();
        for (const id of attrs(src, "Npc", "id")) expect(npcs.has(id), `${e.file}: npc ${id}`).toBe(true);
        for (const id of attrs(src, "Region", "id")) expect(areaOf(id) ?? caveOf(id) ?? getMapInfo(id), `${e.file}: region ${id}`).toBeDefined();
        for (const id of attrs(src, "Region", "area")) expect(areaOf(id) ?? caveOf(id), `${e.file}: area ${id}`).toBeDefined();
        for (const id of attrs(src, "Rarity", "id")) expect(rarityOf(id), `${e.file}: rarity ${id}`).toBeDefined();
        for (const id of attrs(src, "Key", "action")) expect(keybinds.has(id), `${e.file}: key ${id}`).toBe(true);
        for (const to of attrs(src, "Link", "to")) expect(to in ROUTES, `${e.file}: link ${to}`).toBe(true);
        for (const m of src.matchAll(/<Link\s+to="(mechanics|guides)"\s+id="([^"]+)"/g)) {
          expect(contentEntry(m[1] as Collection, e.lang, m[2]), `${e.file}: ${m[1]} ${m[2]}`).toBeDefined();
        }
      }
    });

    it(`${collection}: no digits in the prose (numbers only through <Stat/>)`, () => {
      for (const e of entries) {
        const digits = proseOf(body(e.file)).match(/[^\s]*\d[^\s]*/g);
        expect(digits, `${e.file}: ${digits?.join(", ")}`).toBeNull();
      }
    });
  }

  it("an empty collection is fine", () => {
    expect(() => contentEntries("guides")).not.toThrow();
  });

  it("the prose filter keeps text and drops components and upgrade levels", () => {
    expect(proseOf('a <Stat path="x.y" /> b +7\n## H 2\nc')).not.toMatch(/\d/);
    expect(proseOf("wait 10 s")).toMatch(/\d/);
  });
});
