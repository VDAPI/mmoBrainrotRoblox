// Pure parts of the item icon builder (S40, scripts/item-icons.mjs): tint multiplication on raw RGBA pixels and the
// deterministic file names. Tested in src/lib/icons.test.ts.

/** "#E6C77C" -> [230, 199, 124]. */
export function hexRgb(hex) {
  const v = hex.replace("#", "");
  return [parseInt(v.slice(0, 2), 16), parseInt(v.slice(2, 4), 16), parseInt(v.slice(4, 6), 16)];
}

/**
 * Multiplies every pixel of a raw RGBA buffer by a colour like Roblox's ImageColor3 (r·tr/255, g·tg/255, b·tb/255),
 * alpha unchanged. Returns a new buffer. (sharp's tint() keeps luminance and does not multiply.)
 */
export function multiplyTint(raw, tint) {
  const [tr, tg, tb] = hexRgb(tint);
  const out = Buffer.from(raw);
  for (let i = 0; i < out.length; i += 4) {
    out[i] = Math.round((out[i] * tr) / 255);
    out[i + 1] = Math.round((out[i + 1] * tg) / 255);
    out[i + 2] = Math.round((out[i + 2] * tb) / 255);
  }
  return out;
}

/** Base name of an icon file: the icon key with "/" -> "-" plus the tints of its layers (same look = same file). */
export function iconFileName(key, layers) {
  const tints = layers.filter((l) => l.tint).map((l) => l.tint.replace("#", "").toLowerCase());
  return [key.replaceAll("/", "-"), ...tints].join("-").replace(/[^a-z0-9_-]/gi, "_");
}

/** Every icon the wiki needs: "<itemId>" and "<itemId>:<element>" -> { key, layers, file }. */
export function iconJobs(items) {
  const jobs = new Map();
  for (const item of items) {
    if (!item.layers || item.layers.length === 0) continue;
    const key = item.iconKey ?? item.id;
    jobs.set(item.id, { key, layers: item.layers, file: iconFileName(key, item.layers) });
    for (const [el, layers] of Object.entries(item.layersByElement ?? {})) {
      jobs.set(`${item.id}:${el}`, { key, layers, file: iconFileName(key, layers) });
    }
  }
  return jobs;
}
