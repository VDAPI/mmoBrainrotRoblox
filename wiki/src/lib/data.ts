// Typed access to the exported game data (wiki/src/data, tools/wikidump.luau). Build time only: the JSON is read
// from disk (never bundled), so islands must not import this module; they fetch small generated files instead.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type {
  Boss,
  Files,
  Item,
  MapInfo,
  Monster,
  Rarity,
  RarityKey,
} from "../data/types";

const DATA_DIR = join(process.cwd(), "src", "data");
const cache = new Map<string, unknown>();

export function load<K extends keyof Files>(file: K): Files[K] {
  let value = cache.get(file);
  if (value === undefined) {
    value = JSON.parse(readFileSync(join(DATA_DIR, `${file}.json`), "utf8"));
    cache.set(file, value);
  }
  return value as Files[K];
}

function indexBy<T extends { id: string }>(list: T[]): Map<string, T> {
  return new Map(list.map((entry) => [entry.id, entry]));
}

const indexes = new Map<string, Map<string, unknown>>();

function byId<T extends { id: string }>(key: string, list: () => T[]): Map<string, T> {
  let index = indexes.get(key);
  if (!index) {
    index = indexBy(list());
    indexes.set(key, index);
  }
  return index as Map<string, T>;
}

export const items = (): Item[] => load("items").items;
export const monsters = (): Monster[] => load("monsters").monsters;
export const bosses = (): Boss[] => load("bosses").bosses;
export const maps = (): MapInfo[] => load("maps").maps;
export const rarities = (): Rarity[] => load("rarities").rarities;
export const meta = (): Files["meta"] => load("meta");

export const getItem = (id: string): Item | undefined => byId("items", items).get(id);
export const getMonster = (id: string): Monster | undefined => byId("monsters", monsters).get(id);
export const getBoss = (id: string): Boss | undefined => byId("bosses", bosses).get(id);
export const getMap = (id: string): MapInfo | undefined => byId("maps", maps).get(id);

export function rarityOf(key: RarityKey | string): Rarity | undefined {
  return rarities().find((r) => r.key === key);
}

/** Rarity index (0 = lowest) for sorting and glow strength. */
export function rarityRank(key: string): number {
  return rarities().findIndex((r) => r.key === key);
}
