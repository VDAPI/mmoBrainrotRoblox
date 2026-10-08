// npm run images:city (S43): the city previews of docs/miasto/img (renders of the town plan tool) as WebP for the
// city topic: public/img/city/<name>-1000.webp and -500.webp. Skips outputs newer than their source; plan.png is left
// out (English NPC ids and overlapping labels). The output is committed, so builds and CI need no source images.
import { existsSync, mkdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SRC = join(ROOT, "..", "docs", "miasto", "img");
const OUT = join(ROOT, "public", "img", "city");
export const CITY_IMAGES = ["rynek", "ratusz", "swiatynia", "zamek", "kuznia", "mlyn", "okolica", "farma", "aerial"];
const WIDTHS = [1000, 500];

if (!existsSync(SRC)) {
  console.log(`images:city: no ${SRC}, nothing to do`);
  process.exit(0);
}
mkdirSync(OUT, { recursive: true });
const sizes = {};
let built = 0;
for (const name of CITY_IMAGES) {
  const src = join(SRC, `${name}.png`);
  if (!existsSync(src)) {
    console.warn(`images:city: missing ${name}.png`);
    continue;
  }
  const meta = await sharp(src).metadata();
  for (const w of WIDTHS) {
    const out = join(OUT, `${name}-${w}.webp`);
    const width = Math.min(w, meta.width ?? w);
    sizes[`${name}-${w}`] = { w: width, h: Math.round(((meta.height ?? 1) * width) / (meta.width ?? 1)) };
    if (existsSync(out) && statSync(out).mtimeMs >= statSync(src).mtimeMs) continue;
    await sharp(src).resize({ width, withoutEnlargement: true }).webp({ quality: 80 }).toFile(out);
    built++;
  }
}
writeFileSync(join(ROOT, "src", "generated", "city-images.json"), `${JSON.stringify(sizes, null, 2)}\n`);
console.log(`images:city: ${built} built, ${CITY_IMAGES.length * WIDTHS.length - built} up to date`);
