// npm run data: regenerates wiki/src/data with the game's exporter (lune run tools/wikidump.luau) and the map SVGs in
// wiki/public/img/maps (lune run tools/wikimap.luau, S37), both run from the repository root. Extra arguments go to
// both tools (e.g. npm run data -- --check).
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const extra = process.argv.slice(2);
for (const tool of ["tools/wikidump.luau", "tools/wikimap.luau"]) {
  const args = tool.endsWith("wikimap.luau") ? extra.filter((a) => a === "--check") : extra;
  const result = spawnSync("lune", ["run", tool, ...args], { cwd: root, stdio: "inherit", shell: process.platform === "win32" });
  if (result.error || result.status === null) {
    console.error("Nie znaleziono `lune`. Uruchom `rokit install` w katalogu repozytorium. (lune not found: run `rokit install` in the repository root.)");
    process.exit(1);
  }
  if (result.status !== 0) {
    process.exit(result.status);
  }
}
