// The committed renders match tools/wiki-renders/manifest.json: every output exists (with its -128 thumbnail) and
// public/img/mobs has no .webp outside the manifest. Passes without a manifest when the folder is empty.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { MOBS_DIR, renderFiles } from "./renders";

interface Manifest {
  rendererVersion: number;
  files: Record<string, { hash: string; id: string; kind: string; variant: string; outputs: string[] }>;
}

const path = join(process.cwd(), "..", "tools", "wiki-renders", "manifest.json");

describe("renders manifest", () => {
  it("matches the files on disk", () => {
    const onDisk = renderFiles(MOBS_DIR);
    if (!existsSync(path)) {
      expect(onDisk.size).toBe(0);
      return;
    }
    const manifest = JSON.parse(readFileSync(path, "utf8")) as Manifest;
    const listed = new Set<string>();
    for (const [file, record] of Object.entries(manifest.files)) {
      expect(record.outputs).toContain(`${file}.webp`);
      expect(record.outputs).toContain(`${file}-128.webp`);
      for (const out of record.outputs) {
        expect(onDisk.has(out), out).toBe(true);
        listed.add(out);
      }
    }
    for (const f of onDisk) expect(listed.has(f), `${f} is not in the manifest`).toBe(true);
  });
});
