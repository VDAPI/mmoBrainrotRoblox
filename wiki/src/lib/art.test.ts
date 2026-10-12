// WIKI-GRAFIKA: the committed owner's pictures match src/generated/art.json (npm run art): every entry has all its
// files, public/img/art has nothing outside the manifest, and every entry is a published id — a picture of a hidden
// skill, path, item or anything else never reaches the site (after hiding something, `npm run art` prunes it).
import { existsSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";
import { publishedIds } from "../../scripts/lib/art-core.mjs";
import { ART_DIR, artFor, artImg, artManifest, artMask, itemHd } from "./art";
import { items, load } from "./data";
import { iconFor } from "./icons";
import { iconSources } from "./item-model";

function walk(dir: string, out: string[] = []): string[] {
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(relative(ART_DIR, p).replaceAll("\\", "/"));
  }
  return out;
}

const published = publishedIds({
  items: load("items"),
  classes: load("classes"),
  skills: load("skills"),
  elements: load("elements"),
  mechanics: load("mechanics"),
  quests: load("quests"),
  npcs: load("npcs"),
  premium: load("premium"),
});

describe("owner's pictures (art.json)", () => {
  const entries = Object.entries(artManifest().entries);

  it("lists only published ids, each with all its files", () => {
    for (const [key, e] of entries) {
      const kind = key.slice(0, key.indexOf("/"));
      const id = key.slice(kind.length + 1);
      expect((published as Record<string, Set<string>>)[kind]?.has(id), `${key} is not published`).toBe(true);
      for (const w of e.sizes) expect(existsSync(join(ART_DIR, `${e.file}-${w}.webp`)), `${e.file}-${w}.webp`).toBe(true);
    }
  });

  it("has no file outside the manifest", () => {
    const listed = new Set(entries.flatMap(([, e]) => e.sizes.map((w) => `${e.file}-${w}.webp`)));
    for (const f of walk(ART_DIR)) expect(listed.has(f), `${f} is not in art.json`).toBe(true);
  });

  it("never has a picture of a skill that is not published", () => {
    const skillIds = new Set(load("skills").skills.map((s) => s.id));
    for (const [key] of entries) if (key.startsWith("skill/")) expect(skillIds.has(key.slice(6))).toBe(true);
  });

  it("gives URLs, <img> attributes and masks by kind", () => {
    if (entries.length === 0) return; // npm run art never ran: glyphs everywhere
    const icon = entries.find(([, e]) => !e.mask && e.sizes.includes(64));
    if (icon) {
      const [key] = icon;
      const kind = key.slice(0, key.indexOf("/")) as Parameters<typeof artFor>[0];
      const id = key.slice(kind.length + 1);
      expect(artFor(kind, id)).toBe(`/img/art/${icon[1].file}`);
      const img = artImg(kind, id, 28)!;
      expect(img.src).toBe(`/img/art/${icon[1].file}-64.webp`);
      expect(img.srcset).toContain("128w");
      expect(artMask(kind, id)).toBeNull();
    }
    const mask = entries.find(([, e]) => e.mask);
    if (mask) {
      const [key] = mask;
      const kind = key.slice(0, key.indexOf("/")) as Parameters<typeof artFor>[0];
      expect(artMask(kind, key.slice(kind.length + 1))).toMatch(/^\/img\/art\/.+-64\.webp$/);
    }
    expect(artFor("skill", "no_such_skill")).toBeNull();
    expect(artImg("portrait", null, 300)).toBeNull();
  });

  it("has a 256 px file for item pictures, used for 2x screens above 64 px", () => {
    const withHd = items().filter((i) => i.iconKey && itemHd(i.iconKey));
    if (withHd.length === 0) return;
    for (const item of withHd) expect(iconFor(item.id), item.id).not.toBeNull();
    const hd = itemHd(withHd[0].iconKey)!;
    expect(iconSources("/img/items/x", 128, hd)).toEqual({ src: "/img/items/x-128.webp", srcset: `/img/items/x-128.webp 1x, ${hd} 2x` });
    expect(iconSources("/img/items/x", 40, hd)?.srcset).toBe("/img/items/x-64.webp 1x, /img/items/x-128.webp 2x");
  });
});
