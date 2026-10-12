// npm run art (WIKI-GRAFIKA): the owner's pictures on the wiki. Reads his Graphics folder (1024 px originals; layout in
// its PORADNIK-GRAFIKA.md; `--src <dir>`, else VAELTHORN_GRAPHICS, else D:/Users/vdapi/Downloads/Graphics), keeps only
// pictures of published ids (scripts/lib/art-core.mjs RULES), writes WebP files to public/img/art/<kind>/<id>-<w>.webp
// and the manifest src/generated/art.json ({ version, entries: { "<kind>/<id>": { file, sizes, hash, mask? } } }).
// Item pictures (icon keys from art/icons/src, single layer) get a 256 px file for 2x screens of the 128 px item page
// icon; the 64 / 128 px item icons stay with `npm run icons` (atlases, like the game). Incremental by source hash.
// Without the folder (CI, other machines) nothing is built: entries of ids no longer published are removed with their
// files, the rest is kept. Like `npm run renders`: local only, outputs committed, the build never needs the originals.
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import sharp from "sharp";
import { root } from "./lib/run.mjs";
import budgets from "./budgets.config.mjs";
import { alphaBounds, ART_VERSION, cropBox, outputsOf, planArt, prunePublished, publishedIds, SKIP_DIRS } from "./lib/art-core.mjs";

const WIKI = join(root, "wiki");
const OUT = join(WIKI, "public", "img", "art");
const MANIFEST = join(WIKI, "src", "generated", "art.json");
const ICON_SRC = join(root, "art", "icons", "src");
const BUDGET = budgets.warn.artMb * 1024 * 1024; // one threshold with npm run check (budgets.mjs)

const argSrc = process.argv.indexOf("--src");
const SRC = argSrc > 0 ? process.argv[argSrc + 1] : (process.env.VAELTHORN_GRAPHICS ?? "D:/Users/vdapi/Downloads/Graphics");

const read = (name) => JSON.parse(readFileSync(join(WIKI, "src", "data", `${name}.json`), "utf8"));
const data = Object.fromEntries(["items", "classes", "skills", "elements", "mechanics", "quests", "npcs", "premium"].map((n) => [n, read(n)]));
const published = publishedIds(data);

function walk(dir, base = dir, out = []) {
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir).sort()) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) {
      if (!SKIP_DIRS.has(name)) walk(p, base, out);
    } else out.push(relative(base, p).replaceAll("\\", "/"));
  }
  return out;
}

// Owner's item pictures in the game: single-layer keys of art/icons/src ("eq/sword1h@10"); layered ones need tints.
const pictureKeys = new Set();
{
  const srcFiles = walk(ICON_SRC).filter((f) => f.endsWith(".png"));
  const layered = new Set(srcFiles.filter((f) => /\.(m|a)\.png$/.test(f)).map((f) => f.replace(/\.(m|a)\.png$/, "")));
  for (const f of srcFiles) {
    const key = f.replace(/\.png$/, "");
    if (!/\.(m|a)$/.test(key) && !layered.has(key)) pictureKeys.add(key);
  }
}

const old = existsSync(MANIFEST) ? JSON.parse(readFileSync(MANIFEST, "utf8")) : { version: ART_VERSION, entries: {} };
const sameVersion = old.version === ART_VERSION;
const stillPublished = (key) => !key.startsWith("item/") || pictureKeys.has(key.slice(5));
let entries = {};
let built = 0;
let kept = 0;
let unused = [];

