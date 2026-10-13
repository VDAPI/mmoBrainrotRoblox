// Mechanics topics of the index (S42): all twelve in three groups (S97: mounts, S101: world events); a topic links once its article exists
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
  { key: "trading", group: "players", icon: "M6 12h16l-4-4M26 20H10l4 4" },
  { key: "guilds", group: "players", icon: "M9 6h14v12l-7 8-7-8zM13 12h6" },
  { key: "city", group: "world", icon: "M5 26h22M8 26V14l4-4 4 4v12m4 0V10l4-4 4 4v16" },
  { key: "cosmetics", group: "world", icon: "M10 7l6 3 6-3 4 6-4 2v11H10V15l-4-2z" },
  { key: "mounts", group: "world", icon: "M9 26V12a7 7 0 0 1 14 0v14M6 26h6m8 0h6M12 9h1m6 0h1" },
  { key: "worldEvents", group: "world", icon: "M16 4v6m0 12v6M4 16h6m12 0h6M9 9l3 3m8 8l3 3m0-14l-3 3m-8 8l-3 3M16 13a3 3 0 1 0 0 6a3 3 0 1 0 0-6" },
];

export const GROUPS: Topic["group"][] = ["character", "players", "world"];
