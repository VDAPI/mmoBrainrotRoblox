// Address of a place on the world map (S37, docs/WIKI.md §4): /<lang>/mapa/?m=<map>&a=<id>&x=&z=&s=
//   m  map id (none = the world overview); unknown maps fall back to the world
//   a  selected element: area, cave, NPC, portal or boss id (looked up in that order by the map)
//   x, z  pin and view centre in map studs, clamped to the map
//   s  zoom (1–10, one decimal)
// Pure: the map island and the pages that link to the map share it.

export interface MapLink {
  m?: string;
  a?: string;
  x?: number;
  z?: number;
  s?: number;
}

export interface MapBounds {
  /** map id -> size in studs (x, z); the map is centred on 0, 0 */
  [id: string]: { x: number; z: number };
}

const ID = /^[A-Za-z0-9_-]{1,64}$/;

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

export function parse(search: string, maps: MapBounds): MapLink {
  const params = new URLSearchParams(search.startsWith("?") ? search.slice(1) : search);
  const out: MapLink = {};
  const m = params.get("m");
  const size = m && ID.test(m) ? maps[m] : undefined;
  if (m && size) out.m = m;
  const a = params.get("a");
  if (a && ID.test(a)) out.a = a;
  const x = Number(params.get("x"));
  const z = Number(params.get("z"));
  if (out.m && size && params.has("x") && params.has("z") && Number.isFinite(x) && Number.isFinite(z)) {
    out.x = Math.round(clamp(x, -size.x / 2, size.x / 2));
    out.z = Math.round(clamp(z, -size.z / 2, size.z / 2));
  }
  const s = Number(params.get("s"));
  if (params.has("s") && Number.isFinite(s) && s > 0) out.s = Math.round(clamp(s, 1, 10) * 10) / 10;
  return out;
}

export function serialize(link: MapLink): string {
  const params = new URLSearchParams();
  if (link.m) params.set("m", link.m);
  if (link.a) params.set("a", link.a);
  if (link.m && link.x !== undefined && link.z !== undefined) {
    params.set("x", String(Math.round(link.x)));
    params.set("z", String(Math.round(link.z)));
  }
  if (link.s !== undefined && link.s !== 1) params.set("s", String(Math.round(link.s * 10) / 10));
  const text = params.toString();
  return text ? `?${text}` : "";
}
