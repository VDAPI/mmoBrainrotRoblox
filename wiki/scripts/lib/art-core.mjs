// Pure parts of `npm run art` (WIKI-GRAFIKA, scripts/art.mjs): which of the owner's pictures (his Graphics folder,
// layout in its PORADNIK-GRAFIKA.md) the wiki shows, under which data id, in which sizes. One rule per kind is the
// single mapping source; a picture is used only when its id is published in wiki/src/data (hidden skills, paths and
// items never get a file). Tested in scripts/lib/cores.test.mjs.

export const ART_VERSION = 1;
/** Margin around a trimmed picture (as the game's icon packer, tools/icons/import_png.py). */
export const MARGIN = 0.06;

/** Output widths (px) of each size set; files are <file>-<width>.webp. */
export const SIZE_SETS = { icon: [64, 128], portrait: [320, 640], hd: [256] };

/** Folders of the Graphics folder that never hold finished pictures. */
export const SKIP_DIRS = new Set(["_duplikaty", "szkic", "model"]);

/** HUD buttons of the game windows -> keybind ids of mechanics.keybinds. */
const KEYBIND_FILES = {
  "menu_inventory.png": "win_inventory",
  "menu_skills.png": "win_skills",
  "menu_map.png": "win_map",
  "menu_quests.png": "win_quests",
  "menu_guild.png": "win_guild",
  "menu_party.png": "win_party",
  "sprint.png": "sprint",
};

/**
 * Kinds of pictures. `dir` = folder in Graphics (with `deep`, also its subfolders), `match` = file name -> id (first
 * group) or `names` = file name -> id; `fit`: "trim" (crop to the picture, 6% margin, square), "square" (painted tile,
 * centre crop), "portrait" (square from the upper part of a tall portrait); `mask`: a white sign drawn in the text
 * colour on the page (CSS mask), never as an <img>.
 */
export const RULES = [
  { kind: "class", dir: "tylko_2d/klasy", match: /^class_([a-z]+)\.png$/i, sizes: "icon", fit: "trim" },
  { kind: "portrait", dir: "tylko_2d/klasy", match: /^portrait_([a-z]+)\.png$/i, sizes: "portrait", fit: "portrait" },
  { kind: "skill", dir: "tylko_2d/umiejetnosci", deep: true, match: /^skill_(\w+)\.png$/, sizes: "icon", fit: "square" },
  { kind: "element", dir: "tylko_2d/zywioly", match: /^element_(\w+)\.png$/, sizes: "icon", fit: "square" },
  { kind: "guild", dir: "tylko_2d/gildia", match: /^guild_(\w+)\.png$/, sizes: "icon", fit: "square" },
  { kind: "profile", dir: "tylko_2d/profile", match: /^profile_(\w+)\.png$/, sizes: "icon", fit: "square" },
  { kind: "quest", dir: "tylko_2d/questy", match: /^quest_(\w+)\.png$/, sizes: "icon", fit: "trim" },
  { kind: "service", dir: "tylko_2d/mapa", match: /^service_(\w+)\.png$/, sizes: "icon", fit: "trim", mask: true },
  { kind: "keybind", dir: "tylko_2d/hud", names: KEYBIND_FILES, sizes: "icon", fit: "trim", mask: true },
  { kind: "pass", dir: "tylko_2d/hud", names: { "vip.png": "vip" }, sizes: "icon", fit: "trim", mask: true },
];

/** Item pictures: icon key group -> folders of Graphics holding the original (tools/icons/import_graphics.py). */
const ITEM_DIRS = {
  mat: ["tylko_2d/materialy"],
  pot: ["tylko_2d/mikstury"],
  misc: ["tylko_2d/zwoje", "tylko_2d/kamienie", "tylko_2d/plecaki"],
  tool: ["tylko_2d/narzedzia"],
  bless: ["tylko_2d/blogoslawienstwa"],
};

/**
 * Candidate originals (paths relative to Graphics) of an item picture key, as tools/icons/import_graphics.py maps them
 * the other way: "eq/sword1h@10" -> bronie/sword1h/sword1h_10.png or ekwipunek/sword1h/sword1h_10.png,
 * "uniq/<id>" -> bronie/<id>/<id>.png or unikaty/<id>.png, "bless/<line>" -> blessing_<line>.png, else <name>.png.
 */
export function itemOriginals(key) {
  const [group, rest] = key.split("/");
  if (!rest) return [];
  if (group === "eq") {
    const m = /^([a-z0-9_]+)@(\d+)$/.exec(rest);
    if (!m) return [];
    const file = `${m[1]}_${m[2]}.png`;
    return [`modele_3d/bronie/${m[1]}/${file}`, `tylko_2d/ekwipunek/${m[1]}/${file}`];
  }
  if (group === "uniq") return [`modele_3d/bronie/${rest}/${rest}.png`, `tylko_2d/unikaty/${rest}.png`];
  if (group === "bless") return ITEM_DIRS.bless.map((d) => `${d}/blessing_${rest}.png`);
  return (ITEM_DIRS[group] ?? []).map((d) => `${d}/${rest}.png`);
}

/** File-safe name of an id or icon key ("eq/sword1h@10" -> "eq-sword1h_10"). */
export function safeName(id) {
  return id.replaceAll("/", "-").replace(/[^a-z0-9_-]/gi, "_");
}

