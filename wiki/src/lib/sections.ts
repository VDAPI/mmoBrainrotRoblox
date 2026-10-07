// Wiki sections and whether their pages exist yet (S36). A link to a section that is not ready renders as text with
// "Soon" (never a 404). Later sessions flip `ready` and add their views in src/views/registry.ts.
import { href, type Lang, type RouteKey } from "../i18n/routes";

export interface Section {
  id: RouteKey;
  ready: boolean;
  session: string;
}

export const SECTIONS: Section[] = [
  { id: "items", ready: false, session: "S40" },
  { id: "upgrading", ready: false, session: "S40" },
  { id: "crafting", ready: false, session: "S40" },
  { id: "bestiary", ready: true, session: "S39" },
  { id: "bosses", ready: true, session: "S39" },
  { id: "map", ready: true, session: "S37" },
  { id: "regions", ready: true, session: "S37" },
  { id: "classes", ready: false, session: "S41" },
  { id: "quests", ready: false, session: "S42" },
  { id: "mechanics", ready: false, session: "S42" },
  { id: "guides", ready: false, session: "S43" },
  { id: "updates", ready: false, session: "S43" },
  { id: "search", ready: true, session: "S36" },
  { id: "styleguide", ready: true, session: "S36" },
];

export function isReady(id: RouteKey): boolean {
  return id === "home" || SECTIONS.some((s) => s.id === id && s.ready);
}

/** Address of a section page, or null while the section is not built yet. */
export function sectionHref(lang: Lang, id: RouteKey, ...ids: string[]): string | null {
  return isReady(id) ? href(lang, id, ...ids) : null;
}

/** Search page for a phrase (the fallback link to entities of sections that are not ready). */
export function searchHref(lang: Lang, query: string): string {
  return `${href(lang, "search")}?q=${encodeURIComponent(query)}`;
}
