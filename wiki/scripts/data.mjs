// npm run data: regenerates wiki/src/data with the game's exporter (lune run tools/wikidump.luau) and the map SVGs in
// wiki/public/img/maps (lune run tools/wikimap.luau, S37), both run from the repository root. Extra arguments go to
// both tools (e.g. npm run data -- --check). S40: then npm run icons.
import { spawnSync } from "node:child_process";
import { runLune } from "./lib/run.mjs";

const extra = process.argv.slice(2);
for (const tool of ["tools/wikidump.luau", "tools/wikimap.luau"]) {
  runLune(tool, tool.endsWith("wikimap.luau") ? extra.filter((a) => a === "--check") : extra);
}
// S40: item icons from the S35 atlases (no atlases = empty manifest, glyphs); skipped with --check.
if (!extra.includes("--check")) {
  const icons = spawnSync(process.execPath, ["scripts/item-icons.mjs"], { stdio: "inherit" });
  if (icons.status !== 0) process.exit(icons.status ?? 1);
}
