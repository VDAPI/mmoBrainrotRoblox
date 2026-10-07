// npm run renders (S38): monster, boss and pet renders for the wiki. Dumps the looks with Lune
// (tools/lookdump.luau --wiki), then runs tools/wiki-renders/render.py with Python 3.10+ (numpy, Pillow with WebP).
// Extra arguments go to render.py (npm run renders -- --only wolf --force). `npm run renders:test` runs the Python
// unit tests. Python is never needed by the build or `npm run check`: missing images fall back to the placeholder.
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pickFeaturedItem, pickHeroBoss } from "../src/lib/featured.ts";
import { root, runLune } from "./lib/run.mjs";

const PROBE = "import sys, numpy, PIL; from PIL import features; sys.exit(0 if sys.version_info >= (3, 10) and features.check('webp') else 3)";

function findPython() {
  const candidates = process.platform === "win32" ? [["py", "-3"], ["python"], ["python3"]] : [["python3"], ["python"]];
  for (const [cmd, ...pre] of candidates) {
    const r = spawnSync(cmd, [...pre, "-c", PROBE], { cwd: root, stdio: "ignore" });
    if (!r.error && r.status === 0) return [cmd, ...pre];
  }
  return null;
}

const py = findPython();
if (!py) {
  console.error(
    [
      "Brak Pythona 3.10+ z numpy i Pillow (WebP). (Python 3.10+ with numpy and Pillow with WebP not found.)",
      "  winget install Python.Python.3.12",
      "  (nowy terminal / new terminal)",
      "  py -3 -m pip install -r tools/wiki-renders/requirements.txt",
      "  cd wiki && npm run renders",
    ].join("\n"),
  );
  process.exit(1);
}

const run = (args) => {
  const r = spawnSync(py[0], [...py.slice(1), ...args], { cwd: root, stdio: "inherit" });
  if (r.error || r.status !== 0) process.exit(r.status ?? 1);
};

if (process.argv[2] === "--test") {
  run(["-m", "unittest", "discover", "-s", "tools/wiki-renders/tests", "-t", "tools/wiki-renders"]);
  process.exit(0);
}

const read = (name) => JSON.parse(readFileSync(join(root, "wiki", "src", "data", `${name}.json`), "utf8"));
const heroItem = pickFeaturedItem(read("items").items, read("rarities").rarities);
const heroBoss = pickHeroBoss(read("bosses").bosses, heroItem);

runLune("tools/lookdump.luau", ["--wiki", "tools/wiki-renders/out/looks.json"]);
run([
  "tools/wiki-renders/render.py",
  "--looks", "tools/wiki-renders/out/looks.json",
  "--out", "wiki/public/img/mobs",
  "--manifest", "tools/wiki-renders/manifest.json",
  "--sheet",
  "--og",
  "--og-boss", heroBoss?.id ?? "",
  ...process.argv.slice(2),
]);
