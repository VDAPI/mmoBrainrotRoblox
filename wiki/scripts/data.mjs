// npm run data: regenerates wiki/src/data with the game's exporter (lune run tools/wikidump.luau) and the map SVGs in
// wiki/public/img/maps (lune run tools/wikimap.luau, S37), both run from the repository root. Extra arguments go to
// both tools (e.g. npm run data -- --check).
import { runLune } from "./lib/run.mjs";

const extra = process.argv.slice(2);
for (const tool of ["tools/wikidump.luau", "tools/wikimap.luau"]) {
  runLune(tool, tool.endsWith("wikimap.luau") ? extra.filter((a) => a === "--check") : extra);
}
