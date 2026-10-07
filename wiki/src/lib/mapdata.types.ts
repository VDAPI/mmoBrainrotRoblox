// Shape of /<lang>/map-data.json (S37): short records for the world map island (no fs, safe to import in islands).

export type MapRank = "normal" | "elite" | "elite2";

export interface MDMap {
  name: string;
  kind: string;
  zone: string;
  min: number;
  max: number;
  /** size in studs [x, z] (maps are centred on 0, 0) */
  size: [number, number];
  region?: string;
  href: string | null;
  desc: string;
  route: string[];
  /** monsters living on the map: [monster id, rank, min level, max level] */
  mons: [string, MapRank, number, number][];
  /** has its own SVG in /img/maps */
  svg: boolean;
}

export interface MDArea {
  name: string;
  map: string;
  min: number;
  max: number;
  groups: number;
  count: number;
  respawn: [number, number];
  profile?: string;
  mons: [string, number, number][];
  href: string | null;
}

export interface MDCave {
  name: string;
  region: string;
  min: number;
  max: number;
  normal: string[];
  elites: string[];
  elite2: string[];
  ores: string[];
  oreCount: number;
  boss?: string;
  href: string | null;
}

export interface MDNpc {
  name: string;
  role: string;
  map: string;
  services: string[];
  quests: string[];
}

export interface MDQuest {
  id: string;
  title: string;
  level: number;
  href: string;
  giver: string;
  goal: string;
  places: { map: string; area?: string; cave?: string; npc?: string }[];
}

export interface MDSearch {
  kind: string;
  id: string;
  map: string;
  x: number;
  z: number;
  texts: string[];
}

export interface MapData {
  maps: Record<string, MDMap>;
  /** map list in the game's order (city, region, its caves, …) */
  order: string[];
  areas: Record<string, MDArea>;
  caves: Record<string, MDCave>;
  /** monster id -> [normal name, elite name?, elite II name?] */
  monsters: Record<string, string[]>;
  bosses: Record<string, { name: string; level: number; cave: string; href: string }>;
  portals: Record<string, { map: string; target: string; kind: string }>;
  npcs: Record<string, MDNpc>;
  quests: MDQuest[];
  zones: Record<string, { name: string; rule: string }>;
  ranks: Record<string, string>;
  profiles: Record<string, { icon: string; name: string; color: string }>;
  search: MDSearch[];
  bestiary: string | null;
  limit: number;
}
