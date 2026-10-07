// npm run icons (S40): composes the item icons from the S35 atlases (art/icons/items_<n>.png) like the game draws them
// (layers in order, tinted layers multiplied by their colour, rarity never in the icon) into
// wiki/public/img/items/<file>-128.webp and -64.webp, and writes the manifest src/generated/item-icons.json
// ({ version, atlasHash, files: { "<itemId>[:<element>]": "<file>" } }). Incremental: with the same atlas hash an
// existing file is kept; files not in the manifest are deleted. --sheet also writes .shots/icons-sheet.png.
// Without the atlases (S35 not done) it writes an empty manifest and exits 0: the wiki shows glyphs.
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import sharp from "sharp";
import { root } from "./lib/run.mjs";
import { iconJobs, multiplyTint } from "./lib/item-icons-core.mjs";

const VERSION = 1;
const WIKI = join(root, "wiki");
const OUT = join(WIKI, "public", "img", "items");
const MANIFEST = join(WIKI, "src", "generated", "item-icons.json");
const BUDGET = 8 * 1024 * 1024;

const icons = JSON.parse(readFileSync(join(WIKI, "src", "data", "icons.json"), "utf8"));
const items = JSON.parse(readFileSync(join(WIKI, "src", "data", "items.json"), "utf8")).items;
const sheets = (icons.sheets ?? []).map((p) => join(root, p));

function writeManifest(manifest) {
  mkdirSync(join(WIKI, "src", "generated"), { recursive: true });
  const sorted = Object.fromEntries(Object.entries(manifest.files).sort(([a], [b]) => (a < b ? -1 : 1)));
  writeFileSync(MANIFEST, `${JSON.stringify({ ...manifest, files: sorted }, null, 2)}\n`);
}

if (sheets.length === 0 || !sheets.every((p) => existsSync(p))) {
  console.log("item-icons: brak atlasów S35 (art/icons), ikony jako glify. (no S35 atlases: glyph icons)");
  writeManifest({ version: VERSION, atlasHash: "", files: {} });
  process.exit(0);
}

const hash = createHash("sha256").update(String(VERSION));
for (const p of sheets) hash.update(readFileSync(p));
const atlasHash = hash.digest("hex").slice(0, 16);
const old = existsSync(MANIFEST) ? JSON.parse(readFileSync(MANIFEST, "utf8")) : null;
const sameAtlas = old?.atlasHash === atlasHash;

const cell = icons.cell;
const atlases = await Promise.all(sheets.map((p) => sharp(p).ensureAlpha().raw().toBuffer({ resolveWithObject: true })));

async function layerPng(layer) {
  const atlas = atlases[layer.image - 1];
  let raw = await sharp(atlas.data, { raw: atlas.info }).extract({ left: layer.x, top: layer.y, width: cell, height: cell }).raw().toBuffer();
  if (layer.tint) raw = multiplyTint(raw, layer.tint);
  return sharp(raw, { raw: { width: cell, height: cell, channels: 4 } }).png().toBuffer();
}

async function compose(layers) {
  const pngs = await Promise.all(layers.map(layerPng));
  return sharp({ create: { width: cell, height: cell, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
    .composite(pngs.map((input) => ({ input, blend: "over" })))
    .png()
    .toBuffer();
}

mkdirSync(OUT, { recursive: true });
const jobs = iconJobs(items);
const files = {};
const wanted = new Set();
let built = 0;
let kept = 0;
const done = new Map();
for (const [id, job] of jobs) {
  files[id] = job.file;
  wanted.add(`${job.file}-128.webp`);
  wanted.add(`${job.file}-64.webp`);
  if (done.has(job.file)) continue;
  done.set(job.file, job.layers);
  const big = join(OUT, `${job.file}-128.webp`);
  const small = join(OUT, `${job.file}-64.webp`);
  if (sameAtlas && existsSync(big) && existsSync(small)) {
    kept++;
    continue;
  }
  const png = await compose(job.layers);
  await sharp(png).webp({ quality: 86, alphaQuality: 90 }).toFile(big);
  await sharp(png).resize(64, 64, { kernel: "lanczos3" }).webp({ quality: 86, alphaQuality: 90 }).toFile(small);
  built++;
}
let removed = 0;
for (const f of readdirSync(OUT)) {
  if (!wanted.has(f)) {
    rmSync(join(OUT, f));
    removed++;
  }
}
writeManifest({ version: VERSION, atlasHash, files });
const size = readdirSync(OUT).reduce((n, f) => n + statSync(join(OUT, f)).size, 0);
console.log(`item-icons: ${done.size} ikon (${built} zbudowano, ${kept} bez zmian, ${removed} usunięto), ${Object.keys(files).length} wpisów, ${(size / 1024 / 1024).toFixed(2)} MB`);
if (size > BUDGET) console.warn(`item-icons: folder ponad budżet 8 MB`);

if (process.argv.includes("--sheet")) {
  // Contact sheet: 21 tiers of sword1h, the mage wand in 3 elements, potions, materials, boss items.
  const pick = [
    ...items.filter((i) => i.type === "sword1h").map((i) => i.id),
    ...Object.keys(items.find((i) => i.id === "wand_30")?.layersByElement ?? {}).map((el) => `wand_30:${el}`),
    ...items.filter((i) => i.id.startsWith("potion_")).map((i) => i.id).slice(0, 15),
    ...items.filter((i) => i.category === "material").map((i) => i.id),
    ...items.filter((i) => i.id.startsWith("unique_")).map((i) => i.id),
  ].filter((id) => files[id]);
  const cols = 12;
  const size2 = 96;
  const rows = Math.ceil(pick.length / cols);
  const tiles = await Promise.all(
    pick.map(async (id, i) => ({
      input: await sharp(join(OUT, `${files[id]}-128.webp`)).resize(size2 - 8, size2 - 8).png().toBuffer(),
      left: (i % cols) * size2 + 4,
      top: Math.floor(i / cols) * size2 + 4,
    })),
  );
  mkdirSync(join(WIKI, ".shots"), { recursive: true });
  await sharp({ create: { width: cols * size2, height: rows * size2, channels: 4, background: "#1C1F26" } }).composite(tiles).png().toFile(join(WIKI, ".shots", "icons-sheet.png"));
  console.log(`item-icons: .shots/icons-sheet.png (${pick.length} ikon)`);
}
