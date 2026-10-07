// Bestiary filters (S39): the URL contract (?region=<mapId>&lv=21-40&type=elite,elite2&q=&sort=level|-level|name
// &view=table&page=2), matching and sorting. Pure functions without data imports: the page script
// (src/scripts/bestiary.ts) and the build (src/lib/bestiary.ts) share them. Unknown values are ignored.
import { normalize } from "./search";

export const RANKS = ["normal", "elite", "elite2", "boss"] as const;
export type Rank = (typeof RANKS)[number];
export const SORTS = ["level", "-level", "name"] as const;
export type Sort = (typeof SORTS)[number];
export type View = "cards" | "table";

/** Level band width of the "Level" filter (1–20, 21–40, …). */
export const BAND = 20;

export interface Filters {
  region: string | null; // a region map id (with its caves) or a cave id
  lv: [number, number] | null;
  types: Rank[];
  q: string;
  sort: Sort;
  view: View;
  page: number;
}

/** What a list entry exposes to filtering (data-* attributes on the page). */
export interface FilterEntry {
  rank: Rank;
  levelMin: number;
  levelMax: number;
  places: string[]; // map / cave ids where it lives
  regions: string[]; // region map ids of those places
  key: string; // normalized search text
  name: string;
  order: number; // stable tie-break (data order)
}

export const DEFAULT_FILTERS: Filters = { region: null, lv: null, types: [], q: "", sort: "level", view: "cards", page: 1 };

/** Level bands up to the highest level of the data: [[1,20],[21,40],…]. */
export function levelBands(maxLevel: number): [number, number][] {
  const out: [number, number][] = [];
  for (let from = 1; from <= maxLevel; from += BAND) out.push([from, from + BAND - 1]);
  return out;
}

/**
 * Filters from a query string. `regions` (known region and cave ids) and `bands` limit the accepted values; without
 * them any well-formed value is kept.
 */
export function parseFilters(search: string, known?: { regions?: string[]; bands?: [number, number][] }): Filters {
  const p = new URLSearchParams(search);
  const f: Filters = { ...DEFAULT_FILTERS, types: [] };
  const region = p.get("region");
  if (region && /^[a-z0-9_]+$/i.test(region) && (!known?.regions || known.regions.includes(region))) f.region = region;
  const lv = /^(\d{1,3})-(\d{1,3})$/.exec(p.get("lv") ?? "");
  if (lv) {
    const band: [number, number] = [Number(lv[1]), Number(lv[2])];
    if (band[0] <= band[1] && (!known?.bands || known.bands.some((b) => b[0] === band[0] && b[1] === band[1]))) f.lv = band;
  }
  for (const t of (p.get("type") ?? "").split(",")) {
    if ((RANKS as readonly string[]).includes(t) && !f.types.includes(t as Rank)) f.types.push(t as Rank);
  }
  f.types.sort((a, b) => RANKS.indexOf(a) - RANKS.indexOf(b));
  f.q = (p.get("q") ?? "").slice(0, 60);
  const sort = p.get("sort");
  if (sort && (SORTS as readonly string[]).includes(sort)) f.sort = sort as Sort;
  if (p.get("view") === "table") f.view = "table";
  const page = Number(p.get("page"));
  if (Number.isInteger(page) && page > 1 && page < 1000) f.page = page;
  return f;
}

/** Query string of the filters ("" for the defaults), keys in a fixed order. */
export function serializeFilters(f: Filters): string {
  const p = new URLSearchParams();
  if (f.region) p.set("region", f.region);
  if (f.lv) p.set("lv", `${f.lv[0]}-${f.lv[1]}`);
  if (f.types.length > 0) p.set("type", f.types.join(","));
  if (f.q.trim() !== "") p.set("q", f.q.trim());
  if (f.sort !== "level") p.set("sort", f.sort);
  if (f.view === "table") p.set("view", "table");
  if (f.page > 1) p.set("page", String(f.page));
  const text = p.toString();
  return text ? `?${text}` : "";
}

/** Whether any filter narrows the list (sort, view and page do not). */
export function isFiltered(f: Filters): boolean {
  return f.region !== null || f.lv !== null || f.types.length > 0 || f.q.trim() !== "";
}

/** A region id matches its own places and the caves of the region; a cave id only itself. */
export function matches(entry: FilterEntry, f: Filters): boolean {
  if (f.region && !entry.places.includes(f.region) && !entry.regions.includes(f.region)) return false;
  if (f.lv && (entry.levelMax < f.lv[0] || entry.levelMin > f.lv[1])) return false;
  if (f.types.length > 0 && !f.types.includes(entry.rank)) return false;
  const q = normalize(f.q);
  if (q !== "") {
    for (const word of q.split(" ")) if (!entry.key.includes(word)) return false;
  }
  return true;
}

/** Sorted copy: level ↑ / level ↓ (then name) or name; ties keep the data order. */
export function sortEntries<T extends FilterEntry>(list: T[], sort: Sort, lang: string): T[] {
  const collator = new Intl.Collator(lang === "en" ? "en" : "pl");
  const byName = (a: T, b: T) => collator.compare(a.name, b.name);
  return [...list].sort((a, b) => {
    let d = 0;
    if (sort === "level") d = a.levelMin - b.levelMin || a.levelMax - b.levelMax;
    else if (sort === "-level") d = b.levelMax - a.levelMax || b.levelMin - a.levelMin;
    if (d === 0) d = byName(a, b);
    return d || a.order - b.order;
  });
}

/** The next sort of the sort button (like the mock-up: level ↑ → level ↓ → name). */
export function nextSort(sort: Sort): Sort {
  return SORTS[(SORTS.indexOf(sort) + 1) % SORTS.length];
}
