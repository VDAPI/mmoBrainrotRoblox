// node scripts/stale-data.mjs (S44): after `npm run data`, are the generated files the same as the commit? In GitHub
// Actions a difference is a yellow warning ("Nieaktualne dane wiki") with the list in the step summary; locally a
// plain message. Always exits 0: the site is built from the fresh export anyway.
import { spawnSync } from "node:child_process";
import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { META, porcelainPaths, staleFiles } from "./lib/stale-core.mjs";
import { root } from "./lib/run.mjs";

const git = (args) => spawnSync("git", args, { cwd: root, encoding: "utf8" });
const status = git(["status", "--porcelain", "--untracked-files=all", "--", "wiki/src/data", "wiki/src/styles/tokens.data.css", "docs/PRZEDMIOTY.md", "wiki/public/img/maps", "wiki/src/generated"]);
if (status.status !== 0) {
  console.log("stale-data: git not available, skipped");
  process.exit(0);
}
const head = git(["show", `HEAD:${META}`]);
const metaHead = head.status === 0 ? head.stdout : null;
const metaNow = existsSync(join(root, META)) ? readFileSync(join(root, META), "utf8") : null;
const stale = staleFiles(porcelainPaths(status.stdout), metaHead, metaNow);

if (stale.length === 0) {
  console.log("stale-data: generated wiki files match the commit");
  process.exit(0);
}
const list = stale.join(", ");
if (process.env.GITHUB_ACTIONS === "true") {
  console.log(`::warning title=Nieaktualne dane wiki::${list}`);
  if (process.env.GITHUB_STEP_SUMMARY) {
    appendFileSync(
      process.env.GITHUB_STEP_SUMMARY,
      `### Nieaktualne dane wiki\n\nUruchom \`npm run data\` w \`wiki/\` i zrób commit. Zmienione pliki:\n\n${stale.map((f) => `- \`${f}\``).join("\n")}\n`,
    );
  }
} else {
  console.log(`stale-data: ${stale.length} generated files differ from the commit (run npm run data in wiki/ and commit):\n  ${stale.join("\n  ")}`);
}
process.exit(0);
