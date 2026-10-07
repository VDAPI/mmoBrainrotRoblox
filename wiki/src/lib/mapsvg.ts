// Map SVGs from tools/wikimap.luau (wiki/public/img/maps/<id>.svg), inlined at build time so CSS variables, the
// language switch and highlighting by id work (S37). loadMapSvg reads the file (build time only); inlineMap crops,
// highlights and can strip ids (two mini maps on one page must not share ids). Pure string work: no DOM.
import { readFileSync } from "node:fs";
import { join } from "node:path";

const MAP_DIR = join(process.cwd(), "public", "img", "maps");
const cache = new Map<string, string>();

export function loadMapSvg(id: string): string {
  let svg = cache.get(id);
  if (svg === undefined) {
    svg = readFileSync(join(MAP_DIR, `${id}.svg`), "utf8").trim();
    // the dev server keeps modules alive: re-read regenerated maps there
    if (!import.meta.env?.DEV) cache.set(id, svg);
  }
  return svg;
}

export interface ViewBox {
  x: number;
  y: number;
  w: number;
  h: number;
}

export function parseViewBox(svg: string): ViewBox {
  const m = /viewBox="(-?[\d.]+) (-?[\d.]+) ([\d.]+) ([\d.]+)"/.exec(svg);
  if (!m) throw new Error("mapsvg: no viewBox");
  return { x: Number(m[1]), y: Number(m[2]), w: Number(m[3]), h: Number(m[4]) };
}

export interface Bounds {
  x1: number;
  z1: number;
  x2: number;
  z2: number;
}

/**
 * A view around `bounds` grown by `pad` (0.25 = 25 %) on each side, at least `min` studs wide and tall, kept inside
 * the map (`full`) and with the given aspect ratio (w / h).
 */
export function cropViewBox(full: ViewBox, bounds: Bounds, aspect: number, pad = 0.25, min = 320): ViewBox {
  const cx = (bounds.x1 + bounds.x2) / 2;
  const cz = (bounds.z1 + bounds.z2) / 2;
  let w = Math.max(min, (bounds.x2 - bounds.x1) * (1 + 2 * pad));
  let h = Math.max(min / aspect, (bounds.z2 - bounds.z1) * (1 + 2 * pad));
  if (w / h > aspect) h = w / aspect;
  else w = h * aspect;
  if (w > full.w) {
    w = full.w;
    h = Math.min(full.h, w / aspect);
  }
  if (h > full.h) {
    h = full.h;
    w = Math.min(full.w, h * aspect);
  }
  const x = Math.min(Math.max(cx - w / 2, full.x), full.x + full.w - w);
  const y = Math.min(Math.max(cz - h / 2, full.y), full.y + full.h - h);
  const r = (v: number) => Math.round(v);
  return { x: r(x), y: r(y), w: r(w), h: r(h) };
}

export interface InlineOptions {
  viewBox?: ViewBox;
  /** Element ids (without prefix, e.g. "area-meadows_wolfhills") that get the class is-hl. */
  highlight?: string[];
  /** Remove every id attribute (keeps data-id), so the SVG can appear more than once on a page. */
  stripIds?: boolean;
  /** Extra classes on the root <svg>. */
  className?: string;
  /** Accessible label (role="img" + aria-label); without it the SVG is decorative (aria-hidden). */
  label?: string;
  /** Value of --k on the root (marker scale: studs per screen pixel). */
  k?: number;
  /** Drop the embedded <style> (the page's map.css has the same rules). */
  stripStyle?: boolean;
}

const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");

export function inlineMap(svg: string, opts: InlineOptions = {}): string {
  let out = svg;
  const hl = new Set(opts.highlight ?? []);
  if (hl.size > 0) {
    // add is-hl to the class of highlighted elements (and to labels pointing at them with data-for)
    out = out.replace(/<(\w+)([^>]*?)\s(id|data-for)="([^"]+)"([^>]*?)(\/?)>/g, (whole, tag: string, a: string, attr: string, id: string, b: string, close: string) => {
      if (!hl.has(id)) return whole;
      const attrs = `${a} ${attr}="${id}"${b}`;
      const withClass = /\sclass="/.test(attrs) ? attrs.replace(/\sclass="([^"]*)"/, ' class="$1 is-hl"') : `${attrs} class="is-hl"`;
      return `<${tag}${withClass}${close}>`;
    });
  }
  if (opts.stripIds) {
    out = out.replace(/\sid="[^"]*"/g, "");
    out = out.replace(/\sdata-for="[^"]*"/g, "");
  }
  if (opts.stripStyle) {
    out = out.replace(/<style>[\s\S]*?<\/style>/, "");
  }
  if (opts.viewBox) {
    const v = opts.viewBox;
    out = out.replace(/viewBox="[^"]*"/, `viewBox="${v.x} ${v.y} ${v.w} ${v.h}"`);
  }
  const rootExtra: string[] = [];
  if (opts.className) {
    out = out.replace(/class="vw-mapsvg"/, `class="vw-mapsvg ${esc(opts.className)}"`);
  }
  if (hl.size > 0) rootExtra.push('data-hl=""');
  if (opts.k !== undefined) rootExtra.push(`style="--k:${Math.round(opts.k * 100) / 100}"`);
  if (opts.label) {
    out = out.replace(/\srole="img"/, ` role="img" aria-label="${esc(opts.label)}"`);
  } else {
    out = out.replace(/\srole="img"/, ' aria-hidden="true" focusable="false"');
  }
  if (rootExtra.length > 0) out = out.replace(/<svg /, `<svg ${rootExtra.join(" ")} `);
  return out;
}

/** Ids present in an SVG (for tests and checks). */
export function idsIn(svg: string): string[] {
  return [...svg.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]);
}
