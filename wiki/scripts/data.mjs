// npm run data: regenerates wiki/src/data with the game's exporter (lune run tools/wikidump.luau, run from the
// repository root). Extra arguments go to the exporter (e.g. npm run data -- --check).
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const result = spawnSync("lune", ["run", "tools/wikidump.luau", ...process.argv.slice(2)], { cwd: root, stdio: "inherit", shell: process.platform === "win32" });
if (result.error || result.status === null) {
  console.error("Nie znaleziono `lune`. Uruchom `rokit install` w katalogu repozytorium. (lune not found: run `rokit install` in the repository root.)");
  process.exit(1);
}
process.exit(result.status);
