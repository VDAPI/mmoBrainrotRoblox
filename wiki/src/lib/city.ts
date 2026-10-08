// City topic (S43): which preview image of docs/miasto (public/img/city, npm run images:city) shows the building an
// NPC stands at; buildings without a preview fall back to the mini map.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { load } from "./data";
import type { Npc } from "../data/types";

const SIZES = join(process.cwd(), "src", "generated", "city-images.json");
let sizes: Record<string, { w: number; h: number }> | null = null;
const sizeOf = (key: string) => (sizes ??= existsSync(SIZES) ? JSON.parse(readFileSync(SIZES, "utf8")) : {})![key];

const BUILDING_IMAGE: Record<string, string> = {
  swiatynia: "swiatynia",
  kuznia: "kuznia",
  zbrojownia: "kuznia",
  apteka: "kuznia",
  ratusz: "ratusz",
  hala: "rynek",
  mlyn: "mlyn",
};

export interface CityImage {
  name: string;
  src: string;
  srcset: string;
  width: number;
  height: number;
}

export function cityImage(name: string): CityImage | null {
  const big = sizeOf(`${name}-1000`);
  const small = sizeOf(`${name}-500`);
  if (!big || !small) return null;
  return { name, src: `/img/city/${name}-1000.webp`, srcset: `/img/city/${name}-500.webp ${small.w}w, /img/city/${name}-1000.webp ${big.w}w`, width: big.w, height: big.h };
}

/** Preview of the building of an NPC: stalls show the market square, others their building, else null. */
export function buildingImage(building: string | undefined): CityImage | null {
  if (!building) return null;
  if (building.startsWith("stall_")) return cityImage("rynek");
  const name = BUILDING_IMAGE[building];
  return name ? cityImage(name) : null;
}

/** NPCs of the city that players talk to (not decorations), in the game's order. */
export function cityNpcs(): Npc[] {
  return load("npcs").npcs.filter((n) => n.map === "city" && !n.decoration);
}
