import type { APIRoute, GetStaticPaths } from "astro";
import { LANGS, type Lang } from "../../i18n/routes";
import { paletteEntries } from "../../lib/palette";

// Small index for the Ctrl+K palette, fetched on first open (islands never import the big data files).
export const getStaticPaths = (() => LANGS.map((lang) => ({ params: { lang } }))) satisfies GetStaticPaths;

export const GET: APIRoute = ({ params }) =>
  new Response(JSON.stringify(paletteEntries(params.lang as Lang)), {
    headers: { "Content-Type": "application/json" },
  });
