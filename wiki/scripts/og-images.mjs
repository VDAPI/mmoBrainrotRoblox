// Share images (S39), run after `astro build`: reads dist/og-manifest.json (src/lib/og.ts) and writes 1200 x 630
// JPEGs to dist/<out> — the base picture public/img/og/base.png (S38; missing -> plain #14161B with a frame), the
// render in x 640–1160 / y 40–600 over a glow in the accent colour, and the text drawn by satori (no React: plain
// { type, props } trees) in x 64–600: kicker, name (Grenze, up to 2 lines, smaller for long names), level line and
// chips. Fonts are the .woff files of @fontsource (satori cannot read WOFF2), latin and latin-ext registered as two
// families and listed together so Polish letters come from latin-ext. The manifest is deleted afterwards.
import { existsSync, mkdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import satori from "satori";
import sharp from "sharp";

const W = 1200;
const H = 630;
const DIST = "dist";
const manifestPath = join(DIST, "og-manifest.json");
if (!existsSync(manifestPath)) {
  console.error("og-images: no dist/og-manifest.json (run astro build first)");
  process.exit(1);
}
const entries = JSON.parse(readFileSync(manifestPath, "utf8"));

const font = (pkg, file) => readFileSync(join("node_modules", "@fontsource", pkg, "files", file));
const fonts = [
  { name: "Grenze", data: font("grenze-gotisch", "grenze-gotisch-latin-700-normal.woff"), weight: 700, style: "normal" },
  { name: "GrenzeExt", data: font("grenze-gotisch", "grenze-gotisch-latin-ext-700-normal.woff"), weight: 700, style: "normal" },
  { name: "Alegreya", data: font("alegreya-sans", "alegreya-sans-latin-700-normal.woff"), weight: 700, style: "normal" },
  { name: "AlegreyaExt", data: font("alegreya-sans", "alegreya-sans-latin-ext-700-normal.woff"), weight: 700, style: "normal" },
  { name: "Alegreya", data: font("alegreya-sans", "alegreya-sans-latin-800-normal.woff"), weight: 800, style: "normal" },
  { name: "AlegreyaExt", data: font("alegreya-sans", "alegreya-sans-latin-ext-800-normal.woff"), weight: 800, style: "normal" },
];
const UI = "Alegreya, AlegreyaExt";
const DISPLAY = "Grenze, GrenzeExt";

const h = (type, style, children) => ({ type, props: { style, children } });

/** Title size by length: long names get smaller so they fit in two lines of 536 px. */
export function titleSize(title) {
  const n = [...title].length;
  return n <= 12 ? 84 : n <= 18 ? 72 : n <= 26 ? 60 : 50;
}

function textLayer(e) {
  const chips = e.chips.map((c) =>
    h(
      "div",
      {
        display: "flex",
        padding: "6px 12px",
        fontSize: 20,
        fontWeight: 800,
        letterSpacing: 1,
        border: `2px solid ${c.color}`,
        background: c.fill ? c.color : "rgba(20,22,27,0.85)",
        color: c.fill ? "#14161B" : c.color,
      },
      c.text,
    ),
  );
  return h(
    "div",
    { width: W, height: H, display: "flex", flexDirection: "column", justifyContent: "center", padding: "0 0 0 64px", fontFamily: UI, color: "#E8E4DA" },
    [
      h("div", { display: "flex", width: 536, fontSize: 22, fontWeight: 800, letterSpacing: 4, color: "#C9A45C", textTransform: "uppercase" }, e.kicker),
      h(
        "div",
        { display: "flex", width: 536, marginTop: 18, fontFamily: DISPLAY, fontWeight: 700, fontSize: titleSize(e.title), lineHeight: 1.02, color: "#F2E6C2", lineClamp: 2 },
        e.title,
      ),
      h("div", { display: "flex", width: 536, marginTop: 18, fontSize: 30, fontWeight: 700, color: "#E8C25A", lineClamp: 2 }, e.meta),
      h("div", { display: "flex", flexWrap: "wrap", gap: 10, marginTop: 26, width: 536 }, chips),
    ],
  );
}

async function background() {
  const base = join("public", "img", "og", "base.png");
  if (existsSync(base)) return sharp(base).resize(W, H).png().toBuffer();
  const frame = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}"><rect width="${W}" height="${H}" fill="#14161B"/><rect x="12" y="12" width="${W - 24}" height="${H - 24}" fill="none" stroke="#C9A45C" stroke-width="2"/></svg>`;
  return sharp(Buffer.from(frame)).png().toBuffer();
}

function glow(color) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}"><defs><radialGradient id="g" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="${color}" stop-opacity="0.42"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient></defs><ellipse cx="900" cy="520" rx="320" ry="110" fill="url(#g)"/><ellipse cx="900" cy="330" rx="300" ry="280" fill="url(#g)" opacity="0.45"/></svg>`;
  return Buffer.from(svg);
}

const bg = await background();
let done = 0;
let bytes = 0;
for (const e of entries) {
  const layers = [{ input: glow(e.accent), left: 0, top: 0 }];
  const render = e.render ? join("public", e.render) : null;
  if (render && existsSync(render)) {
    const pic = await sharp(render).resize(520, 560, { fit: "contain", position: "bottom", background: { r: 0, g: 0, b: 0, alpha: 0 } }).png().toBuffer();
    layers.push({ input: pic, left: 640, top: 40 });
  }
  const svg = await satori(textLayer(e), { width: W, height: H, fonts });
  layers.push({ input: Buffer.from(svg), left: 0, top: 0 });
  const file = join(DIST, e.out);
  mkdirSync(dirname(file), { recursive: true });
  await sharp(bg).composite(layers).jpeg({ quality: 82, mozjpeg: true }).toFile(file);
  const size = statSync(file).size;
  if (size > 120 * 1024) console.warn(`og-images: ${e.out} is ${Math.round(size / 1024)} KB (> 120 KB)`);
  bytes += size;
  done++;
}
rmSync(manifestPath);
console.log(`og-images: ${done} images, ${Math.round(bytes / 1024)} KB`);
