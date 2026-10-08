// Pages below /<lang>/ (S36 registry; S44: paths only, no view imports). Each section has its own route file
// src/pages/<lang>/<segment>/[...path].astro (written by `npm run routes`, scripts/routes.mjs) that imports only its
// view, so a page loads only the CSS of its own view. A new section: an entry here (view = file name in src/views),
// `ready: true` in src/lib/sections.ts, then `npm run routes`. Sections that are not ready get "Coming soon".
import type { Lang, RouteKey } from "../i18n/routes";
import { ROUTES } from "../i18n/routes";
import { SECTIONS } from "../lib/sections";
import { areas, caves, maps } from "../lib/world";
import { bosses, items, monsters } from "../lib/data";
import { classes } from "../lib/classes";
import { contentEntries } from "../lib/content";
import { mainQuests, sideQuests } from "../lib/quests";

export interface PageEntry {
  key: RouteKey | "404";
  /** File name of the view in src/views (without .astro). */
  view: string;
  /** Paths below the section segment ([] = the section root) with the props of each page. */
  getPaths: (lang: Lang) => { ids: string[]; props?: Record<string, unknown> }[];
}

export const PAGES: PageEntry[] = [
  { key: "search", view: "SearchView", getPaths: () => [{ ids: [] }] },
  { key: "styleguide", view: "Styleguide", getPaths: () => [{ ids: [] }] },
  { key: "404", view: "NotFound", getPaths: () => [{ ids: [] }] },
  { key: "map", view: "WorldMapView", getPaths: () => [{ ids: [] }] },
  {
    key: "regions",
    view: "RegionsView",
    getPaths: () => [
      { ids: [], props: { page: "index" } },
      ...maps()
        .filter((m) => m.kind === "city" || m.kind === "region")
        .map((m) => ({ ids: [m.id], props: { page: "region", id: m.id } })),
      ...areas().map((a) => ({ ids: [a.map, a.id], props: { page: "area", id: a.id } })),
      ...caves().map((c) => ({ ids: [c.region, c.id], props: { page: "cave", id: c.id } })),
    ],
  },
  {
    key: "bestiary",
    view: "BestiarySection",
    getPaths: () => [{ ids: [] }, ...monsters().map((m) => ({ ids: [m.id], props: { page: "monster", id: m.id } }))],
  },
  {
    key: "bosses",
    view: "BossView",
    getPaths: () => [{ ids: [], props: { page: "index" } }, ...bosses().map((b) => ({ ids: [b.id], props: { page: "boss", id: b.id } }))],
  },
  {
    key: "items",
    view: "ItemsSection",
    getPaths: () => [{ ids: [] }, ...items().map((i) => ({ ids: [i.id], props: { page: "item", id: i.id } }))],
  },
  { key: "bossItems", view: "BossItemsView", getPaths: () => [{ ids: [] }] },
  { key: "upgrading", view: "UpgradeView", getPaths: () => [{ ids: [] }] },
  { key: "crafting", view: "CraftingView", getPaths: () => [{ ids: [] }] },
  {
    key: "classes",
    view: "ClassesSection",
    getPaths: () => [{ ids: [] }, ...classes().map((c) => ({ ids: [c.id], props: { page: "class", id: c.id } }))],
  },
  {
    key: "quests",
    view: "QuestsSection",
    getPaths: () => [{ ids: [] }, ...[...mainQuests(), ...sideQuests()].map((q) => ({ ids: [q.id], props: { page: "quest", id: q.id } }))],
  },
  {
    key: "mechanics",
    view: "MechanicsSection",
    getPaths: (lang) => [
      { ids: [] },
      ...contentEntries("mechanics")
        .filter((e) => e.lang === lang)
        .map((e) => ({ ids: [e.slug], props: { page: "topic", slug: e.slug } })),
    ],
  },
  {
    key: "guides",
    view: "GuidesSection",
    getPaths: (lang) => [
      { ids: [] },
      ...contentEntries("guides")
        .filter((e) => e.lang === lang)
        .map((e) => ({ ids: [e.slug], props: { page: "guide", slug: e.slug } })),
    ],
  },
  { key: "updates", view: "UpdatesView", getPaths: () => [{ ids: [] }] },
  ...SECTIONS.filter((s) => !s.ready).map(
    (s): PageEntry => ({ key: s.id, view: "ComingSoon", getPaths: () => [{ ids: [], props: { section: s.id } }] }),
  ),
];

/** getStaticPaths of one section in one language (route files of src/pages/<lang>/<segment>/). */
export function pagesOf(key: PageEntry["key"], lang: Lang) {
  const entry = PAGES.find((e) => e.key === key);
  if (!entry) throw new Error(`no page entry for ${key}`);
  return entry.getPaths(lang).map((p) => ({ params: p.ids.length ? { path: p.ids.join("/") } : { path: undefined }, props: { ids: p.ids, extra: p.props ?? {} } }));
}

/** The page of a section at a path ("" or undefined = the section root): its ids and view props. */
export function pageFor(key: PageEntry["key"], lang: Lang, path: string | undefined): { ids: string[]; extra: Record<string, unknown> } {
  const entry = PAGES.find((e) => e.key === key);
  const want = (path ?? "").replace(/^\/+|\/+$/g, "");
  const page = entry?.getPaths(lang).find((p) => p.ids.join("/") === want);
  return { ids: page?.ids ?? [], extra: page?.props ?? {} };
}

/** URL segment of a section in a language ("404" for the not-found page). */
export function segmentOf(key: PageEntry["key"], lang: Lang): string {
  return key === "404" ? "404" : ROUTES[key][lang];
}
