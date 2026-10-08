// npm run compare (S44): the mock-up frame (design/frames/<Page>-<desktop|mobile>.jpg) and the screenshot of the
// same page (.shots/<name>-<1440|390>.png from npm run shots) side by side, scaled to the same width, in
// .shots/compare/<Page>-<desktop|mobile>.png. Run `npm run shots` first. For looking at, not for asserting.
import { existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import sharp from "sharp";

const PAIRS = [
  ["Glowna", "glowna"],
  ["Szukaj", "szukaj"],
  ["Bestiariusz", "bestiariusz"],
  ["Potwor", "potwor-wilk"],
  ["Przedmioty", "przedmioty"],
  ["Przedmiot", "przedmiot-miecz"],
  ["Mag", "klasa-mag"],
  ["Mapa", "mapa"],
  ["Kraina", "kraina-laki"],
  ["Ulepszanie", "ulepszanie"],
];
const SIZES = [
  ["desktop", 1440],
  ["mobile", 390],
];
const MAX_H = 6000;
const GAP = 24;
const OUT = join(".shots", "compare");
mkdirSync(OUT, { recursive: true });

let made = 0;
for (const [frame, shot] of PAIRS) {
  for (const [kind, width] of SIZES) {
    const a = join("design", "frames", `${frame}-${kind}.jpg`);
    const b = join(".shots", `${shot}-${width}.png`);
    if (!existsSync(a) || !existsSync(b)) {
      console.warn(`compare: skipped ${frame}-${kind} (${existsSync(a) ? b : a} missing)`);
      continue;
    }
    const left = await sharp(a).resize({ width }).toBuffer({ resolveWithObject: true });
    const right = await sharp(b).resize({ width }).toBuffer({ resolveWithObject: true });
    const h = Math.min(MAX_H, Math.max(left.info.height, right.info.height));
    const crop = async (img) => (img.info.height > h ? sharp(img.data).extract({ left: 0, top: 0, width, height: h }).toBuffer() : img.data);
    await sharp({ create: { width: width * 2 + GAP, height: h, channels: 3, background: "#000000" } })
      .composite([
        { input: await crop(left), left: 0, top: 0 },
        { input: await crop(right), left: width + GAP, top: 0 },
      ])
      .png()
      .toFile(join(OUT, `${frame}-${kind}.png`));
    made++;
  }
}
console.log(`compare: ${made} images in ${OUT} (mock-up left, wiki right)`);