/** Published ids per kind from the wiki data files ({ items, classes, skills, elements, mechanics, quests, npcs, premium }). */
export function publishedIds(data) {
  const questItems = new Set();
  for (const q of [...(data.quests.main ?? []), ...(data.quests.side ?? [])]) {
    for (const o of q.objectives ?? []) if (o.item) questItems.add(o.item);
  }
  const classIds = data.classes.classes.map((c) => c.id);
  return {
    class: new Set(classIds),
    portrait: new Set(classIds),
    skill: new Set(data.skills.skills.map((s) => s.id)),
    element: new Set(data.elements.elements.map((e) => e.id)),
    guild: new Set((data.mechanics.guild?.skills ?? []).map((s) => s.id)),
    profile: new Set(Object.keys(data.mechanics.areaProfiles ?? {})),
    quest: questItems,
    service: new Set(Object.keys(data.npcs.services ?? {})),
    keybind: new Set((data.mechanics.keybinds ?? []).map((k) => k.id)),
    pass: new Set((data.premium.passes ?? []).map((p) => p.key)),
    item: new Set(data.items.items.map((i) => i.iconKey).filter(Boolean)),
  };
}

/** Data id for a captured name: exact, else the only id equal ignoring case ("mage" -> "Mage"), else null. */
export function resolveId(name, ids) {
  if (ids.has(name)) return name;
  const hits = [...ids].filter((id) => id.toLowerCase() === name.toLowerCase());
  return hits.length === 1 ? hits[0] : null;
}

/**
 * What to build. `files` = every .png of Graphics (relative, "/" separators, SKIP_DIRS already left out), `published`
 * = publishedIds(...), `pictureKeys` = icon keys that are owner's pictures in the game (art/icons/src). Returns
 * { entries: [{ key, kind, id, source, file, sizes, fit, mask }], unused: [relative path] } sorted by key / path.
 */
export function planArt(files, published, pictureKeys) {
  const entries = new Map();
  const used = new Set();
  for (const rule of RULES) {
    for (const rel of files) {
      const slash = rel.lastIndexOf("/");
      const dir = rel.slice(0, slash);
      const base = rel.slice(slash + 1);
      if (dir !== rule.dir && !(rule.deep && dir.startsWith(`${rule.dir}/`))) continue;
      const name = rule.names ? rule.names[base] : rule.match.exec(base)?.[1];
      if (!name) continue;
      const id = resolveId(name, published[rule.kind]);
      if (!id) continue;
      const key = `${rule.kind}/${id}`;
      if (entries.has(key)) throw new Error(`art: two pictures for ${key}: ${entries.get(key).source}, ${rel}`);
      entries.set(key, { key, kind: rule.kind, id, source: rel, file: `${rule.kind}/${safeName(id)}`, sizes: SIZE_SETS[rule.sizes], fit: rule.fit, mask: rule.mask === true });
      used.add(rel);
    }
  }
  const have = new Set(files);
  for (const iconKey of [...published.item].sort()) {
    if (!pictureKeys.has(iconKey)) continue;
    const source = itemOriginals(iconKey).find((p) => have.has(p));
    if (!source) continue;
    const key = `item/${iconKey}`;
    entries.set(key, { key, kind: "item", id: iconKey, source, file: `item/${safeName(iconKey)}`, sizes: SIZE_SETS.hd, fit: "trim", mask: false });
    used.add(source);
  }
  return {
    entries: [...entries.values()].sort((a, b) => (a.key < b.key ? -1 : 1)),
    unused: files.filter((f) => !used.has(f)).sort(),
  };
}

/** Output file names of an entry ("skill/fireball-64.webp", ...). */
export function outputsOf(entry) {
  return entry.sizes.map((w) => `${entry.file}-${w}.webp`);
}

/** Manifest entries whose kind/id is still published (used without the Graphics folder: only pruning). */
export function prunePublished(manifestEntries, published) {
  const out = {};
  for (const [key, e] of Object.entries(manifestEntries)) {
    const slash = key.indexOf("/");
    const kind = key.slice(0, slash);
    const id = key.slice(slash + 1);
    if (published[kind]?.has(id)) out[key] = e;
  }
  return out;
}

/**
 * Crop box of a picture: "trim" = bounding box of alpha > 10 grown to a square with MARGIN on each side (the square can
 * reach past the image: the caller pads with transparency), "square" = centred square, "portrait" = square from the top
 * of a tall image (15% of the spare height down, where the face is). Returns { left, top, side } in source pixels.
 */
export function cropBox(fit, width, height, alphaBox) {
  if (fit === "trim" && alphaBox) {
    const bw = alphaBox.right - alphaBox.left;
    const bh = alphaBox.bottom - alphaBox.top;
    const side = Math.round(Math.max(bw, bh) / (1 - 2 * MARGIN));
    return { left: alphaBox.left - Math.floor((side - bw) / 2), top: alphaBox.top - Math.floor((side - bh) / 2), side };
  }
  const side = Math.min(width, height);
  const left = Math.floor((width - side) / 2);
  const top = fit === "portrait" ? Math.round((height - side) * 0.15) : Math.floor((height - side) / 2);
  return { left, top, side };
}

/** Bounding box of pixels with alpha > 10 in a raw RGBA buffer, or null when all are transparent. */
export function alphaBounds(raw, width, height) {
  let left = width;
  let top = height;
  let right = -1;
  let bottom = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (raw[(y * width + x) * 4 + 3] > 10) {
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }
  return right < 0 ? null : { left, top, right: right + 1, bottom: bottom + 1 };
}
