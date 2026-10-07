import { existsSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { iconFileName, iconJobs, multiplyTint } from "../../scripts/lib/item-icons-core.mjs";
import { items } from "./data";
import { iconManifest } from "./icons";

describe("item icons", () => {
  it("multiplies the colour on a pixel and keeps alpha", () => {
    const out: Buffer = multiplyTint(Buffer.from([128, 128, 128, 200]), "#FF8000");
    expect([...out]).toEqual([128, 64, 0, 200]);
  });

  it("names files deterministically from the key and the tints", () => {
    const layers = [{ image: 1, x: 0, y: 0, tint: "#B5ACA1" }, { image: 1, x: 128, y: 0 }];
    expect(iconFileName("eq/sword1h", layers)).toBe("eq-sword1h-b5aca1");
    expect(iconFileName("eq/sword1h", layers)).toBe(iconFileName("eq/sword1h", [...layers]));
  });

  it("has one file per unique look and a manifest entry for every item with layers", () => {
    const jobs: Map<string, { file: string }> = iconJobs(items());
    const files = new Set([...jobs.values()].map((j) => j.file));
    const manifest = iconManifest();
    if (Object.keys(manifest.files).length === 0) return; // no S35 atlases: glyphs only
    expect(new Set(Object.values(manifest.files)).size).toBe(files.size);
    for (const item of items()) if (item.layers?.length) expect(manifest.files[item.id]).toBeTruthy();
    for (const file of new Set(Object.values(manifest.files))) {
      expect(existsSync(join(process.cwd(), "public", "img", "items", `${file}-64.webp`))).toBe(true);
      expect(existsSync(join(process.cwd(), "public", "img", "items", `${file}-128.webp`))).toBe(true);
    }
  });
});
