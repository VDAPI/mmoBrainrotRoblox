// Mechanics topics of the index (S42): all eighteen in three groups (S97: mounts, S101: world events; S131: premium shop,
// VIP, rankings, arena, Blood Moon, tournament); a topic links once its article exists
// (mechanicsHref finds the key), otherwise its card shows "Soon". Titles and descriptions in the wiki i18n.
export interface Topic {
  key: string;
  group: "character" | "players" | "world";
  icon: string; // SVG path on a 32 x 32 grid
}

export const TOPICS: Topic[] = [
  { key: "combat", group: "character", icon: "M8 24L22 10m-3-3l6 6M7 21l4 4M24 24L10 10m3-3l-6 6m18 8l-4 4" },
  { key: "stats", group: "character", icon: "M7 25V15m6 10V9m6 16V12m6 13V6" },
  { key: "experience", group: "character", icon: "M6 24c6 0 8-4 10-9s4-9 10-9M6 26h20" },
  { key: "death", group: "character", icon: "M10 26V13a6 6 0 0 1 12 0v13M13 26h6M16 9v6m-3-3h6" },
  { key: "blessings", group: "character", icon: "M16 5l2.5 7h7l-5.7 4.3 2.2 7L16 19l-6 4.3 2.2-7L6.5 12h7z" },
  { key: "pvp", group: "players", icon: "M7 7l9 9m0 0l9-9M16 16v10M10 26h12" },
  { key: "rankings", group: "players", icon: "M6 26h20M9 26V16h5v10m4 0V10h5v16M14 6l2-2 2 2" },
  { key: "arena", group: "players", icon: "M5 26h22M7 26V14h18v12M11 14V9h10v5M8 20h4m8 0h4" },
  { key: "bloodMoon", group: "players", icon: "M20 6a10 10 0 1 0 6 16a8 8 0 1 1-6-16zM8 27l3-3m10 3l-3-3" },
  { key: "tourney", group: "players", icon: "M10 6h12v6a6 6 0 0 1-12 0zM10 8H6a4 4 0 0 0 4 6m12-6h4a4 4 0 0 1-4 6M16 18v5m-5 3h10" },
  { key: "trading", group: "players", icon: "M6 12h16l-4-4M26 20H10l4 4" },
  { key: "guilds", group: "players", icon: "M9 6h14v12l-7 8-7-8zM13 12h6" },
  { key: "city", group: "world", icon: "M5 26h22M8 26V14l4-4 4 4v12m4 0V10l4-4 4 4v16" },
  { key: "cosmetics", group: "world", icon: "M10 7l6 3 6-3 4 6-4 2v11H10V15l-4-2z" },
  { key: "mounts", group: "world", icon: "M9 26V12a7 7 0 0 1 14 0v14M6 26h6m8 0h6M12 9h1m6 0h1" },
  { key: "premiumShop", group: "world", icon: "M16 4l10 8-10 16L6 12zM6 12h20M12 12l4 16 4-16" },
  { key: "vip", group: "world", icon: "M6 24l3-13 7 6 7-6 3 13zM6 27h20M9 8a1 1 0 1 0 0.1 0M23 8a1 1 0 1 0 0.1 0" },
  { key: "worldEvents", group: "world", icon: "M16 4v6m0 12v6M4 16h6m12 0h6M9 9l3 3m8 8l3 3m0-14l-3 3m-8 8l-3 3M16 13a3 3 0 1 0 0 6a3 3 0 1 0 0-6" },
];

export const GROUPS: Topic["group"][] = ["character", "players", "world"];
