// Item browser filters (S40, pure): URL contract (?q=&r=&slot=&cls=&lv=&sort=&sel=&all=&page=), matching, tier
// grouping (one row per generated base with a tier stepper) and sorting. Used by ItemsBrowser and the tests.
import { normalize } from "./search";

export interface IndexRowLite {
  id: string;
  base: string;
  name: string;
  type: string;
  slot: string;
  category: string;
  classes: string[];
  allClasses: boolean;
  level: number;
  tier: number | null;
  rarities: string[];
  stats: Record<string, string>;
  statNum?: Record<string, number>;
  key: string;
}

export type ItemSort = "level" | "-level" | "name" | "type" | "stat";
export const ITEM_SORTS: ItemSort[] = ["-level", "level", "name", "type", "stat"];

export interface ItemFilters {
  q: string;
  rarities: string[];
  slot: string; // "" = all
  cls: string; // "" = every class
  lv: [number, number] | null;
  sort: ItemSort;
  sel: string;
  all: boolean; // flat list of every tier
  page: number;
}

export const DEFAULT_ITEM_FILTERS: ItemFilters = { q: "", rarities: [], slot: "", cls: "", lv: null, sort: "-level", sel: "", all: false, page: 1 };

const ID = /^[A-Za-z0-9_:]+$/;

export function parseItemFilters(search: string, known?: { rarities?: string[]; slots?: string[]; classes?: string[] }): ItemFilters {
  const p = new URLSearchParams(search);
  const f: ItemFilters = { ...DEFAULT_ITEM_FILTERS, rarities: [] };
  f.q = (p.get("q") ?? "").slice(0, 60);
  for (const r of (p.get("r") ?? "").split(",")) {
    if (r && ID.test(r) && (!known?.rarities || known.rarities.includes(r)) && !f.rarities.includes(r)) f.rarities.push(r);
  }
  if (known?.rarities) f.rarities.sort((a, b) => known.rarities!.indexOf(a) - known.rarities!.indexOf(b));
  const slot = p.get("slot") ?? "";
  if (slot && ID.test(slot) && (!known?.slots || known.slots.includes(slot))) f.slot = slot;
  const cls = p.get("cls") ?? "";
  if (cls && ID.test(cls) && (!known?.classes || known.classes.includes(cls))) f.cls = cls;
  const lv = /^(\d{1,3})-(\d{1,3})$/.exec(p.get("lv") ?? "");
  if (lv && Number(lv[1]) <= Number(lv[2])) f.lv = [Number(lv[1]), Number(lv[2])];
  const sort = p.get("sort") as ItemSort | null;
  if (sort && ITEM_SORTS.includes(sort)) f.sort = sort;
  const sel = p.get("sel") ?? "";
  if (sel && ID.test(sel)) f.sel = sel;
  f.all = p.get("all") === "1";
  const page = Number(p.get("page"));
  if (Number.isInteger(page) && page > 1 && page < 1000) f.page = page;
  return f;
}

export function serializeItemFilters(f: ItemFilters): string {
  const p = new URLSearchParams();
  if (f.q.trim()) p.set("q", f.q.trim());
  if (f.rarities.length) p.set("r", f.rarities.join(","));
  if (f.slot) p.set("slot", f.slot);
  if (f.cls) p.set("cls", f.cls);
  if (f.lv) p.set("lv", `${f.lv[0]}-${f.lv[1]}`);
  if (f.sort !== "-level") p.set("sort", f.sort);
  if (f.sel) p.set("sel", f.sel);
  if (f.all) p.set("all", "1");
  if (f.page > 1) p.set("page", String(f.page));
  const text = p.toString();
  return text ? `?${text}` : "";
}

export function itemMatches(row: IndexRowLite, f: ItemFilters): boolean {
  if (f.rarities.length > 0 && !row.rarities.some((r) => f.rarities.includes(r))) return false;
  if (f.slot && row.slot !== f.slot && row.category !== f.slot) return false;
  if (f.cls && !row.allClasses && !row.classes.includes(f.cls)) return false;
  if (f.lv && (row.level < f.lv[0] || row.level > f.lv[1])) return false;
  const q = normalize(f.q);
  if (q) for (const w of q.split(" ")) if (!row.key.includes(w)) return false;
  return true;
}

export interface ItemGroup<T extends IndexRowLite> {
  base: string;
  tiers: T[]; // sorted by tier (one entry for non-generated items)
  shown: T; // default tier
}

/**
 * Groups generated equipment by base (one row with a tier stepper); the shown tier is the highest one in the level
 * range (without a range the highest <= 100). Non-generated items stay single rows. Input rows must already match.
 */
export function groupTiers<T extends IndexRowLite>(rows: T[], lv: [number, number] | null): ItemGroup<T>[] {
  const groups = new Map<string, T[]>();
  const order: string[] = [];
  for (const row of rows) {
    const key = row.tier !== null ? `base:${row.base}` : `item:${row.id}`;
    if (!groups.has(key)) {
      groups.set(key, []);
      order.push(key);
    }
    groups.get(key)!.push(row);
  }
  const max = lv ? lv[1] : 100;
  return order.map((key) => {
    const tiers = groups.get(key)!.sort((a, b) => (a.tier ?? a.level) - (b.tier ?? b.level));
    const fit = tiers.filter((r) => r.level <= max);
    return { base: key, tiers, shown: fit[fit.length - 1] ?? tiers[0] };
  });
}

export function sortRows<T extends { name: string; type: string; level: number; statNum?: number }>(rows: T[], sort: ItemSort, lang: string): T[] {
  const collator = new Intl.Collator(lang === "en" ? "en" : "pl");
  return [...rows].sort((a, b) => {
    let d = 0;
    if (sort === "level") d = a.level - b.level;
    else if (sort === "-level") d = b.level - a.level;
    else if (sort === "type") d = collator.compare(a.type, b.type);
    else if (sort === "stat") d = (b.statNum ?? -1) - (a.statNum ?? -1);
    return d || collator.compare(a.name, b.name);
  });
}