if (!existsSync(SRC)) {
  console.log(`art: brak folderu grafik ${SRC}; tylko porządkuję manifest. (Graphics folder not found: pruning only)`);
  entries = Object.fromEntries(Object.entries(prunePublished(old.entries ?? {}, published)).filter(([key]) => stillPublished(key)));
} else {
  const files = walk(SRC).filter((f) => f.toLowerCase().endsWith(".png"));
  const plan = planArt(files, published, pictureKeys);
  unused = plan.unused;
  for (const e of plan.entries) {
    const bytes = readFileSync(join(SRC, e.source));
    const hash = createHash("sha256").update(`${ART_VERSION}:${e.fit}:${e.sizes.join(",")}:`).update(bytes).digest("hex").slice(0, 16);
    const record = { file: e.file, sizes: e.sizes, hash, ...(e.mask ? { mask: true } : {}) };
    entries[e.key] = record;
    const outs = outputsOf(e).map((f) => join(OUT, f));
    if (sameVersion && old.entries?.[e.key]?.hash === hash && outs.every((p) => existsSync(p))) {
      kept++;
      continue;
    }
    const img = sharp(bytes).ensureAlpha();
    const { data: raw, info } = await img.raw().toBuffer({ resolveWithObject: true });
    const box = cropBox(e.fit, info.width, info.height, e.fit === "trim" ? alphaBounds(raw, info.width, info.height) : null);
    // Pad with transparency so a square reaching past the picture keeps the picture centred.
    const pad = Math.max(0, -box.left, -box.top, box.left + box.side - info.width, box.top + box.side - info.height);
    const padded =
      pad > 0
        ? await sharp(raw, { raw: info })
            .extend({ top: pad, bottom: pad, left: pad, right: pad, background: { r: 0, g: 0, b: 0, alpha: 0 } })
            .raw()
            .toBuffer({ resolveWithObject: true })
        : { data: raw, info };
    const square = await sharp(padded.data, { raw: padded.info })
      .extract({ left: box.left + pad, top: box.top + pad, width: box.side, height: box.side })
      .raw()
      .toBuffer({ resolveWithObject: true });
    mkdirSync(dirname(outs[0]), { recursive: true });
    for (const [i, w] of e.sizes.entries()) {
      await sharp(square.data, { raw: square.info })
        .resize(w, w, { kernel: "lanczos3" })
        .sharpen({ sigma: 0.5 })
        .webp({ quality: e.kind === "portrait" ? 80 : 86, alphaQuality: 90, effort: 6 })
        .toFile(outs[i]);
    }
    built++;
  }
}

// Remove every file of public/img/art that no entry wants (also files of ids hidden since the last run).
const wanted = new Set(Object.values(entries).flatMap((e) => e.sizes.map((w) => `${e.file}-${w}.webp`)));
let removed = 0;
for (const f of walk(OUT)) {
  if (!wanted.has(f)) {
    rmSync(join(OUT, f));
    removed++;
  }
}
for (const dir of existsSync(OUT) ? readdirSync(OUT) : []) {
  const p = join(OUT, dir);
  if (statSync(p).isDirectory() && readdirSync(p).length === 0) rmSync(p, { recursive: true });
}
for (const f of wanted) if (!existsSync(join(OUT, f))) console.warn(`art: brak pliku ${f} (missing file; run with the Graphics folder)`);

mkdirSync(dirname(MANIFEST), { recursive: true });
const sorted = Object.fromEntries(Object.entries(entries).sort(([a], [b]) => (a < b ? -1 : 1)));
writeFileSync(MANIFEST, `${JSON.stringify({ version: ART_VERSION, entries: sorted }, null, 2)}\n`);

const byKind = {};
for (const key of Object.keys(sorted)) {
  const kind = key.slice(0, key.indexOf("/"));
  byKind[kind] = (byKind[kind] ?? 0) + 1;
}
const size = walk(OUT).reduce((n, f) => n + statSync(join(OUT, f)).size, 0);
console.log(`art: ${Object.keys(sorted).length} obrazków (${built} zbudowano, ${kept} bez zmian, ${removed} plików usunięto), ${wanted.size} plików, ${(size / 1024 / 1024).toFixed(2)} MB`);
console.log(`art: ${Object.entries(byKind).map(([k, n]) => `${k} ${n}`).join(", ")}`);
if (size > BUDGET) console.warn(`art: folder ponad budżet ${budgets.warn.artMb} MB`);
if (unused.length > 0) {
  const groups = {};
  for (const f of unused) {
    const dir = f.slice(0, f.lastIndexOf("/"));
    groups[dir] = (groups[dir] ?? 0) + 1;
  }
  console.log(`art: bez miejsca na wiki (unused) ${unused.length}: ${Object.entries(groups).map(([d, n]) => `${d} ${n}`).join(", ")}`);
  if (process.argv.includes("--unused")) for (const f of unused) console.log(`  ${f}`);
}
