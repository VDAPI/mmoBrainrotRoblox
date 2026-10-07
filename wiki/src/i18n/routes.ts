// URL segments of every wiki section (docs/WIKI.md §4): ids in URLs are game ids (same in both languages), section
// segments are translated. One source for links, the language switch and the page registry.
export const LANGS = ["pl", "en"] as const;
export type Lang = (typeof LANGS)[number];

export const ROUTES = {
  home: { pl: "", en: "" },
  items: { pl: "przedmioty", en: "items" },
  bestiary: { pl: "bestiariusz", en: "bestiary" },
  bosses: { pl: "bossy", en: "bosses" },
  classes: { pl: "klasy", en: "classes" },
  map: { pl: "mapa", en: "map" },
  regions: { pl: "krainy", en: "regions" },
  upgrading: { pl: "ulepszanie", en: "upgrading" },
  crafting: { pl: "rzemioslo", en: "crafting" },
  quests: { pl: "zadania", en: "quests" },
  mechanics: { pl: "mechaniki", en: "mechanics" },
  guides: { pl: "poradniki", en: "guides" },
  search: { pl: "szukaj", en: "search" },
  updates: { pl: "aktualizacje", en: "updates" },
  styleguide: { pl: "styleguide", en: "styleguide" },
} as const satisfies Record<string, Record<Lang, string>>;

export type RouteKey = keyof typeof ROUTES;

export function isLang(value: unknown): value is Lang {
  return value === "pl" || value === "en";
}

export function otherLang(lang: Lang): Lang {
  return lang === "pl" ? "en" : "pl";
}

/** Address of a section (and ids below it) with a trailing slash: href("pl", "items", "sword1h_30"). */
export function href(lang: Lang, key: RouteKey, ...ids: string[]): string {
  const parts = [lang, ROUTES[key][lang], ...ids.map((id) => encodeURIComponent(id))].filter((p) => p !== "");
  return `/${parts.join("/")}/`;
}

/** Route key of a path segment in a language. */
export function keyOf(lang: Lang, segment: string): RouteKey | undefined {
  return (Object.keys(ROUTES) as RouteKey[]).find((key) => key !== "home" && ROUTES[key][lang] === segment);
}

/** The same address in the other language (unknown paths go to the other language's home page). */
export function alternate(path: string): string {
  const parts = path.split("?")[0].split("/").filter(Boolean);
  const lang = parts[0];
  if (!isLang(lang)) {
    return "/pl/";
  }
  const to = otherLang(lang);
  if (parts.length === 1) {
    return `/${to}/`;
  }
  const key = keyOf(lang, parts[1]);
  if (!key) {
    return parts[1] === "404" ? `/${to}/404/` : `/${to}/`;
  }
  return `/${[to, ROUTES[key][to], ...parts.slice(2)].join("/")}/`;
}
