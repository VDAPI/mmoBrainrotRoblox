// Shared helpers of the wiki scripts: the repository root and running Lune tools from it (npm run data, renders).
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");

/** Runs `lune run <tool> ...args` in the repository root; exits the process on failure. */
export function runLune(tool, args = []) {
  const result = spawnSync("lune", ["run", tool, ...args], { cwd: root, stdio: "inherit" });
  if (result.error || result.status === null) {
    console.error("Nie znaleziono `lune`. Uruchom `rokit install` w katalogu repozytorium. (lune not found: run `rokit install` in the repository root.)");
    process.exit(1);
  }
  if (result.status !== 0) {
    process.exit(result.status);
  }
}
