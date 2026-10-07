// Page registry (S36): every page below /<lang>/ comes from here; src/pages/[lang]/[...path].astro generates them.
// A later session adds a section with one entry (and sets SECTIONS.ready in src/lib/sections.ts). Sections that
// are not ready get a "Coming soon" page at their root, so no address of the menu is a 404.
import type { Lang, RouteKey } from "../i18n/routes";
import { SECTIONS } from "../lib/sections";
import ComingSoon from "./ComingSoon.astro";
import NotFound from "./NotFound.astro";
import RegionsView from "./RegionsView.astro";
import WorldMapView from "./WorldMapView.astro";
import { areas, caves, maps } from "../lib/world";
import SearchView from "./SearchView.astro";
import Styleguide from "./Styleguide.astro";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type View = (props: any) => any;

export interface PageEntry {
  key: RouteKey | "404";
  view: View;
  /** Paths below the section segment ([] = the section root) with the props of each page. */
  getPaths: (lang: Lang) => { ids: string[]; props?: Record<string, unknown> }[];
}

export const REGISTRY: PageEntry[] = [
  { key: "search", view: SearchView, getPaths: () => [{ ids: [] }] },
  { key: "styleguide", view: Styleguide, getPaths: () => [{ ids: [] }] },
  { key: "404", view: NotFound, getPaths: () => [{ ids: [] }] },
  { key: "map", view: WorldMapView, getPaths: () => [{ ids: [] }] },
  {
    key: "regions",
    view: RegionsView,
    getPaths: () => [
      { ids: [], props: { page: "index" } },
      ...maps()
        .filter((m) => m.kind === "city" || m.kind === "region")
        .map((m) => ({ ids: [m.id], props: { page: "region", id: m.id } })),
      ...areas().map((a) => ({ ids: [a.map, a.id], props: { page: "area", id: a.id } })),
      ...caves().map((c) => ({ ids: [c.region, c.id], props: { page: "cave", id: c.id } })),
    ],
  },
  ...SECTIONS.filter((s) => !s.ready).map(
    (s): PageEntry => ({ key: s.id, view: ComingSoon, getPaths: () => [{ ids: [], props: { section: s.id } }] }),
  ),
];
